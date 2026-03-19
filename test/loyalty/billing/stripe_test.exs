defmodule Loyalty.Billing.StripeTest do
  use Loyalty.DataCase

  import Loyalty.AccountsFixtures, only: [user_scope_fixture: 0]
  import Loyalty.EstablishmentsFixtures, only: [establishment_fixture: 1]

  alias Loyalty.Billing.Stripe

  defp json_resp(conn, status, body_map) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(status, Jason.encode!(body_map))
  end

  describe "create_subscription_checkout_session/4" do
    test "returns stripe_not_configured when secret_key is blank" do
      prev = Application.get_env(:loyalty, :stripe)
      on_exit(fn -> Application.put_env(:loyalty, :stripe, prev) end)

      Application.put_env(:loyalty, :stripe,
        secret_key: "",
        webhook_secret: prev[:webhook_secret],
        price_id: "price_x"
      )

      scope = user_scope_fixture()
      est = establishment_fixture(scope)

      assert {:error, :stripe_not_configured} =
               Stripe.create_subscription_checkout_session(est, "http://ok", "http://cancel")
    end

    test "returns stripe_not_configured when price_id is blank" do
      prev = Application.get_env(:loyalty, :stripe)
      on_exit(fn -> Application.put_env(:loyalty, :stripe, prev) end)

      Application.put_env(:loyalty, :stripe,
        secret_key: "sk_test",
        webhook_secret: prev[:webhook_secret],
        price_id: ""
      )

      scope = user_scope_fixture()
      est = establishment_fixture(scope)

      assert {:error, :stripe_not_configured} =
               Stripe.create_subscription_checkout_session(est, "http://ok", "http://cancel",
                 req_opts: [
                   plug: fn conn ->
                     json_resp(conn, 200, %{"url" => "https://should-not-run.test"})
                   end
                 ]
               )
    end

    test "returns checkout URL when Stripe responds 200 with url" do
      scope = user_scope_fixture()
      est = establishment_fixture(scope)

      assert {:ok, "https://checkout.example/session/cs_test"} =
               Stripe.create_subscription_checkout_session(est, "http://ok", "http://cancel",
                 req_opts: [
                   plug: fn conn ->
                     assert conn.method == "POST"
                     assert conn.request_path == "/v1/checkout/sessions"
                     json_resp(conn, 200, %{"url" => "https://checkout.example/session/cs_test"})
                   end
                 ]
               )
    end

    test "returns stripe_no_checkout_url when 200 body has no url" do
      scope = user_scope_fixture()
      est = establishment_fixture(scope)

      assert {:error, :stripe_no_checkout_url} =
               Stripe.create_subscription_checkout_session(est, "http://ok", "http://cancel",
                 req_opts: [
                   plug: fn conn -> json_resp(conn, 200, %{}) end
                 ]
               )
    end

    test "returns stripe_http_error on non-200 response" do
      scope = user_scope_fixture()
      est = establishment_fixture(scope)

      assert {:error, {:stripe_http_error, 402, %{"error" => "card"}}} =
               Stripe.create_subscription_checkout_session(est, "http://ok", "http://cancel",
                 req_opts: [
                   plug: fn conn -> json_resp(conn, 402, %{"error" => "card"}) end
                 ]
               )
    end
  end
end
