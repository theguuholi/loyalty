defmodule Loyalty.Repo do
  use Ecto.Repo,
    otp_app: :loyalty,
    adapter: Ecto.Adapters.Postgres
end
