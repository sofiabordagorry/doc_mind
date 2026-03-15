defmodule DocMind.Chunking.SectionChunker do
  alias DocMind.Chunk

  @max_chars 1200
  @overlap 100

  def chunk(%DocMind.Document{} = doc, opts \\ []) do
    max_chars = Keyword.get(opts, :max_chars, @max_chars)
    overlap = Keyword.get(opts, :overlap, @overlap)
    collection = Keyword.get(opts, :collection, nil)

    chunks =
      doc.content
      |> split_into_sections()
      |> Enum.with_index()
      |> Enum.flat_map(fn {{heading, text}, section_idx} ->
        text
        |> split_section(max_chars, overlap)
        |> Enum.with_index()
        |> Enum.map(fn {chunk_text, chunk_idx} ->
          %Chunk{
            id: "#{doc.id}_#{section_idx}_#{chunk_idx}",
            document_id: doc.id,
            text: chunk_text,
            metadata: %{
              source: doc.source,
              heading: heading,
              section_index: section_idx,
              chunk_index: chunk_idx,
              collection: collection
            }
          }
        end)
      end)

    {:ok, chunks}
  end

  defp split_into_sections(content) do
    {sections, last_heading, last_lines} =
      content
      |> String.split("\n")
      |> Enum.reduce({[], "Introduction", []}, fn line, {sections, heading, acc} ->
        if String.match?(line, ~r/^\#{1,6}\s/) do
          new_heading = String.replace(line, ~r/^\#+\s*/, "") |> String.trim()
          text = acc |> Enum.reverse() |> Enum.join("\n") |> String.trim()
          sections = if text != "", do: [{heading, text} | sections], else: sections
          {sections, new_heading, []}
        else
          {sections, heading, [line | acc]}
        end
      end)

    remaining = last_lines |> Enum.reverse() |> Enum.join("\n") |> String.trim()
    all = if remaining != "", do: [{last_heading, remaining} | sections], else: sections
    Enum.reverse(all)
  end

  defp split_section(text, max_chars, _overlap) when byte_size(text) <= max_chars, do: [text]

  defp split_section(text, max_chars, overlap) do
    overlap_word_count = max(1, div(overlap, 5))

    {chunks, current} =
      text
      |> String.split(~r/\s+/)
      |> Enum.reduce({[], []}, fn word, {chunks, current} ->
        candidate = Enum.reverse([word | current]) |> Enum.join(" ")

        if String.length(candidate) > max_chars and current != [] do
          chunk_text = current |> Enum.reverse() |> Enum.join(" ")
          tail = Enum.take(current, overlap_word_count)
          {[chunk_text | chunks], [word | tail]}
        else
          {chunks, [word | current]}
        end
      end)

    remaining = current |> Enum.reverse() |> Enum.join(" ")
    all = if remaining != "", do: [remaining | chunks], else: chunks
    Enum.reverse(all)
  end
end
