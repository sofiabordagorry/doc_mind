defmodule DocMind.Retrieval.HybridRanker do
  @moduledoc """
  Combines semantic cosine similarity with BM25 lexical scoring.

  Final score = semantic_weight * semantic + (1 - semantic_weight) * bm25_normalized
  Default semantic_weight: 0.7
  """

  alias DocMind.Retrieval.{Similarity, BM25}

  @default_semantic_weight 0.7

  @doc """
  Rank chunks by hybrid score. Returns `[{chunk, score}]` sorted descending.
  """
  def rank(query, chunks, query_embedding, opts \\ []) do
    semantic_weight = Keyword.get(opts, :semantic_weight, @default_semantic_weight)
    lexical_weight = 1.0 - semantic_weight

    # Semantic: cosine similarity, normalized from [-1,1] to [0,1]
    semantic_scores =
      Map.new(chunks, fn chunk ->
        raw = Similarity.cosine_similarity(query_embedding, chunk.embedding)
        {chunk.id, (raw + 1.0) / 2.0}
      end)

    # BM25: normalize to [0,1] by dividing by max score
    bm25_raw = BM25.score(query, chunks)

    max_bm25 =
      bm25_raw
      |> Enum.map(&elem(&1, 1))
      |> Enum.max(fn -> 1.0 end)
      |> max(1.0e-9)

    bm25_scores =
      Map.new(bm25_raw, fn {chunk, s} ->
        {chunk.id, s / max_bm25}
      end)

    chunks
    |> Enum.map(fn chunk ->
      sem = Map.get(semantic_scores, chunk.id, 0.0)
      lex = Map.get(bm25_scores, chunk.id, 0.0)
      hybrid = semantic_weight * sem + lexical_weight * lex
      {chunk, hybrid}
    end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
  end
end
