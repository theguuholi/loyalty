defmodule LoyaltyWeb.Plugs.RawBody do
  @moduledoc """
  Plug to capture the raw request body for webhook signature verification.

  Stores the raw body in `conn.assigns[:raw_body]` before parsing.
  """

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    # In tests, raw_body might already be assigned
    if conn.assigns[:raw_body] do
      conn
    else
      case Plug.Conn.read_body(conn) do
        {:ok, body, conn} -> Plug.Conn.assign(conn, :raw_body, body)
        {:error, _reason} -> Plug.Conn.assign(conn, :raw_body, "")
      end
    end
  end

  @doc """
  Used as `body_reader` in `Plug.Parsers` to capture raw body before parsing.
  Reads the body, stores it in `conn.assigns[:raw_body]`, and returns it for the parser.
  """
  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} -> {:ok, body, Plug.Conn.assign(conn, :raw_body, body)}
      {:more, partial, conn} -> {:more, partial, conn}
      {:error, reason} -> {:error, reason}
    end
  end
end
