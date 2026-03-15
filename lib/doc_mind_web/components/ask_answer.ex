defmodule DocMindWeb.AskAnswer do
  use DocMindWeb, :html

  attr :answer, :any, required: true

  def ask_answer(assigns) do
    ~H"""
    <div :if={not is_nil(@answer)} class="mt-8 space-y-4">
      <div class="border border-base-300 rounded-2xl px-6 py-6">
        <p class="text-xs font-semibold text-base-content/30 uppercase tracking-widest mb-4">
          Answer
        </p>
        <p class="text-sm leading-loose">{@answer.answer}</p>
      </div>
      <div :if={@answer.sources != []} class="border border-base-300 rounded-2xl px-6 py-5">
        <p class="text-xs font-semibold text-base-content/30 uppercase tracking-widest mb-4">
          Sources
        </p>
        <.answer_source :for={s <- @answer.sources} source={s} />
      </div>
    </div>
    """
  end

  defp answer_source(assigns) do
    ~H"""
    <div class="flex items-center gap-2.5 text-sm text-base-content/50 py-1.5">
      <.icon name="hero-document-text-micro" class="size-3.5 shrink-0 text-base-content/25" />
      {@source[:source] || @source[:url] || "unknown"}
      <span :if={@source[:heading]} class="text-base-content/30"> — {@source[:heading]}</span>
    </div>
    """
  end
end
