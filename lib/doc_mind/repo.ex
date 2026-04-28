defmodule DocMind.Repo do
  use Ecto.Repo,
    otp_app: :doc_mind,
    adapter: Ecto.Adapters.Postgres
end
