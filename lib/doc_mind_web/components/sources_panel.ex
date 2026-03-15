defmodule DocMindWeb.SourcesPanel do
  use DocMindWeb, :html

  attr :source_list, :list, required: true
  attr :collections, :list, required: true

  def sources_panel(assigns) do
    ~H"""
    <div>
      <div :if={@source_list == []} class="text-center py-10 text-base-content/30">
        <.icon name="hero-rectangle-stack" class="size-10 mx-auto mb-3" />
        <p class="text-sm">No sources indexed yet</p>
      </div>
      <div :if={@source_list != []} class="-mx-6 -my-6 divide-y divide-base-200">
        <.collection_group :for={c <- @collections} collection={c} />
      </div>
    </div>
    """
  end

  defp collection_group(assigns) do
    ~H"""
    <details open class="group">
      <summary class="flex items-center gap-2 px-6 py-3 text-xs font-semibold uppercase tracking-widest text-base-content/40 cursor-pointer select-none hover:text-base-content/60 transition-colors list-none">
        <.icon
          name="hero-chevron-right-micro"
          class="size-3 group-open:rotate-90 transition-transform"
        />
        {@collection.name || "Uncollected"} ({length(@collection.sources)})
      </summary>
      <div class="border-t border-base-200">
        <.source_item :for={s <- @collection.sources} source={s} />
      </div>
    </details>
    """
  end

  defp source_item(assigns) do
    ~H"""
    <div class="flex items-center px-6 py-3 hover:bg-base-200/20 transition-colors group">
      <.icon
        name={
          if String.starts_with?(@source.name, "http"),
            do: "hero-globe-alt-micro",
            else: "hero-document-text-micro"
        }
        class="size-3.5 shrink-0 text-base-content/30 mr-2.5"
      />
      <span class="text-sm text-base-content/80 truncate flex-1">{@source.name}</span>
      <button
        type="button"
        phx-click="remove_source"
        phx-value-source={@source.name}
        class="btn btn-ghost btn-xs text-error opacity-0 group-hover:opacity-100 transition-opacity px-1"
        title="Remove source"
      >
        <.icon name="hero-trash-micro" class="size-3.5" />
      </button>
    </div>
    """
  end
end
