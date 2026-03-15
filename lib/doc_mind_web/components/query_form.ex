defmodule DocMindWeb.QueryForm do
  use DocMindWeb, :html

  attr :tab, :atom, required: true
  attr :query, :string, required: true
  attr :rerank, :boolean, required: true

  def query_form(assigns) do
    ~H"""
    <form :if={@tab in [:search, :ask]} phx-submit="search" class="space-y-4">
      <textarea
        name="query"
        rows="3"
        class="textarea textarea-bordered w-full resize-none text-sm leading-relaxed"
        placeholder={
          if @tab == :ask,
            do: "What is a GenServer callback?",
            else: "how does supervision work?"
        }
      >{@query}</textarea>
      <div class="flex items-center gap-5">
        <button type="submit" class="btn btn-primary btn-sm px-5">
          <.icon
            name={if @tab == :ask, do: "hero-sparkles-micro", else: "hero-magnifying-glass-micro"}
            class="size-4"
          />
          {if @tab == :ask, do: "Ask", else: "Search"}
        </button>
        <label class="flex items-center gap-2 cursor-pointer select-none">
          <input
            type="checkbox"
            name="rerank"
            value="true"
            checked={@rerank}
            class="checkbox checkbox-xs"
          />
          <span class="text-sm text-base-content/40">Rerank results</span>
        </label>
      </div>
    </form>
    """
  end
end
