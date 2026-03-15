defmodule DocMind.IndexerTest do
  use ExUnit.Case

  alias DocMind.Indexer

  test "index_async returns a job id" do
    # We don't have an API key in tests, so we just verify the job is created.
    # The task will fail, but the job tracking is what we're testing here.
    Application.put_env(:doc_mind, :embedding_adapter, __MODULE__.FakeAdapter)

    {:ok, job_id} = Indexer.index_async(["README.md"])
    assert is_binary(job_id)
    assert byte_size(job_id) == 16
  after
    Application.delete_env(:doc_mind, :embedding_adapter)
  end

  test "job_status returns :not_found for unknown job" do
    assert Indexer.job_status("nonexistent") == :not_found
  end

  test "job eventually completes" do
    Application.put_env(:doc_mind, :embedding_adapter, __MODULE__.FakeAdapter)
    {:ok, job_id} = Indexer.index_async(["README.md"])

    result = Indexer.await_job(job_id, 5_000)
    assert match?({:done, _}, result)
  after
    Application.delete_env(:doc_mind, :embedding_adapter)
    DocMind.clear_index()
  end

  defmodule FakeAdapter do
    @behaviour DocMind.Embeddings.Behaviour

    @impl true
    def embed(_text), do: {:ok, [0.1, 0.2, 0.3]}

    @impl true
    def embed_many(texts), do: {:ok, Enum.map(texts, fn _ -> [0.1, 0.2, 0.3] end)}
  end
end
