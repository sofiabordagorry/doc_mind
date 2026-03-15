defmodule DocMind.Chunk do
  @enforce_keys [:id, :document_id, :text, :metadata]
  defstruct [:id, :document_id, :text, :metadata, :embedding]

  @type t :: %__MODULE__{
          id: String.t(),
          document_id: String.t(),
          text: String.t(),
          metadata: map(),
          embedding: [float()] | nil
        }
end
