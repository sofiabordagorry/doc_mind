defmodule DocMindWeb.SearchHeader do
  use DocMindWeb, :html

  attr :stats, :map, required: true

  def search_header(assigns) do
    ~H"""
    <div style="display: flex; align-items: flex-start; justify-content: space-between; margin-bottom: 3rem;">
      <div>
        <h1 style="font-size: 1.875rem; font-weight: 700; letter-spacing: -0.025em;">DocMind</h1>
        <p style="font-size: 1rem; color: oklch(var(--bc) / 0.5); margin-top: 0.5rem;">
          Semantic search & QA over your docs
        </p>
        <div style="display: flex; gap: 1.25rem; margin-top: 1rem; font-size: 0.875rem; color: oklch(var(--bc) / 0.4);">
          <span style="display: flex; align-items: center; gap: 0.375rem;">
            <.icon name="hero-circle-stack-micro" class="size-4" />
            {@stats.chunks} chunks
          </span>
          <span style="display: flex; align-items: center; gap: 0.375rem;">
            <.icon name="hero-document-text-micro" class="size-4" />
            {@stats.sources} source(s)
          </span>
        </div>
      </div>
      <DocMindWeb.Layouts.theme_toggle />
    </div>
    """
  end
end
