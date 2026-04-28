defmodule DocMind.Repo.Migrations.CreateChunks do
  use Ecto.Migration

  # Change to 1536 if using OpenAI text-embedding-3-small
  @embedding_dims 1024

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS vector", "DROP EXTENSION IF EXISTS vector"

    create table(:chunks, primary_key: false) do
      add :id, :string, primary_key: true
      add :document_id, :string, null: false
      add :text, :text, null: false
      add :metadata, :map, null: false, default: %{}
      add :embedding, :vector, size: @embedding_dims
      timestamps(type: :utc_datetime)
    end

    create index(:chunks, [:document_id])

    # ANN index — speeds up semantic_search on large datasets.
    # Requires at least a few hundred rows to be effective.
    execute(
      "CREATE INDEX ON chunks USING ivfflat (embedding vector_cosine_ops) WITH (lists = 10)",
      "DROP INDEX IF EXISTS chunks_embedding_idx"
    )
  end
end
