defmodule DocMind.Store.Manifest do
  @moduledoc """
  Tracks which sources have already been indexed and their content hash.
  Used to skip unchanged documents on re-index, avoiding redundant embedding calls.
  """

  @manifest_suffix ".manifest.bin"

  def load do
    path = manifest_path()

    case File.read(path) do
      {:ok, binary} -> {:ok, :erlang.binary_to_term(binary)}
      {:error, :enoent} -> {:ok, %{}}
      {:error, reason} -> {:error, reason}
    end
  end

  def save(manifest) do
    path = manifest_path()
    File.mkdir_p!(Path.dirname(path))
    File.write(path, :erlang.term_to_binary(manifest, [:compressed]))
  end

  def delete do
    path = manifest_path()

    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def hash(content), do: :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)

  def changed?(manifest, source, content) do
    Map.get(manifest, source) != hash(content)
  end

  def mark_indexed(manifest, source, content) do
    Map.put(manifest, source, hash(content))
  end

  defp manifest_path do
    store_path = DocMind.Config.store_path()
    base = String.replace_suffix(store_path, Path.extname(store_path), "")
    base <> @manifest_suffix
  end
end
