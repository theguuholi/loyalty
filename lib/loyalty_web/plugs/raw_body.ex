defmodule LoyaltyWeb.Plugs.RawBody do
  @moduledoc """
  Reads the full request body into `conn.assigns[:raw_body]` for Stripe webhooks.

  Used on the webhook-only pipeline (no `Plug.Parsers`). Tests may assign
  `:raw_body` directly to skip reading.
  """

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    if conn.assigns[:raw_body] do
      conn
    else
      read_opts = Keyword.merge([length: 8_000_000], opts)

      case LoyaltyWeb.Plugs.RawBodyReader.read_body(conn, read_opts) do
        {:ok, _full, conn} ->
          conn

        {:error, _reason} ->
          Plug.Conn.assign(conn, :raw_body, "")
      end
    end
  end
end
