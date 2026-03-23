defmodule Loyalty.Billing.StripeWebhookTest do
  use Loyalty.DataCase

  alias Loyalty.{
    AccountsFixtures,
    Billing.StripeWebhook,
    Establishments,
    EstablishmentsFixtures
  }

  describe "handle_event/1" do
    test "invoice.paid with subscription_details metadata updates establishment" do
      scope = AccountsFixtures.user_scope_fixture()
      establishment = EstablishmentsFixtures.establishment_fixture(scope)

      event = %{
        "type" => "invoice.paid",
        "data" => %{
          "object" => %{
            "paid" => true,
            "customer" => "cus_inv",
            "subscription" => "sub_inv",
            "subscription_details" => %{
              "metadata" => %{"establishment_id" => establishment.id}
            }
          }
        }
      }

      assert :ok == StripeWebhook.handle_event(event)

      updated = Establishments.get_establishment!(scope, establishment.id)
      assert updated.stripe_customer_id == "cus_inv"
      assert updated.stripe_subscription_id == "sub_inv"
      assert updated.subscription_status == "active"
    end

    test "customer.subscription.created with metadata updates establishment" do
      scope = AccountsFixtures.user_scope_fixture()
      establishment = EstablishmentsFixtures.establishment_fixture(scope)

      event = %{
        "type" => "customer.subscription.created",
        "data" => %{
          "object" => %{
            "id" => "sub_new",
            "customer" => "cus_new",
            "status" => "active",
            "metadata" => %{"establishment_id" => establishment.id}
          }
        }
      }

      assert :ok == StripeWebhook.handle_event(event)

      updated = Establishments.get_establishment!(scope, establishment.id)
      assert updated.stripe_customer_id == "cus_new"
      assert updated.stripe_subscription_id == "sub_new"
      assert updated.subscription_status == "active"
    end
  end
end
