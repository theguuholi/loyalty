defmodule LoyaltyWeb.Plugs.RawBodyTest do
  use ExUnit.Case, async: true

  import Plug.{Conn, Test}

  alias LoyaltyWeb.Plugs.RawBody

  test "call/2 reads body and assigns raw_body" do
    body = ~s({"hello":"world"})
    base = conn(:post, "/", body)
    conn = put_req_header(base, "content-type", "application/json")

    conn = RawBody.call(conn, [])

    assert conn.assigns.raw_body == body
  end

  test "call/2 skips reading when raw_body already assigned" do
    base = conn(:post, "/", "")
    conn = Plug.Conn.assign(base, :raw_body, "already-set")

    conn = RawBody.call(conn, [])

    assert conn.assigns.raw_body == "already-set"
  end

  test "read_body/2 stores body in assigns and returns it" do
    body = ~s({"hello":"world"})
    base = conn(:post, "/", body)
    conn = put_req_header(base, "content-type", "application/json")

    assert {:ok, ^body, conn} = RawBody.read_body(conn, [])
    assert conn.assigns.raw_body == body
  end

  test "init/1 returns the options unchanged" do
    opts = [max_length: 1_000_000]
    assert RawBody.init(opts) == opts
  end
end
