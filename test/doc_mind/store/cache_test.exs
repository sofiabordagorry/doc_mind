defmodule DocMind.Store.CacheTest do
  use ExUnit.Case

  alias DocMind.Store.Cache
  alias DocMind.Chunk

  setup do
    Cache.clear()
    :ok
  end

  defp chunk(id),
    do: %Chunk{id: id, document_id: "doc1", text: "text #{id}", metadata: %{}, embedding: nil}

  test "starts empty" do
    assert Cache.get_chunks() == []
  end

  test "put and get chunks" do
    chunks = [chunk("a"), chunk("b")]
    :ok = Cache.put_chunks(chunks)
    assert Cache.get_chunks() == chunks
  end

  test "clear removes all chunks" do
    :ok = Cache.put_chunks([chunk("x")])
    :ok = Cache.clear()
    assert Cache.get_chunks() == []
  end

  test "put_chunks replaces state" do
    :ok = Cache.put_chunks([chunk("1"), chunk("2")])
    :ok = Cache.put_chunks([chunk("3")])
    assert length(Cache.get_chunks()) == 1
  end
end
