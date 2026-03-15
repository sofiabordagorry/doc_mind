defmodule DocMindWeb.SearchResults do
  use DocMindWeb, :html

  attr :results, :any, required: true

  def search_results(assigns) do
    ~H"""
    <div :if={is_list(@results)} class="mt-8">
      <div :if={@results == []} class="text-center py-20 text-base-content/25">
        <.icon name="hero-magnifying-glass" class="size-12 mx-auto mb-4" />
        <p class="text-sm">No results found</p>
      </div>
      <div
        :if={@results != []}
        class="border border-base-300 rounded-2xl overflow-hidden divide-y divide-base-200"
      >
        <.result_card :for={r <- @results} result={r} />
      </div>
    </div>
    """
  end

  defp result_card(assigns) do
    ~H"""
    <div class="px-6 py-5 hover:bg-base-200/20 transition-colors">
      <div class="flex items-center gap-2.5 mb-3">
        <span class="badge badge-primary badge-outline badge-sm font-mono shrink-0">
          {Float.round(@result.score, 3)}
        </span>
        <span class="text-xs text-base-content/40 truncate">
          {@result.metadata[:source] || @result.metadata[:url] || "unknown"}
          <span :if={@result.metadata[:heading]}> — {@result.metadata[:heading]}</span>
        </span>
      </div>
      <p class="text-sm text-base-content/75 leading-relaxed">
        {String.slice(@result.text, 0, 500)}
      </p>
    </div>
    """
  end
end
