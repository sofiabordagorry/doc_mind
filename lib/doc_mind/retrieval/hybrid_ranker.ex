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

    # Heading-match bonus: boost chunks whose heading contains a query term.
    query_terms = MapSet.new(BM25.tokenize(query))

    heading_bonus =
      Map.new(chunks, fn chunk ->
        heading_tokens = BM25.tokenize(chunk.metadata[:heading] || "")

        bonus =
          cond do
            # All heading tokens appear in the query — strong exact-name match
            heading_tokens != [] and
                Enum.all?(heading_tokens, &MapSet.member?(query_terms, &1)) ->
              0.2

            # At least one heading token matches — weaker signal.
            Enum.any?(heading_tokens, &MapSet.member?(query_terms, &1)) ->
              0.05

            true ->
              0.0
          end

        {chunk.id, bonus}
      end)

    chunks
    |> Enum.map(fn chunk ->
      sem = Map.get(semantic_scores, chunk.id, 0.0)
      lex = Map.get(bm25_scores, chunk.id, 0.0)
      bonus = Map.get(heading_bonus, chunk.id, 0.0)
      hybrid = semantic_weight * sem + lexical_weight * lex + bonus
      {chunk, hybrid}
    end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
  end
end
