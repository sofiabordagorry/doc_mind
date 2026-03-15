defmodule DocMind.Answer do
  defstruct [:answer, :sources]

  @type t :: %__MODULE__{
          answer: String.t(),
          sources: [map()]
        }
end
