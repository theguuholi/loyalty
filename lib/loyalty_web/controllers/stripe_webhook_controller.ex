defmodule LoyaltyWeb.StripeWebhookController do
  use LoyaltyWeb, :controller

  alias Loyalty.Billing.{StripeSignature, StripeWebhook}

  def create(conn, _params) do
    payload = conn.assigns[:raw_body]
    signature = conn |> get_req_header("stripe-signature") |> List.first()

    if is_nil(signature) do
      send_resp(conn, 400, "missing signature")
    else
      process_webhook(conn, payload, signature)
    end
  end

  defp process_webhook(conn, payload, signature) do
    with :ok <- StripeSignature.verify(payload, signature, webhook_secret()),
         {:ok, event} <- Jason.decode(payload) do
      dispatch_event(conn, event)
    else
      {:error, :webhook_secret_not_configured} ->
        send_resp(conn, 503, "webhook not configured")

      {:error, _} ->
        send_resp(conn, 400, "invalid signature or payload")
    end
  end

  defp dispatch_event(conn, event) do
    case StripeWebhook.handle_event(event) do
      :ok -> send_resp(conn, 200, "")
      {:error, _} -> send_resp(conn, 500, "handler error")
    end
  end

  defp webhook_secret do
    Application.get_env(:loyalty, :stripe)[:webhook_secret] ||
      raise "Stripe webhook secret not configured"
  end
end
