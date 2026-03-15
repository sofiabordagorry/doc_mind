defmodule DocMind.Ingestion.HexdocsCrawler do
  alias DocMind.Document

  @request_delay_ms 100
  @skip_extensions ~w(.png .jpg .jpeg .gif .svg .css .js .json .xml .zip .tar .gz .pdf)

  defp skip_patterns do
    [
      ~r/\/search/,
      ~r/\/404/,
      ~r/\/changelog/i,
      ~r/\/license/i,
      ~r/\/contributing/i,
      ~r/\/code_of_conduct/i
    ]
  end

  def crawl(url, opts \\ []) do
    delay_ms = Keyword.get(opts, :request_delay_ms, @request_delay_ms)
    base_url = extract_base_url(url)

    case fetch_and_parse(url) do
      {:ok, doc, links} ->
        more_urls =
          links
          |> Enum.filter(&same_domain?(&1, base_url))
          |> Enum.reject(&(&1 == url))
          |> Enum.reject(&skip_url?/1)

        seen_hashes = MapSet.new([content_hash(doc.content)])
        rest = crawl_many(more_urls, MapSet.new([url]), seen_hashes, [], delay_ms)
        {:ok, [doc | rest]}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp crawl_many([], _visited, _hashes, acc, _delay), do: Enum.reverse(acc)

  defp crawl_many([url | rest], visited, hashes, acc, delay) do
    if MapSet.member?(visited, url) do
      crawl_many(rest, visited, hashes, acc, delay)
    else
      Process.sleep(delay)

      case fetch_and_parse(url) do
        {:ok, doc, _links} ->
          hash = content_hash(doc.content)

          if MapSet.member?(hashes, hash) do
            crawl_many(rest, MapSet.put(visited, url), hashes, acc, delay)
          else
            crawl_many(
              rest,
              MapSet.put(visited, url),
              MapSet.put(hashes, hash),
              [doc | acc],
              delay
            )
          end

        {:error, _} ->
          crawl_many(rest, MapSet.put(visited, url), hashes, acc, delay)
      end
    end
  end

  def fetch_and_parse(url) do
    case Req.get(url, headers: [{"user-agent", "DocMind/0.1"}]) do
      {:ok, %{status: 200, body: html}} when is_binary(html) ->
        {:ok, parse_html(html, url), extract_links(html, url)}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_html(html, url) do
    {:ok, parsed} = Floki.parse_document(html)

    title =
      parsed |> Floki.find("h1") |> Floki.text() |> String.trim()

    content =
      case Floki.find(parsed, ".content, article, main, #content, .body-wrapper") do
        [] -> Floki.find(parsed, "body")
        nodes -> nodes
      end
      |> Floki.text(sep: "\n")
      |> clean_text()

    %Document{
      id: generate_id(url),
      source: url,
      content: content,
      metadata: %{type: :html, title: title, url: url}
    }
  end

  defp extract_links(html, base_url) do
    {:ok, parsed} = Floki.parse_document(html)
    base_uri = URI.parse(base_url)

    parsed
    |> Floki.find("a[href]")
    |> Floki.attribute("href")
    |> Enum.map(&resolve_url(&1, base_uri))
    |> Enum.filter(& &1)
    |> Enum.reject(&skip_url?/1)
    |> Enum.uniq()
  end

  defp resolve_url(href, base_uri) do
    case URI.parse(href) do
      %URI{scheme: nil, path: path} when is_binary(path) ->
        absolute_path =
          if String.starts_with?(path, "/") do
            path
          else
            base_dir =
              (base_uri.path || "/")
              |> String.split("/")
              |> Enum.drop(-1)
              |> Enum.join("/")

            base_dir <> "/" <> path
          end

        URI.to_string(%{base_uri | path: absolute_path, query: nil, fragment: nil})

      %URI{scheme: scheme} when scheme in ["http", "https"] ->
        href |> URI.parse() |> Map.put(:fragment, nil) |> Map.put(:query, nil) |> URI.to_string()

      _ ->
        nil
    end
  end

  defp same_domain?(url, base_url) do
    uri = URI.parse(url)
    base = URI.parse(base_url)
    uri.host == base.host and String.starts_with?(uri.path || "", base.path || "")
  end

  defp skip_url?(url) do
    uri = URI.parse(url)
    path = uri.path || ""

    Path.extname(path) in @skip_extensions or
      Enum.any?(skip_patterns(), &Regex.match?(&1, path))
  end

  # Drop the filename segment to get the package base path.
  # e.g. https://hexdocs.pm/elixir/GenServer.html -> https://hexdocs.pm/elixir
  defp extract_base_url(url) do
    uri = URI.parse(url)

    base_path =
      (uri.path || "/")
      |> String.split("/")
      |> Enum.drop(-1)
      |> Enum.join("/")
      |> then(&if(&1 == "", do: "/", else: &1))

    URI.to_string(%{uri | path: base_path, query: nil, fragment: nil})
  end

  defp clean_text(text) do
    text
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.replace(~r/[ \t]+/, " ")
    |> String.trim()
  end

  defp content_hash(content), do: :crypto.hash(:md5, content) |> Base.encode16(case: :lower)

  defp generate_id(source) do
    :crypto.hash(:sha256, source) |> Base.encode16(case: :lower) |> binary_part(0, 16)
  end
end
