defmodule Loyalty.WhatsAppTest do
  use ExUnit.Case, async: true

  describe "send_stamp_update/5 — not configured" do
    test "returns :ok when stamps are in progress and WhatsApp not configured" do
      assert :ok =
               Loyalty.WhatsApp.send_stamp_update(
                 "+5511999999999",
                 3,
                 10,
                 "Free coffee",
                 "Café Test"
               )
    end

    test "returns :ok when stamps are complete (0 remaining) and WhatsApp not configured" do
      assert :ok =
               Loyalty.WhatsApp.send_stamp_update(
                 "+5511999999999",
                 10,
                 10,
                 "Free coffee",
                 "Café Test"
               )
    end
  end

  describe "send_stamp_update/5 — configured, HTTP stubs" do
    setup do
      prev = Application.get_env(:loyalty, Loyalty.WhatsApp)

      Application.put_env(:loyalty, Loyalty.WhatsApp,
        account_sid: "ACtest",
        auth_token: "token",
        from_number: "+15550001111",
        plug: {Req.Test, __MODULE__}
      )

      on_exit(fn ->
        if is_nil(prev),
          do: Application.delete_env(:loyalty, Loyalty.WhatsApp),
          else: Application.put_env(:loyalty, Loyalty.WhatsApp, prev)
      end)

      :ok
    end

    test "returns :ok on 2xx response" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(201, ~s({"sid":"SM123"}))
      end)

      assert :ok =
               Loyalty.WhatsApp.send_stamp_update(
                 "+5511999999999",
                 3,
                 10,
                 "Free coffee",
                 "Café Test"
               )
    end

    test "returns {:error, :twilio_error} on non-2xx response" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(400, ~s({"code":21211}))
      end)

      assert {:error, :twilio_error} =
               Loyalty.WhatsApp.send_stamp_update(
                 "+5511999999999",
                 3,
                 10,
                 "Free coffee",
                 "Café Test"
               )
    end
  end
end
