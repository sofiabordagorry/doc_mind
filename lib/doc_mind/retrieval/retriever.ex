defmodule DocMind.Retrieval.Retriever do
  alias DocMind.Result
  alias DocMind.Retrieval.{HybridRanker, Reranker}
  alias DocMind.Store.Cache

  @doc """
  Search the index using hybrid ranking (semantic + BM25).

  ## Options

    * `:top_k` — number of results (default: `5`)
    * `:semantic_weight` — weight of semantic score vs BM25, 0.0–1.0 (default: `0.7`)
    * `:rerank` — run LLM reranker over top-k results (default: `false`)
  """
  def search(query, opts \\ []) do
    top_k = Keyword.get(opts, :top_k, 5)
    rerank = Keyword.get(opts, :rerank, false)
    semantic_weight = Keyword.get(opts, :semantic_weight, 0.7)
    adapter = Application.get_env(:doc_mind, :embedding_adapter)

    with {:ok, query_embedding} <- adapter.embed(query) do
      chunks = Cache.get_chunks() |> Enum.filter(& &1.embedding)

      results =
        HybridRanker.rank(query, chunks, query_embedding, semantic_weight: semantic_weight)
        |> Enum.take(top_k)
        |> Enum.map(fn {chunk, score} ->
          %Result{score: score, text: chunk.text, metadata: chunk.metadata}
        end)

      if rerank do
        Reranker.rerank(query, results, opts)
      else
        {:ok, results}
      end
    end
  end
end
