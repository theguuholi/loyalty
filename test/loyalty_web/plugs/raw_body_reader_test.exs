defmodule LoyaltyWeb.Plugs.RawBodyReaderTest do
  use ExUnit.Case, async: true

  import Plug.{Conn, Test}

  alias LoyaltyWeb.Plugs.RawBodyReader

  test "read_body/2 returns full body and assigns raw_body" do
    body = ~s({"hello":"world"})
    base = conn(:post, "/", body)
    conn = put_req_header(base, "content-type", "application/json")

    assert {:ok, ^body, conn} = RawBodyReader.read_body(conn, [])

    assert conn.assigns.raw_body == body
  end
end
