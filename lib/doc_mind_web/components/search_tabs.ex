defmodule DocMindWeb.SearchTabs do
  use DocMindWeb, :html

  attr :tab, :atom, required: true

  def search_tabs(assigns) do
    ~H"""
    <div class="flex border-b border-base-300 bg-base-200/40">
      <.tab_button label="Ask" tab={:ask} current={@tab} icon="hero-chat-bubble-left-ellipsis-micro" />
      <.tab_button label="Search" tab={:search} current={@tab} icon="hero-magnifying-glass-micro" />
      <.tab_button label="Index" tab={:index} current={@tab} icon="hero-arrow-up-tray-micro" />
      <.tab_button label="Sources" tab={:sources} current={@tab} icon="hero-rectangle-stack-micro" />
    </div>
    """
  end

  attr :label, :string, required: true
  attr :tab, :atom, required: true
  attr :current, :atom, required: true
  attr :icon, :string, required: true

  defp tab_button(assigns) do
    ~H"""
    <button
      class={[
        "flex items-center gap-2 px-6 py-4 text-sm font-medium transition-colors border-b-2 -mb-px",
        if(@tab == @current,
          do: "border-primary text-primary bg-base-100",
          else: "border-transparent text-base-content/40 hover:text-base-content"
        )
      ]}
      phx-click="switch_tab"
      phx-value-tab={@tab}
    >
      <.icon name={@icon} class="size-4" />{@label}
    </button>
    """
  end
end
