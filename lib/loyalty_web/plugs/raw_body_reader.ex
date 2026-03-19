defmodule LoyaltyWeb.Plugs.RawBodyReader do
  @moduledoc """
  Accumulates the raw request body into `conn.assigns.raw_body` for Stripe webhook
  signature verification while allowing `Plug.Parsers` to run as usual.
  """

  @doc false
  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    assigned = (conn.assigns[:raw_body] || "") <> body
    {:ok, body, Plug.Conn.assign(conn, :raw_body, assigned)}
  end
end
