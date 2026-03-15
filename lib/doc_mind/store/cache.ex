defmodule DocMind.Store.Cache do
  @moduledoc """
  GenServer that holds the chunk index in memory for fast retrieval.
  On startup it loads the persisted index from disk (if it exists).
  Writes are synchronous: the in-memory state and the on-disk file are
  always updated together.
  """

  use GenServer

  alias DocMind.Store.FileStore

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc "Return all chunks currently in memory."
  def get_chunks do
    GenServer.call(__MODULE__, :get_chunks)
  end

  @doc "Replace the full chunk list, persisting to disk."
  def put_chunks(chunks) do
    GenServer.call(__MODULE__, {:put_chunks, chunks})
  end

  @doc "Clear the in-memory index and delete the on-disk file."
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  @impl true
  def init(:ok) do
    chunks =
      case FileStore.load() do
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
    case FileStore.save(chunks) do
      :ok -> {:reply, :ok, chunks}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:clear, _from, _state) do
    FileStore.delete()
    {:reply, :ok, []}
  end
end
