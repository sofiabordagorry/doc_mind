defmodule DocMind.Chunking.SectionChunkerTest do
  use ExUnit.Case, async: true

  alias DocMind.Chunking.SectionChunker
  alias DocMind.Document

  defp doc(content, id \\ "test"),
    do: %Document{id: id, source: "test.md", content: content, metadata: %{}}

  test "splits document into sections by headings" do
    {:ok, chunks} =
      SectionChunker.chunk(
        doc("""
        # Intro
        This is the intro.

        # Setup
        Setup instructions here.

        # Usage
        How to use it.
        """)
      )

    assert length(chunks) >= 3
    assert Enum.all?(chunks, &(&1.text != ""))
    assert Enum.all?(chunks, &(&1.metadata[:source] == "test.md"))
  end

  test "splits oversized sections into smaller chunks" do
    long = String.duplicate("word ", 500)
    {:ok, chunks} = SectionChunker.chunk(doc("# Big\n#{long}"), max_chars: 200)
    assert length(chunks) > 1
  end

  test "chunk ids are unique within a document" do
    {:ok, chunks} =
      SectionChunker.chunk(
        doc("""
        # A
        text a
        # B
        text b
        # C
        text c
        """)
      )

    ids = Enum.map(chunks, & &1.id)
    assert ids == Enum.uniq(ids)
  end

  test "assigns correct metadata" do
    {:ok, [chunk | _]} = SectionChunker.chunk(doc("# My Heading\nContent here."))
    assert chunk.metadata[:source] == "test.md"
    assert is_binary(chunk.metadata[:heading])
    assert is_integer(chunk.metadata[:section_index])
    assert is_integer(chunk.metadata[:chunk_index])
  end
end
