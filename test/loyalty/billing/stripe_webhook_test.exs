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

    test "invoice.payment_succeeded also updates establishment" do
      scope = AccountsFixtures.user_scope_fixture()
      establishment = EstablishmentsFixtures.establishment_fixture(scope)

      event = %{
        "type" => "invoice.payment_succeeded",
        "data" => %{
          "object" => %{
            "paid" => true,
            "customer" => "cus_ps",
            "subscription" => "sub_ps",
            "metadata" => %{"establishment_id" => establishment.id}
          }
        }
      }

      assert :ok == StripeWebhook.handle_event(event)

      updated = Establishments.get_establishment!(scope, establishment.id)
      assert updated.subscription_status == "active"
    end

    test "invoice.paid with invoice not paid returns :ok without updating" do
      scope = AccountsFixtures.user_scope_fixture()
      establishment = EstablishmentsFixtures.establishment_fixture(scope)

      event = %{
        "type" => "invoice.paid",
        "data" => %{
          "object" => %{
            "paid" => false,
            "customer" => "cus_x",
            "subscription" => "sub_x",
            "metadata" => %{"establishment_id" => establishment.id}
          }
        }
      }

      assert :ok == StripeWebhook.handle_event(event)

      updated = Establishments.get_establishment!(scope, establishment.id)
      assert updated.subscription_status == nil
    end

    test "checkout.session.completed with subscription as map extracts subscription id" do
      scope = AccountsFixtures.user_scope_fixture()
      establishment = EstablishmentsFixtures.establishment_fixture(scope)

      event = %{
        "type" => "checkout.session.completed",
        "data" => %{
          "object" => %{
            "customer" => "cus_map",
            "subscription" => %{"id" => "sub_map"},
            "metadata" => %{"establishment_id" => establishment.id}
          }
        }
      }

      assert :ok == StripeWebhook.handle_event(event)

      updated = Establishments.get_establishment!(scope, establishment.id)
      assert updated.stripe_subscription_id == "sub_map"
    end

    test "checkout.session.completed with missing fields returns :ok" do
      event = %{
        "type" => "checkout.session.completed",
        "data" => %{"object" => %{"customer" => "cus_x"}}
      }

      assert :ok == StripeWebhook.handle_event(event)
    end

    test "customer.subscription.created with missing fields returns :ok" do
      event = %{
        "type" => "customer.subscription.created",
        "data" => %{"object" => %{"id" => "sub_x"}}
      }

      assert :ok == StripeWebhook.handle_event(event)
    end

    test "customer.subscription.updated with missing fields returns :ok" do
      event = %{
        "type" => "customer.subscription.updated",
        "data" => %{"object" => %{}}
      }

      assert :ok == StripeWebhook.handle_event(event)
    end

    test "customer.subscription.deleted with missing sub_id returns :ok" do
      event = %{
        "type" => "customer.subscription.deleted",
        "data" => %{"object" => %{}}
      }

      assert :ok == StripeWebhook.handle_event(event)
    end

    test "unknown event type returns :ok" do
      event = %{
        "type" => "some.unknown.event",
        "data" => %{"object" => %{}}
      }

      assert :ok == StripeWebhook.handle_event(event)
    end

    test "malformed event returns :ok" do
      assert :ok == StripeWebhook.handle_event(%{"type" => "no_data"})
      assert :ok == StripeWebhook.handle_event("not a map")
    end

    test "invoice.paid with unknown establishment id returns :ok" do
      event = %{
        "type" => "invoice.paid",
        "data" => %{
          "object" => %{
            "paid" => true,
            "customer" => "cus_x",
            "subscription" => "sub_x",
            "metadata" => %{"establishment_id" => "00000000-0000-0000-0000-000000000000"}
          }
        }
      }

      assert :ok == StripeWebhook.handle_event(event)
    end

    test "customer.subscription.updated with unknown sub_id returns :ok" do
      event = %{
        "type" => "customer.subscription.updated",
        "data" => %{
          "object" => %{"id" => "sub_unknown_999", "status" => "canceled"}
        }
      }

      assert :ok == StripeWebhook.handle_event(event)
    end

    test "checkout.session.completed with unknown establishment_id returns :ok" do
      event = %{
        "type" => "checkout.session.completed",
        "data" => %{
          "object" => %{
            "customer" => "cus_unknown_est",
            "subscription" => "sub_unknown_est",
            "metadata" => %{"establishment_id" => "00000000-0000-0000-0000-000000000001"}
          }
        }
      }

      assert :ok == StripeWebhook.handle_event(event)
    end

    test "customer.subscription.created with unknown establishment_id returns :ok" do
      event = %{
        "type" => "customer.subscription.created",
        "data" => %{
          "object" => %{
            "id" => "sub_unknown_est2",
            "customer" => "cus_unknown_est2",
            "status" => "active",
            "metadata" => %{"establishment_id" => "00000000-0000-0000-0000-000000000002"}
          }
        }
      }

      assert :ok == StripeWebhook.handle_event(event)
    end

    test "invoice.paid where subscription is not a string returns :ok without update" do
      scope = AccountsFixtures.user_scope_fixture()
      establishment = EstablishmentsFixtures.establishment_fixture(scope)

      event = %{
        "type" => "invoice.paid",
        "data" => %{
          "object" => %{
            "paid" => true,
            "customer" => "cus_map_sub",
            "subscription" => %{"id" => "sub_map_sub"},
            "metadata" => %{"establishment_id" => establishment.id}
          }
        }
      }

      assert :ok == StripeWebhook.handle_event(event)

      updated = Establishments.get_establishment!(scope, establishment.id)
      assert updated.subscription_status == nil
    end
  end
end
