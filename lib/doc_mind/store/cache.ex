defmodule DocMind.Store.Cache do
  @moduledoc """
  GenServer that holds the chunk index in memory for fast retrieval.
  On startup it loads the persisted index from disk (if it exists).
  Writes are synchronous: the in-memory state and the on-disk file are
  always updated together.
  """

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc "Return all chunks currently in memory."
  def get_chunks do
    GenServer.call(__MODULE__, :get_chunks)
  end

  @doc "Replace the full chunk list, persisting to the configured store."
  def put_chunks(chunks) do
    GenServer.call(__MODULE__, {:put_chunks, chunks})
  end

  @doc "Clear the in-memory index and delete from the configured store."
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  @impl true
  def init(:ok) do
    chunks =
      case store().load() do
        {:ok, chunks} -> chunks
        _ -> []
      end

    {:ok, chunks}
  end

  @impl true
  def handle_call(:get_chunks, _from, chunks) do
    {:reply, chunks, chunks}
  end

  @impl true
  def handle_call({:put_chunks, chunks}, _from, state) do
    case store().save(chunks) do
      :ok -> {:reply, :ok, chunks}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:clear, _from, _state) do
    store().delete()
    {:reply, :ok, []}
  end

  defp store do
    Application.get_env(:doc_mind, :store_backend, DocMind.Store.PgStore)
  end
end
