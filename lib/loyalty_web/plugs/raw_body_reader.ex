defmodule LoyaltyWeb.Plugs.RawBodyReader do
  @moduledoc """
  Accumulates the full raw request body into `conn.assigns.raw_body` for Stripe
  webhook signature verification while allowing `Plug.Parsers` to run as usual.

  `Plug.Conn.read_body/2` may return `{:more, partial, conn}`; this module loops
  until `{:ok, body, conn}` so the JSON parser receives the complete body and
  the assigned bytes match what Stripe signed.
  """

  @doc false
  def read_body(conn, opts) do
    read_until_ok(conn, opts, "")
  end

  defp read_until_ok(conn, opts, acc) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        full = acc <> body
        {:ok, full, Plug.Conn.assign(conn, :raw_body, full)}

      {:more, partial, conn} ->
        read_until_ok(conn, opts, acc <> partial)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
