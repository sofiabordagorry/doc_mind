defmodule DocMind.Retrieval.BM25Test do
  use ExUnit.Case, async: true

  alias DocMind.Retrieval.BM25
  alias DocMind.Chunk

  defp chunk(id, text),
    do: %Chunk{id: id, document_id: "doc", text: text, metadata: %{}, embedding: nil}

  test "returns empty list for empty corpus" do
    assert BM25.score("query", []) == []
  end

  test "scores higher for chunks with more query terms" do
    chunks = [
      chunk("a", "elixir processes are lightweight"),
      chunk("b", "elixir elixir elixir genserver supervision")
    ]

    scores = BM25.score("elixir", chunks) |> Map.new(fn {c, s} -> {c.id, s} end)
    assert scores["b"] > scores["a"]
  end

  test "irrelevant chunk scores 0.0" do
    chunks = [chunk("a", "completely unrelated words here")]
    [{_chunk, score}] = BM25.score("elixir genserver", chunks)
    assert score == 0.0
  end

  test "tokenize lowercases and removes punctuation" do
    tokens = BM25.tokenize("Hello, World! Elixir.")
    assert "hello" in tokens
    assert "world" in tokens
    assert "elixir" in tokens
    refute "hello," in tokens
  end

  test "tokenize filters short words" do
    tokens = BM25.tokenize("a is the foo bar")
    refute "a" in tokens
    refute "is" in tokens
    assert "foo" in tokens
    assert "bar" in tokens
  end
end
