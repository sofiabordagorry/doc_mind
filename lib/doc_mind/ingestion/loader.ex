defmodule DocMind.Ingestion.Loader do
  alias DocMind.Ingestion.{FileLoader, HexdocsCrawler}

  def load(paths_or_urls, opts \\ []) do
    {urls, paths} = Enum.split_with(paths_or_urls, &url?/1)

    file_docs =
      case paths do
        [] ->
          []

        _ ->
          case FileLoader.load(paths) do
            {:ok, docs} -> docs
            _ -> []
          end
      end

    url_docs =
      Enum.flat_map(urls, fn url ->
        case HexdocsCrawler.crawl(url, opts) do
          {:ok, docs} -> docs
          _ -> []
        end
      end)

    {:ok, file_docs ++ url_docs}
  end

  defp url?(s),
    do: String.starts_with?(s, "http://") or String.starts_with?(s, "https://")
end
