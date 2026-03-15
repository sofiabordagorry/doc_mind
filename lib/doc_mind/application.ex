defmodule DocMind.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DocMindWeb.Telemetry,
      {Phoenix.PubSub, name: DocMind.PubSub},
      DocMind.Store.Cache,
      {Task.Supervisor, name: DocMind.TaskSupervisor},
      DocMind.Indexer,
      DocMindWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: DocMind.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    DocMindWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
