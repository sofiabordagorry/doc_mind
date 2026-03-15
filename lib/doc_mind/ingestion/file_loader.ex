defmodule DocMind.Ingestion.FileLoader do
  alias DocMind.Document

  def load(paths) when is_list(paths) do
    docs =
      paths
      |> Enum.flat_map(&expand_path/1)
      |> Enum.uniq()
      |> Enum.flat_map(fn path ->
        case load_file(path) do
          {:ok, doc} -> [doc]
          _ -> []
        end
      end)

    {:ok, docs}
  end

  defp expand_path(path) do
    cond do
      File.dir?(path) -> Path.wildcard(Path.join(path, "**/*.{md,txt}"))
      File.regular?(path) -> [path]
      true -> []
    end
  end

  defp load_file(path) do
    case File.read(path) do
      {:ok, content} ->
        {:ok,
         %Document{
           id: generate_id(path),
           source: path,
           content: content,
           metadata: %{type: detect_type(path)}
         }}

      {:error, reason} ->
        {:error, {path, reason}}
    end
  end

  defp detect_type(path) do
    case Path.extname(path) do
      ".md" -> :markdown
      _ -> :text
    end
  end

  defp generate_id(path) do
    :crypto.hash(:sha256, path) |> Base.encode16(case: :lower) |> binary_part(0, 16)
  end
end
