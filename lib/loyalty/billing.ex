defmodule Loyalty.Billing do
  @moduledoc """
  Product constants and helpers for plans and Stripe-backed subscriptions.

  - **Free plan:** `subscription_status` is `nil`, `\"\"`, or `\"free\"`. Up to
    20 loyalty cards per establishment.
  - **Paid plan:** Stripe subscription with status `active` or `trialing`. Up to
    1000 loyalty cards per establishment.
  """

  @free_client_limit 20
  @paid_client_limit 1000

  @doc "Maximum loyalty cards (clients) on the free tier."
  def free_client_limit, do: @free_client_limit

  @doc "Maximum loyalty cards (clients) on an active paid subscription."
  def paid_client_limit, do: @paid_client_limit

  @doc "Stripe subscription statuses that allow registering new clients (paid tier)."
  def paid_subscription_active_statuses, do: ["active", "trialing"]

  @doc """
  True if the establishment is treated as free (no active paid subscription in DB).
  """
  def on_free_plan?(establishment) do
    status = establishment.subscription_status
    status in [nil, "", "free"]
  end

  @doc """
  True if paid subscription is in a state that allows new client cards.
  """
  def paid_subscription_allows_new_clients?(establishment) do
    establishment.subscription_status in paid_subscription_active_statuses()
  end
end
