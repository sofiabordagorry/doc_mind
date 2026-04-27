defmodule DocMind.Retrieval.BM25 do
  @moduledoc """
  BM25 lexical relevance scoring over a chunk corpus.
  """

  @k1 1.5
  @b 0.75

  @doc """
  Score each chunk against the query. Returns `[{chunk, float}]`.
  """
  def score(_query, []), do: []

  def score(query, chunks) do
    terms = tokenize(query)
    n = length(chunks)
    avg_dl = chunks |> Enum.map(&word_count(&1.text)) |> Enum.sum() |> then(&(&1 / n))
    idf_map = compute_idf(terms, chunks, n)

    Enum.map(chunks, fn chunk ->
      s = compute_chunk_score(terms, chunk.text, idf_map, avg_dl)
      {chunk, s}
    end)
  end

  defp compute_idf(terms, chunks, n) do
    Map.new(terms, fn term ->
      df = Enum.count(chunks, fn chunk ->
        chunk.text |> tokenize() |> Enum.member?(term)
      end)
      idf = :math.log((n - df + 0.5) / (df + 0.5) + 1)
      {term, idf}
    end)
  end

  defp compute_chunk_score(terms, text, idf_map, avg_dl) do
    words = tokenize(text)
    dl = length(words)

    Enum.reduce(terms, 0.0, fn term, acc ->
      tf = Enum.count(words, &(&1 == term))
      idf = Map.get(idf_map, term, 0.0)
      numerator = tf * (@k1 + 1)
      denominator = tf + @k1 * (1 - @b + @b * dl / max(avg_dl, 1))
      acc + idf * numerator / denominator
    end)
  end

  @stopwords MapSet.new(~w(
    the a an and or but in on at to for of is it this that with from by as are was
    were be been being have has had do does did will would shall should may might can
    could not no nor so if then else when how what which who whom whose where why
  ))

  def tokenize(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/u, " ")
    |> String.split()
    |> Enum.reject(&(String.length(&1) <= 2))
    |> Enum.reject(&MapSet.member?(@stopwords, &1))
    |> Enum.map(&Stemmer.stem/1)
  end

  defp word_count(text), do: text |> String.split() |> length()
end
