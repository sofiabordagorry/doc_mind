defmodule DocMind.Retrieval.Reranker do
  @moduledoc """
  LLM-based reranker. Uses a single prompt to reorder top-k results
  by relevance to the query.

  Enabled via `rerank: true` in search/ask opts. Falls back to
  original order on any LLM error.
  """

  alias DocMind.Config

  @doc """
  Rerank `results` by relevance to `query`.

  Uses the configured LLM adapter to rank all results in one call.
  Falls back gracefully to the original order on error.
  """
  def rerank(query, results, opts \\ [])

  def rerank(_query, [], _opts), do: {:ok, []}

  def rerank(query, results, _opts) do
    llm = Config.llm_adapter()

    passages =
      results
      |> Enum.with_index(1)
      |> Enum.map_join("\n\n", fn {r, i} ->
        "[#{i}] #{String.slice(r.text, 0, 400)}"
      end)

    prompt = """
    You are a relevance ranking assistant.
    Given the query and the numbered passages below, return ONLY a comma-separated list
    of passage numbers ordered from most to least relevant to the query.
    Include every number exactly once. Return nothing else — no explanation, no punctuation other than commas.

    Query: #{query}

    Passages:
    #{passages}

    Ranking:
    """

    case llm.complete(prompt) do
      {:ok, ranking_str} ->
        order = parse_ranking(ranking_str, length(results))
        reranked = order |> Enum.map(&Enum.at(results, &1 - 1)) |> Enum.filter(& &1)
        # Append any results the LLM missed, to guarantee we return top_k items
        missing = Enum.reject(results, &(&1 in reranked))
        {:ok, reranked ++ missing}

      {:error, _reason} ->
        {:ok, results}
    end
  end

  defp parse_ranking(str, n) do
    str
    |> String.replace(~r/[^\d,]/, "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.flat_map(fn s ->
      case Integer.parse(s) do
        {i, ""} when i >= 1 and i <= n -> [i]
        _ -> []
      end
    end)
    |> Enum.uniq()
  end
end
