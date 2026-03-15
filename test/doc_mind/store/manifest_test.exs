defmodule DocMind.Store.ManifestTest do
  use ExUnit.Case, async: true

  alias DocMind.Store.Manifest

  test "hash is deterministic" do
    assert Manifest.hash("hello") == Manifest.hash("hello")
  end

  test "different content produces different hashes" do
    refute Manifest.hash("hello") == Manifest.hash("world")
  end

  test "changed? returns true when source is not in manifest" do
    assert Manifest.changed?(%{}, "file.md", "content")
  end

  test "changed? returns false when hash matches" do
    manifest = Manifest.mark_indexed(%{}, "file.md", "content")
    refute Manifest.changed?(manifest, "file.md", "content")
  end

  test "changed? returns true when content differs" do
    manifest = Manifest.mark_indexed(%{}, "file.md", "old content")
    assert Manifest.changed?(manifest, "file.md", "new content")
  end

  test "mark_indexed stores the hash" do
    manifest = Manifest.mark_indexed(%{}, "file.md", "content")
    assert Map.has_key?(manifest, "file.md")
  end
end
