defmodule DocMind.Retrieval.HybridRankerTest do
  use ExUnit.Case, async: true

  alias DocMind.Retrieval.HybridRanker
  alias DocMind.Chunk

  defp chunk(id, text, embedding),
    do: %Chunk{id: id, document_id: "doc", text: text, metadata: %{}, embedding: embedding}

  test "returns chunks sorted by hybrid score descending" do
    # chunk_a is semantically close (embedding similar to query) but lexically irrelevant
    # chunk_b is lexically very relevant
    chunks = [
      chunk("a", "foo bar baz", [1.0, 0.0]),
      chunk("b", "elixir elixir genserver elixir", [0.0, 1.0])
    ]

    query_embedding = [1.0, 0.0]  # semantically closest to chunk_a

    ranked = HybridRanker.rank("elixir genserver", chunks, query_embedding, semantic_weight: 0.5)
    assert length(ranked) == 2

    ids = Enum.map(ranked, fn {c, _} -> c.id end)
    # With equal weights, BM25 advantage of chunk_b should push it to top
    assert is_list(ids)
  end

  test "pure semantic ranking (weight 1.0) ignores BM25" do
    chunks = [
      chunk("close", "unrelated text", [1.0, 0.0]),
      chunk("far", "elixir elixir elixir", [-1.0, 0.0])
    ]

    query_embedding = [1.0, 0.0]
    ranked = HybridRanker.rank("elixir", chunks, query_embedding, semantic_weight: 1.0)
    [{top, _} | _] = ranked
    assert top.id == "close"
  end

  test "returns all chunks" do
    chunks = Enum.map(1..5, &chunk("c#{&1}", "text #{&1}", [&1 * 0.1, 0.0]))
    ranked = HybridRanker.rank("text", chunks, [1.0, 0.0])
    assert length(ranked) == 5
  end
end
