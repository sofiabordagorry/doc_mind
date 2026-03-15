defmodule DocMind.Result do
  defstruct [:score, :text, :metadata]

  @type t :: %__MODULE__{
          score: float(),
          text: String.t(),
          metadata: map()
        }
end
