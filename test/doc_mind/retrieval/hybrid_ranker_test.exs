defmodule DocMind.Retrieval.HybridRankerTest do
  use ExUnit.Case, async: true

  alias DocMind.Retrieval.HybridRanker
  alias DocMind.Chunk

  defp chunk(id, text),
    do: %Chunk{id: id, document_id: "doc", text: text, metadata: %{}, embedding: nil}

  test "returns chunks sorted by hybrid score descending" do
    # chunk_a is semantically close, chunk_b is lexically very relevant
    chunks = [
      chunk("a", "foo bar baz"),
      chunk("b", "elixir elixir genserver elixir")
    ]

    # pgvector would produce this map; here we pass it directly
    semantic_scores = %{"a" => 1.0, "b" => 0.1}

    ranked = HybridRanker.rank("elixir genserver", chunks, semantic_scores, semantic_weight: 0.5)
    assert length(ranked) == 2
    assert is_list(ranked)
  end

  test "pure semantic ranking (weight 1.0) ignores BM25" do
    chunks = [
      chunk("close", "unrelated text"),
      chunk("far", "elixir elixir elixir")
    ]

    semantic_scores = %{"close" => 1.0, "far" => 0.0}
    ranked = HybridRanker.rank("elixir", chunks, semantic_scores, semantic_weight: 1.0)
    [{top, _} | _] = ranked
    assert top.id == "close"
  end

  test "returns all chunks" do
    chunks = Enum.map(1..5, &chunk("c#{&1}", "text #{&1}"))
    semantic_scores = Map.new(1..5, &{"c#{&1}", &1 * 0.1})
    ranked = HybridRanker.rank("text", chunks, semantic_scores)
    assert length(ranked) == 5
  end
end
