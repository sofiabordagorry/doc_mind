defmodule DocMind.Store.FileStore do
  def save(chunks) do
    path = DocMind.Config.store_path()
    File.mkdir_p!(Path.dirname(path))
    File.write(path, :erlang.term_to_binary(chunks, [:compressed]))
  end

  def load do
    path = DocMind.Config.store_path()

    case File.read(path) do
      {:ok, binary} -> {:ok, :erlang.binary_to_term(binary)}
      {:error, :enoent} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete do
    path = DocMind.Config.store_path()

    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
