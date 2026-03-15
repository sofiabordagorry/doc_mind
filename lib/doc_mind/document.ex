defmodule DocMind.Document do
  @enforce_keys [:id, :source, :content]
  defstruct [:id, :source, :content, metadata: %{}]

  @type t :: %__MODULE__{
          id: String.t(),
          source: String.t(),
          content: String.t(),
          metadata: map()
        }
end
