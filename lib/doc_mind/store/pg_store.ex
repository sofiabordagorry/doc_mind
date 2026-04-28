defmodule DocMind.Store.PgStore do
  import Ecto.Query
  alias DocMind.{Repo, Chunk}
  alias DocMind.Store.ChunkRecord

  def save(chunks) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    records =
      Enum.map(chunks, fn chunk ->
        %{
          id: chunk.id,
          document_id: chunk.document_id,
          text: chunk.text,
          metadata: chunk.metadata,
          embedding: chunk.embedding && Pgvector.new(chunk.embedding),
          inserted_at: now,
          updated_at: now
        }
      end)

    Repo.insert_all(ChunkRecord, records, on_conflict: :replace_all, conflict_target: :id)
    :ok
  end

  def load do
    {:ok, Repo.all(ChunkRecord) |> Enum.map(&to_chunk/1)}
  end

  def delete do
    Repo.delete_all(ChunkRecord)
    :ok
  end

  # Returns a map of chunk_id => cosine_similarity (0.0–1.0).
  # Uses pgvector's <=> operator (cosine distance) to rank candidates in SQL,
  # avoiding a full embedding scan in Elixir.
  def semantic_search(query_embedding, limit) do
    vec = Pgvector.new(query_embedding)

    from(c in ChunkRecord,
      select: {c.id, fragment("1 - (embedding <=> ?)", ^vec)},
      order_by: fragment("embedding <=> ?", ^vec),
      limit: ^limit,
      where: not is_nil(c.embedding)
    )
    |> Repo.all()
    |> Map.new()
  end

  defp to_chunk(%ChunkRecord{} = r) do
    %Chunk{
      id: r.id,
      document_id: r.document_id,
      text: r.text,
      metadata: r.metadata,
      embedding: r.embedding && Pgvector.to_list(r.embedding)
    }
  end
end
