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

    test "checkout.session.completed applies referral credit to referrer within 90-day window" do
      referrer_scope = AccountsFixtures.user_scope_fixture()
      referrer = EstablishmentsFixtures.establishment_fixture(referrer_scope)
      assert referrer.free_access_until == nil

      referred_scope = AccountsFixtures.user_scope_fixture()
      referred = EstablishmentsFixtures.establishment_fixture(referred_scope)

      referred
      |> Ecto.Changeset.change(%{referred_by_establishment_id: referrer.id})
      |> Loyalty.Repo.update!()

      event = %{
        "type" => "checkout.session.completed",
        "data" => %{
          "object" => %{
            "customer" => "cus_ref",
            "subscription" => "sub_ref",
            "metadata" => %{"establishment_id" => referred.id}
          }
        }
      }

      assert {:ok, _} = StripeWebhook.handle_event(event)

      updated_referrer = Establishments.get_establishment_for_referral_credit(referrer.id)
      assert updated_referrer.free_access_until != nil
    end

    test "invoice.paid applies referral credit to referrer" do
      referrer_scope = AccountsFixtures.user_scope_fixture()
      referrer = EstablishmentsFixtures.establishment_fixture(referrer_scope)

      referred_scope = AccountsFixtures.user_scope_fixture()
      referred = EstablishmentsFixtures.establishment_fixture(referred_scope)

      referred
      |> Ecto.Changeset.change(%{referred_by_establishment_id: referrer.id})
      |> Loyalty.Repo.update!()

      event = %{
        "type" => "invoice.paid",
        "data" => %{
          "object" => %{
            "paid" => true,
            "customer" => "cus_inv_ref",
            "subscription" => "sub_inv_ref",
            "metadata" => %{"establishment_id" => referred.id}
          }
        }
      }

      assert {:ok, _} = StripeWebhook.handle_event(event)

      updated_referrer = Establishments.get_establishment_for_referral_credit(referrer.id)
      assert updated_referrer.free_access_until != nil
    end

    test "referral credit is not applied when referred_by_establishment_id is nil" do
      scope = AccountsFixtures.user_scope_fixture()
      establishment = EstablishmentsFixtures.establishment_fixture(scope)

      event = %{
        "type" => "checkout.session.completed",
        "data" => %{
          "object" => %{
            "customer" => "cus_no_ref",
            "subscription" => "sub_no_ref",
            "metadata" => %{"establishment_id" => establishment.id}
          }
        }
      }

      assert :ok == StripeWebhook.handle_event(event)

      updated = Establishments.get_establishment!(scope, establishment.id)
      assert updated.free_access_until == nil
    end

    test "get_establishment_for_referral_credit returns nil for unknown id" do
      assert Establishments.get_establishment_for_referral_credit(
               "00000000-0000-0000-0000-000000000099"
             ) == nil
    end

    test "referral credit is not double-applied (idempotency)" do
      referrer_scope = AccountsFixtures.user_scope_fixture()
      referrer = EstablishmentsFixtures.establishment_fixture(referrer_scope)

      referred_scope = AccountsFixtures.user_scope_fixture()
      referred = EstablishmentsFixtures.establishment_fixture(referred_scope)

      referred
      |> Ecto.Changeset.change(%{referred_by_establishment_id: referrer.id})
      |> Loyalty.Repo.update!()

      event = %{
        "type" => "checkout.session.completed",
        "data" => %{
          "object" => %{
            "customer" => "cus_idem",
            "subscription" => "sub_idem",
            "metadata" => %{"establishment_id" => referred.id}
          }
        }
      }

      # First call applies credit
      assert {:ok, _} = StripeWebhook.handle_event(event)
      referrer_v1 = Establishments.get_establishment_for_referral_credit(referrer.id)
      assert referrer_v1.free_access_until != nil

      # Set free_access_until far beyond the 90-day window to simulate already credited
      window_end = DateTime.add(referred.inserted_at, 90, :day)
      far_future = window_end |> DateTime.add(1, :day) |> DateTime.truncate(:second)

      referrer_v1
      |> Ecto.Changeset.change(%{free_access_until: far_future})
      |> Loyalty.Repo.update!()

      # Second call should not re-apply (already_credited? check)
      assert :ok == StripeWebhook.handle_event(event)
      referrer_v2 = Establishments.get_establishment_for_referral_credit(referrer.id)
      assert referrer_v2.free_access_until == far_future
    end

    test "referral credit not applied outside 90-day window" do
      referrer_scope = AccountsFixtures.user_scope_fixture()
      referrer = EstablishmentsFixtures.establishment_fixture(referrer_scope)

      referred_scope = AccountsFixtures.user_scope_fixture()
      referred = EstablishmentsFixtures.establishment_fixture(referred_scope)

      # Backdate referred establishment to more than 90 days ago
      past = DateTime.utc_now() |> DateTime.add(-91, :day) |> DateTime.truncate(:second)

      referred
      |> Ecto.Changeset.change(%{
        referred_by_establishment_id: referrer.id,
        inserted_at: past
      })
      |> Loyalty.Repo.update!()

      event = %{
        "type" => "checkout.session.completed",
        "data" => %{
          "object" => %{
            "customer" => "cus_old",
            "subscription" => "sub_old",
            "metadata" => %{"establishment_id" => referred.id}
          }
        }
      }

      assert :ok == StripeWebhook.handle_event(event)

      updated_referrer = Establishments.get_establishment_for_referral_credit(referrer.id)
      assert updated_referrer.free_access_until == nil
    end
  end
end
