defmodule DocMind.Ingestion.FileLoaderTest do
  use ExUnit.Case, async: true

  alias DocMind.Ingestion.FileLoader

  @fixtures "test/fixtures/file_loader"

  setup do
    File.mkdir_p!(@fixtures)
    File.write!(Path.join(@fixtures, "sample.md"), "# Hello\nThis is markdown.")
    File.write!(Path.join(@fixtures, "sample.txt"), "Plain text content.")
    on_exit(fn -> File.rm_rf!(@fixtures) end)
    :ok
  end

  test "loads a markdown file" do
    {:ok, [doc]} = FileLoader.load([Path.join(@fixtures, "sample.md")])
    assert String.contains?(doc.content, "Hello")
    assert doc.metadata[:type] == :markdown
  end

  test "loads a plain text file" do
    {:ok, [doc]} = FileLoader.load([Path.join(@fixtures, "sample.txt")])
    assert doc.metadata[:type] == :text
  end

  test "expands directory" do
    {:ok, docs} = FileLoader.load([@fixtures])
    assert length(docs) == 2
  end

  test "returns empty list for nonexistent path" do
    {:ok, docs} = FileLoader.load(["/does/not/exist"])
    assert docs == []
  end
end
