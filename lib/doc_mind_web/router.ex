defmodule DocMindWeb.Router do
  use DocMindWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DocMindWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DocMindWeb do
    pipe_through :browser

    live "/", SearchLive, :index
  end

  if Application.compile_env(:docmind, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: DocMindWeb.Telemetry
    end
  end
end
