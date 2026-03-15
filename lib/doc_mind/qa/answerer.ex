defmodule DocMind.QA.Answerer do
  alias DocMind.{Config, Answer}
  alias DocMind.Retrieval.Retriever

  def answer(query, opts \\ []) do
    top_k = Keyword.get(opts, :top_k, 5)
    llm = Config.llm_adapter()

    with {:ok, results} <- Retriever.search(query, top_k: top_k) do
      prompt = build_prompt(query, results)

      case llm.complete(prompt) do
        {:ok, answer_text} ->
          sources = if String.contains?(answer_text, "["), do: Enum.map(results, & &1.metadata), else: []
          {:ok, %Answer{answer: answer_text, sources: sources}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp build_prompt(query, results) do
    context =
      results
      |> Enum.with_index(1)
      |> Enum.map(fn {result, i} ->
        source = result.metadata[:source] || result.metadata[:url] || "unknown"
        heading = result.metadata[:heading] || ""
        "[#{i}] (#{source} — #{heading})\n#{result.text}"
      end)
      |> Enum.join("\n\n---\n\n")

    """
    Answer the question using ONLY the provided context.
    If the answer cannot be determined from the context, say so.
    Cite sources by their number in brackets like [1], [2].

    Question: #{query}

    Context:
    #{context}

    Answer:
    """
  end
end
