defmodule LoyaltyWeb.StripeWebhookController do
  use LoyaltyWeb, :controller

  alias Loyalty.Billing.{StripeSignature, StripeWebhook}

  def create(conn, _params) do
    raw = conn.assigns[:raw_body] || ""
    secret = Application.get_env(:loyalty, :stripe, [])[:webhook_secret]

    with [sig | _] <- get_req_header(conn, "stripe-signature"),
         :ok <- StripeSignature.verify(raw, sig, secret || ""),
         {:ok, event} <- Jason.decode(raw) do
      case StripeWebhook.handle_event(event) do
        :ok ->
          send_resp(conn, 200, "")

        {:error, _} ->
          send_resp(conn, 500, "handler error")
      end
    else
      [] ->
        send_resp(conn, 400, "missing signature")

      {:error, :webhook_secret_not_configured} ->
        send_resp(conn, 503, "webhook not configured")

      {:error, _} ->
        send_resp(conn, 400, "invalid signature or payload")
    end
  end
end
