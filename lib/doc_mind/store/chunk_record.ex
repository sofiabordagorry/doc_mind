defmodule DocMind.Store.ChunkRecord do
  use Ecto.Schema

  @primary_key {:id, :string, autogenerate: false}
  schema "chunks" do
    field :document_id, :string
    field :text, :string
    field :metadata, :map
    field :embedding, Pgvector.Ecto.Vector
    timestamps(type: :utc_datetime)
  end
end
