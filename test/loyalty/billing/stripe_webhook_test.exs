defmodule Loyalty.Billing.StripeWebhookTest do
  use Loyalty.DataCase

  import Loyalty.AccountsFixtures, only: [user_scope_fixture: 0]
  import Loyalty.EstablishmentsFixtures, only: [establishment_fixture: 2]

  alias Loyalty.Billing.StripeWebhook
  alias Loyalty.Establishments

  test "handle_event/1 ignores unknown event types" do
    assert :ok ==
             StripeWebhook.handle_event(%{
               "type" => "invoice.paid",
               "data" => %{"object" => %{}}
             })
  end

  test "handle_event/1 ignores malformed payloads" do
    assert :ok == StripeWebhook.handle_event(%{})
    assert :ok == StripeWebhook.handle_event("not a map")
  end

  test "checkout.session.completed with subscription id as nested map applies billing" do
    scope = user_scope_fixture()
    est = establishment_fixture(scope, %{})

    event = %{
      "type" => "checkout.session.completed",
      "data" => %{
        "object" => %{
          "customer" => "cus_map",
          "subscription" => %{"id" => "sub_from_map"},
          "metadata" => %{"establishment_id" => est.id}
        }
      }
    }

    assert :ok == StripeWebhook.handle_event(event)

    updated = Establishments.get_establishment!(scope, est.id)
    assert updated.stripe_customer_id == "cus_map"
    assert updated.stripe_subscription_id == "sub_from_map"
    assert updated.subscription_status == "active"
  end

  test "checkout.session.completed with missing customer is a no-op" do
    scope = user_scope_fixture()
    est = establishment_fixture(scope, %{})

    event = %{
      "type" => "checkout.session.completed",
      "data" => %{
        "object" => %{
          "subscription" => "sub_x",
          "metadata" => %{"establishment_id" => est.id}
        }
      }
    }

    assert :ok == StripeWebhook.handle_event(event)
    refute Establishments.get_establishment!(scope, est.id).stripe_customer_id
  end

  test "customer.subscription.updated with invalid ids returns :ok" do
    assert :ok ==
             StripeWebhook.handle_event(%{
               "type" => "customer.subscription.updated",
               "data" => %{"object" => %{"id" => nil, "status" => "active"}}
             })
  end

  test "customer.subscription.deleted with invalid id returns :ok" do
    assert :ok ==
             StripeWebhook.handle_event(%{
               "type" => "customer.subscription.deleted",
               "data" => %{"object" => %{"id" => nil}}
             })
  end
end
