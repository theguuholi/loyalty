defmodule Loyalty.WhatsAppTest do
  use Loyalty.DataCase

  alias Loyalty.WhatsApp

  defp json_resp(conn, status, body_map) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(status, Jason.encode!(body_map))
  end

  defp with_whatsapp_config(config, fun) do
    prev = Application.get_env(:loyalty, Loyalty.WhatsApp)
    on_exit(fn -> Application.put_env(:loyalty, Loyalty.WhatsApp, prev || []) end)
    Application.put_env(:loyalty, Loyalty.WhatsApp, config)
    fun.()
  end

  describe "send_stamp_update/6" do
    test "returns :ok when WhatsApp is not configured (empty config)" do
      with_whatsapp_config([], fn ->
        assert :ok = WhatsApp.send_stamp_update("+5511999999999", 5, 10, "Coffee", "Cafe Test")
      end)
    end

    test "returns :ok when account_sid is nil" do
      with_whatsapp_config([account_sid: nil, auth_token: "token", from_number: "+14155238886"], fn ->
        assert :ok = WhatsApp.send_stamp_update("+5511999999999", 5, 10, "Coffee", "Cafe Test")
      end)
    end

    test "returns :ok on successful Twilio 200 response" do
      with_whatsapp_config(
        [account_sid: "ACtest", auth_token: "authtest", from_number: "+14155238886"],
        fn ->
          assert :ok =
                   WhatsApp.send_stamp_update(
                     "+5511999999999",
                     5,
                     10,
                     "Coffee",
                     "Cafe Test",
                     req_opts: [plug: fn conn -> json_resp(conn, 200, %{"sid" => "SM123"}) end]
                   )
        end
      )
    end

    test "returns :ok on 201 Created response" do
      with_whatsapp_config(
        [account_sid: "ACtest", auth_token: "authtest", from_number: "+14155238886"],
        fn ->
          assert :ok =
                   WhatsApp.send_stamp_update(
                     "+5511999999999",
                     10,
                     10,
                     "Coffee",
                     "Cafe Test",
                     req_opts: [plug: fn conn -> json_resp(conn, 201, %{"sid" => "SM124"}) end]
                   )
        end
      )
    end

    test "returns {:error, :twilio_error} on non-2xx response" do
      with_whatsapp_config(
        [account_sid: "ACtest", auth_token: "authtest", from_number: "+14155238886"],
        fn ->
          assert {:error, :twilio_error} =
                   WhatsApp.send_stamp_update(
                     "+5511999999999",
                     5,
                     10,
                     "Coffee",
                     "Cafe Test",
                     req_opts: [
                       plug: fn conn ->
                         json_resp(conn, 400, %{"code" => 21211, "message" => "Invalid 'To'"})
                       end
                     ]
                   )
        end
      )
    end

    test "sends completed card path when stamps_current >= stamps_required" do
      with_whatsapp_config(
        [account_sid: "ACtest", auth_token: "authtest", from_number: "+14155238886"],
        fn ->
          # stamps_current == stamps_required → completed message branch
          assert :ok =
                   WhatsApp.send_stamp_update(
                     "+5511999999999",
                     10,
                     10,
                     "Coffee",
                     "Cafe Test",
                     req_opts: [plug: fn conn -> json_resp(conn, 200, %{"sid" => "SM125"}) end]
                   )
        end
      )
    end

    test "sends progress message when stamps remaining (remaining > 0)" do
      with_whatsapp_config(
        [account_sid: "ACtest", auth_token: "authtest", from_number: "+14155238886"],
        fn ->
          # stamps_current < stamps_required → progress message branch
          assert :ok =
                   WhatsApp.send_stamp_update(
                     "+5511999999999",
                     3,
                     10,
                     "Coffee",
                     "Cafe Test",
                     req_opts: [plug: fn conn -> json_resp(conn, 200, %{"sid" => "SM126"}) end]
                   )
        end
      )
    end
  end
end
