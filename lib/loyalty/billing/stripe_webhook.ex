defmodule Loyalty.Billing.StripeWebhook do
  @moduledoc "Handles Stripe webhook event payloads (after signature verification)."

  alias Loyalty.Establishments

  @doc """
  Dispatches a decoded Stripe `event` map. Returns `:ok` or `{:error, term}`.
  """
  def handle_event(%{"type" => type, "data" => %{"object" => object}}) do
    case type do
      "checkout.session.completed" ->
        handle_checkout_completed(object)

      "customer.subscription.updated" ->
        handle_subscription_updated(object)

      "customer.subscription.deleted" ->
        handle_subscription_deleted(object)

      _ ->
        :ok
    end
  end

  def handle_event(_), do: :ok

  defp handle_checkout_completed(session) do
    establishment_id =
      get_in(session, ["metadata", "establishment_id"]) || session["client_reference_id"]

    subscription_id = subscription_id_from(session)
    customer_id = session["customer"]

    if establishment_id && subscription_id && customer_id do
      case Establishments.apply_stripe_billing_attrs(establishment_id, %{
             stripe_customer_id: customer_id,
             stripe_subscription_id: subscription_id,
             subscription_status: "active"
           }) do
        {:ok, _} -> :ok
        {:error, :not_found} -> :ok
        {:error, other} -> {:error, other}
      end
    else
      :ok
    end
  end

  defp handle_subscription_updated(sub) do
    sub_id = sub["id"]
    status = sub["status"]

    if is_binary(sub_id) and is_binary(status) do
      apply_billing_by_subscription(sub_id, %{subscription_status: status})
    else
      :ok
    end
  end

  defp handle_subscription_deleted(sub) do
    sub_id = sub["id"]

    if is_binary(sub_id) do
      apply_billing_by_subscription(sub_id, %{subscription_status: "canceled"})
    else
      :ok
    end
  end

  defp apply_billing_by_subscription(sub_id, attrs) when is_binary(sub_id) and is_map(attrs) do
    case Establishments.get_establishment_by_stripe_subscription_id(sub_id) do
      nil ->
        :ok

      est ->
        case Establishments.apply_stripe_billing_attrs(est.id, attrs) do
          {:ok, _} -> :ok
          {:error, other} -> {:error, other}
        end
    end
  end

  defp subscription_id_from(session) do
    case session["subscription"] do
      id when is_binary(id) -> id
      %{"id" => id} when is_binary(id) -> id
      _ -> nil
    end
  end
end
