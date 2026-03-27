defmodule LoyaltyWeb.StripeWebhookControllerTest do
  use LoyaltyWeb.ConnCase

  alias Loyalty.{AccountsFixtures, Establishments, EstablishmentsFixtures}

  defp signing_key do
    Application.get_env(:loyalty, :stripe)[:webhook_secret]
  end

  defp build_signature_header(raw_body) do
    timestamp = System.system_time(:second)
    signed_payload = "#{timestamp}.#{raw_body}"
    mac = :crypto.mac(:hmac, :sha256, signing_key(), signed_payload)
    sig = Base.encode16(mac, case: :lower)
    "t=#{timestamp},v1=#{sig}"
  end

  # Call controller directly with conn that has raw_body and signature so verification
  # sees the same body we signed (endpoint body_reader may not receive body in test).
  defp post_webhook(_conn, body, signature) do
    conn = build_conn(:post, ~p"/webhooks/stripe")

    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("stripe-signature", signature)
    |> assign(:raw_body, body)
    |> put_private(:phoenix_action, :create)
    |> LoyaltyWeb.StripeWebhookController.call(:create)
  end

  describe "POST /webhooks/stripe" do
    test "returns 503 when webhook secret is not configured", %{conn: conn} do
      prev = Application.get_env(:loyalty, :stripe)
      on_exit(fn -> Application.put_env(:loyalty, :stripe, prev) end)

      Application.put_env(:loyalty, :stripe, Keyword.put(prev, :webhook_secret, ""))

      body = ~s({"type":"checkout.session.completed"})
      sig = build_signature_header(body)

      conn =
        post_webhook(conn, body, sig)

      assert response(conn, 503) == "webhook not configured"
    end

    test "returns 400 when Stripe-Signature header is missing", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/stripe", ~s({"type":"checkout.session.completed"}))

      assert response(conn, 400) == "missing signature"
    end

    test "returns 400 when signature is invalid", %{conn: conn} do
      body = ~s({"type":"checkout.session.completed"})

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("stripe-signature", "t=123,v1=invalid")
        |> post(~p"/webhooks/stripe", body)

      assert response(conn, 400) == "invalid signature or payload"
    end

    test "with valid checkout.session.completed updates establishment and returns 200", %{
      conn: conn
    } do
      scope = AccountsFixtures.user_scope_fixture()
      establishment = EstablishmentsFixtures.establishment_fixture(scope)
      assert establishment.subscription_status == nil

      event = %{
        "type" => "checkout.session.completed",
        "data" => %{
          "object" => %{
            "customer" => "cus_xyz",
            "subscription" => "sub_abc",
            "metadata" => %{"establishment_id" => establishment.id}
          }
        }
      }

      body = Jason.encode!(event)
      sig = build_signature_header(body)
      conn = post_webhook(conn, body, sig)

      assert response(conn, 200) == ""

      updated = Establishments.get_establishment!(scope, establishment.id)
      assert updated.stripe_customer_id == "cus_xyz"
      assert updated.stripe_subscription_id == "sub_abc"
      assert updated.subscription_status == "active"
    end

    test "with valid customer.subscription.updated updates status and returns 200", %{conn: conn} do
      scope = AccountsFixtures.user_scope_fixture()

      establishment =
        EstablishmentsFixtures.establishment_fixture(scope, %{
          stripe_subscription_id: "sub_123",
          subscription_status: "active"
        })

      event = %{
        "type" => "customer.subscription.updated",
        "data" => %{
          "object" => %{
            "id" => "sub_123",
            "status" => "past_due"
          }
        }
      }

      body = Jason.encode!(event)
      sig = build_signature_header(body)
      conn = post_webhook(conn, body, sig)

      assert response(conn, 200) == ""

      updated = Establishments.get_establishment!(scope, establishment.id)
      assert updated.subscription_status == "past_due"
    end

    test "with valid customer.subscription.deleted sets canceled and returns 200", %{conn: conn} do
      scope = AccountsFixtures.user_scope_fixture()

      establishment =
        EstablishmentsFixtures.establishment_fixture(scope, %{
          stripe_subscription_id: "sub_456",
          subscription_status: "active"
        })

      event = %{
        "type" => "customer.subscription.deleted",
        "data" => %{
          "object" => %{"id" => "sub_456"}
        }
      }

      body = Jason.encode!(event)
      sig = build_signature_header(body)
      conn = post_webhook(conn, body, sig)

      assert response(conn, 200) == ""

      updated = Establishments.get_establishment!(scope, establishment.id)
      assert updated.subscription_status == "canceled"
    end
  end
end
