defmodule DocMind.Indexer do
  @moduledoc """
  GenServer that manages async indexing jobs.

  Each call to `index_async/2` spawns a supervised Task and returns a job ID
  immediately. Use `job_status/1` to poll, or `await_job/2` to block until done.
  """

  use GenServer

  # --- Public API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc "Start an async indexing job. Returns `{:ok, job_id}` immediately."
  def index_async(paths_or_urls, opts \\ []) do
    GenServer.call(__MODULE__, {:index_async, paths_or_urls, opts})
  end

  @doc """
  Returns the current status of a job:
    - `{:running, started_at}`
    - `{:done, result}`
    - `{:error, reason}`
    - `:not_found`
  """
  def job_status(job_id) do
    GenServer.call(__MODULE__, {:job_status, job_id})
  end

  @doc "List all jobs with their statuses."
  def list_jobs do
    GenServer.call(__MODULE__, :list_jobs)
  end

  @doc "Block until the job finishes (or timeout). Returns the result."
  def await_job(job_id, timeout \\ 300_000) do
    deadline = System.monotonic_time(:millisecond) + timeout
    wait_loop(job_id, deadline)
  end

  # --- GenServer callbacks ---

  @impl true
  def init(:ok) do
    {:ok, %{jobs: %{}}}
  end

  @impl true
  def handle_call({:index_async, paths_or_urls, opts}, _from, state) do
    job_id = generate_id()

    task =
      Task.Supervisor.async_nolink(DocMind.TaskSupervisor, fn ->
        DocMind.index_sync(paths_or_urls, opts)
      end)

    job = %{
      id: job_id,
      status: :running,
      task_ref: task.ref,
      started_at: DateTime.utc_now(),
      finished_at: nil,
      result: nil
    }

    {:reply, {:ok, job_id}, put_in(state.jobs[job_id], job)}
  end

  @impl true
  def handle_call({:job_status, job_id}, _from, state) do
    reply =
      case Map.get(state.jobs, job_id) do
        nil -> :not_found
        %{status: :running, started_at: t} -> {:running, t}
        %{status: :done, result: r} -> {:done, r}
        %{status: :error, result: r} -> {:error, r}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call(:list_jobs, _from, state) do
    jobs =
      state.jobs
      |> Map.values()
      |> Enum.map(&Map.drop(&1, [:task_ref]))
      |> Enum.sort_by(& &1.started_at, {:desc, DateTime})

    {:reply, jobs, state}
  end

  @impl true
  def handle_info({ref, result}, state) do
    # Task completed normally
    case find_by_ref(state.jobs, ref) do
      {job_id, job} ->
        Process.demonitor(ref, [:flush])

        updated = %{job | status: :done, result: result, finished_at: DateTime.utc_now(), task_ref: nil}

        {:noreply, put_in(state.jobs[job_id], updated)}

      nil ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _, reason}, state) do
    # Task crashed
    case find_by_ref(state.jobs, ref) do
      {job_id, job} ->
        updated = %{job | status: :error, result: reason, finished_at: DateTime.utc_now(), task_ref: nil}

        {:noreply, put_in(state.jobs[job_id], updated)}

      nil ->
        {:noreply, state}
    end
  end

  # --- Private ---

  defp find_by_ref(jobs, ref) do
    Enum.find_value(jobs, fn {id, job} ->
      if job.task_ref == ref, do: {id, job}
    end)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp wait_loop(job_id, deadline) do
    case job_status(job_id) do
      {:running, _} ->
        if System.monotonic_time(:millisecond) >= deadline do
          {:error, :timeout}
        else
          Process.sleep(200)
          wait_loop(job_id, deadline)
        end

      other ->
        other
    end
  end
end
