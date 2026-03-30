defmodule Loyalty.EstablishmentsTest do
  use Loyalty.DataCase

  alias Loyalty.Establishments

  describe "establishments" do
    alias Loyalty.Establishments.Establishment

    import Loyalty.AccountsFixtures, only: [user_scope_fixture: 0]
    import Loyalty.EstablishmentsFixtures

    @invalid_attrs %{name: nil}

    test "list_establishments/1 returns all scoped establishments" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      establishment = establishment_fixture(scope)
      other_establishment = establishment_fixture(other_scope)
      assert Establishments.list_establishments(scope) == [establishment]
      assert Establishments.list_establishments(other_scope) == [other_establishment]
    end

    test "get_establishment!/2 returns the establishment with given id" do
      scope = user_scope_fixture()
      establishment = establishment_fixture(scope)
      other_scope = user_scope_fixture()
      assert Establishments.get_establishment!(scope, establishment.id) == establishment

      assert_raise Ecto.NoResultsError, fn ->
        Establishments.get_establishment!(other_scope, establishment.id)
      end
    end

    test "create_establishment/2 with valid data creates a establishment" do
      valid_attrs = %{name: "some name"}
      scope = user_scope_fixture()

      assert {:ok, %Establishment{} = establishment} =
               Establishments.create_establishment(scope, valid_attrs)

      assert establishment.name == "some name"
      assert establishment.user_id == scope.user.id
    end

    test "create_establishment/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Establishments.create_establishment(scope, @invalid_attrs)
    end

    test "create_establishment/2 when user already has an establishment returns establishment_limit_reached" do
      scope = user_scope_fixture()
      establishment_fixture(scope)

      assert {:error, :establishment_limit_reached} =
               Establishments.create_establishment(scope, %{name: "second establishment"})
    end

    test "update_establishment/3 with valid data updates the establishment" do
      scope = user_scope_fixture()
      establishment = establishment_fixture(scope)
      update_attrs = %{name: "some updated name"}

      assert {:ok, %Establishment{} = establishment} =
               Establishments.update_establishment(scope, establishment, update_attrs)

      assert establishment.name == "some updated name"
    end

    test "update_establishment/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      establishment = establishment_fixture(scope)

      assert_raise MatchError, fn ->
        Establishments.update_establishment(other_scope, establishment, %{})
      end
    end

    test "update_establishment/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      establishment = establishment_fixture(scope)

      assert {:error, %Ecto.Changeset{}} =
               Establishments.update_establishment(scope, establishment, @invalid_attrs)

      assert establishment == Establishments.get_establishment!(scope, establishment.id)
    end

    test "delete_establishment/2 deletes the establishment" do
      scope = user_scope_fixture()
      establishment = establishment_fixture(scope)
      assert {:ok, %Establishment{}} = Establishments.delete_establishment(scope, establishment)

      assert_raise Ecto.NoResultsError, fn ->
        Establishments.get_establishment!(scope, establishment.id)
      end
    end

    test "delete_establishment/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      establishment = establishment_fixture(scope)

      assert_raise MatchError, fn ->
        Establishments.delete_establishment(other_scope, establishment)
      end
    end

    test "change_establishment/2 returns a establishment changeset" do
      scope = user_scope_fixture()
      establishment = establishment_fixture(scope)
      assert %Ecto.Changeset{} = Establishments.change_establishment(scope, establishment)
    end

    test "count_loyalty_cards/1 returns number of cards for establishment" do
      scope = user_scope_fixture()
      establishment = establishment_fixture(scope)
      assert Establishments.count_loyalty_cards(establishment.id) == 0

      scope_with_est = Loyalty.Accounts.Scope.put_establishment(scope, establishment)
      program = Loyalty.LoyaltyProgramsFixtures.loyalty_program_fixture(scope_with_est)

      {:ok, customer} =
        Loyalty.Customers.get_or_create_customer_by_email("count-test@example.com")

      {:ok, _} =
        Loyalty.LoyaltyCards.create_loyalty_card(scope_with_est, %{
          customer_id: customer.id,
          loyalty_program_id: program.id,
          stamps_current: 0,
          stamps_required: 10
        })

      assert Establishments.count_loyalty_cards(establishment.id) == 1
    end

    test "check_new_loyalty_card_allowed/1 free under limit returns :ok" do
      scope = user_scope_fixture()
      establishment = establishment_fixture(scope)
      assert Establishments.check_new_loyalty_card_allowed(establishment) == :ok
    end

    test "check_new_loyalty_card_allowed/1 free at limit returns client_limit_reached" do
      scope = user_scope_fixture()

      establishment =
        establishment_fixture(scope, %{subscription_status: nil})

      scope_with_est = Loyalty.Accounts.Scope.put_establishment(scope, establishment)
      program = Loyalty.LoyaltyProgramsFixtures.loyalty_program_fixture(scope_with_est)

      for i <- 0..(Loyalty.Billing.free_client_limit() - 1) do
        {:ok, customer} =
          Loyalty.Customers.get_or_create_customer_by_email("limit#{i}@example.com")

        assert {:ok, _} =
                 Loyalty.LoyaltyCards.create_loyalty_card(scope_with_est, %{
                   customer_id: customer.id,
                   loyalty_program_id: program.id,
                   stamps_current: 0,
                   stamps_required: 10
                 })
      end

      assert Establishments.check_new_loyalty_card_allowed(establishment) ==
               {:error, :client_limit_reached}
    end

    test "check_new_loyalty_card_allowed/1 paid active returns :ok" do
      scope = user_scope_fixture()

      establishment =
        establishment_fixture(scope, %{subscription_status: "active"})

      assert Establishments.check_new_loyalty_card_allowed(establishment) == :ok
    end

    test "check_new_loyalty_card_allowed/1 past_due returns subscription_inactive" do
      scope = user_scope_fixture()

      establishment =
        establishment_fixture(scope, %{subscription_status: "past_due"})

      assert Establishments.check_new_loyalty_card_allowed(establishment) ==
               {:error, :subscription_inactive}
    end

    test "apply_stripe_billing_attrs/2 updates establishment billing fields" do
      scope = user_scope_fixture()
      establishment = establishment_fixture(scope)
      assert establishment.stripe_customer_id == nil
      assert establishment.subscription_status == nil

      assert {:ok, updated} =
               Establishments.apply_stripe_billing_attrs(establishment.id, %{
                 stripe_customer_id: "cus_xyz",
                 stripe_subscription_id: "sub_abc",
                 subscription_status: "active"
               })

      assert updated.stripe_customer_id == "cus_xyz"
      assert updated.stripe_subscription_id == "sub_abc"
      assert updated.subscription_status == "active"
    end

    test "apply_stripe_billing_attrs/2 with unknown id returns not_found" do
      assert {:error, :not_found} =
               Establishments.apply_stripe_billing_attrs(
                 "00000000-0000-0000-0000-000000000000",
                 %{
                   subscription_status: "active"
                 }
               )
    end

    test "get_establishment_by_stripe_subscription_id/1 returns establishment" do
      scope = user_scope_fixture()

      establishment =
        establishment_fixture(scope, %{stripe_subscription_id: "sub_123"})

      assert Establishments.get_establishment_by_stripe_subscription_id("sub_123").id ==
               establishment.id

      assert Establishments.get_establishment_by_stripe_subscription_id("sub_other") == nil
    end

    test "list_all_establishments_with_owner_emails/0 returns all with default filter" do
      scope = user_scope_fixture()
      establishment = establishment_fixture(scope)

      rows = Establishments.list_all_establishments_with_owner_emails()
      assert Enum.any?(rows, &(&1.id == establishment.id))
    end

    test "create_establishment/2 generates an 8-char referral_code" do
      scope = user_scope_fixture()
      {:ok, establishment} = Establishments.create_establishment(scope, %{name: "ref-test"})
      assert is_binary(establishment.referral_code)
      assert String.length(establishment.referral_code) == 8
    end

    test "get_establishment_by_referral_code/1 finds by code" do
      scope = user_scope_fixture()
      establishment = establishment_fixture(scope)
      found = Establishments.get_establishment_by_referral_code(establishment.referral_code)
      assert found.id == establishment.id
    end

    test "get_establishment_by_referral_code/1 returns nil for unknown code" do
      assert Establishments.get_establishment_by_referral_code("ZZZZZZZZ") == nil
    end

    test "set_referred_by/2 sets referred_by_establishment_id for valid code" do
      scope = user_scope_fixture()
      referrer = establishment_fixture(scope)

      other_scope = user_scope_fixture()
      referred = establishment_fixture(other_scope)

      assert {:ok, updated} = Establishments.set_referred_by(referred, referrer.referral_code)
      assert updated.referred_by_establishment_id == referrer.id
    end

    test "set_referred_by/2 is no-op for blank code" do
      scope = user_scope_fixture()
      establishment = establishment_fixture(scope)
      assert :ok == Establishments.set_referred_by(establishment, "")
    end

    test "set_referred_by/2 is no-op for nil code" do
      scope = user_scope_fixture()
      establishment = establishment_fixture(scope)
      assert :ok == Establishments.set_referred_by(establishment, nil)
    end

    test "set_referred_by/2 is no-op for unknown referral code" do
      scope = user_scope_fixture()
      establishment = establishment_fixture(scope)
      assert :ok == Establishments.set_referred_by(establishment, "UNKNOWN8")
    end

    test "apply_referral_credit/1 sets free_access_until 30 days from now" do
      scope = user_scope_fixture()
      establishment = establishment_fixture(scope)
      assert establishment.free_access_until == nil

      {:ok, updated} = Establishments.apply_referral_credit(establishment)
      assert updated.free_access_until != nil

      diff = DateTime.diff(updated.free_access_until, DateTime.utc_now(), :day)
      assert diff >= 29 and diff <= 30
    end

    test "apply_referral_credit/1 stacks on existing credit" do
      scope = user_scope_fixture()
      establishment = establishment_fixture(scope)

      future = DateTime.utc_now() |> DateTime.add(15, :day) |> DateTime.truncate(:second)

      {:ok, est_with_credit} =
        establishment
        |> Ecto.Changeset.change(%{free_access_until: future})
        |> Loyalty.Repo.update()

      {:ok, updated} = Establishments.apply_referral_credit(est_with_credit)
      diff = DateTime.diff(updated.free_access_until, future, :day)
      assert diff >= 29 and diff <= 30
    end

    test "count_referral_signups/1 counts referred establishments" do
      scope = user_scope_fixture()
      referrer = establishment_fixture(scope)
      assert Establishments.count_referral_signups(referrer) == 0

      other_scope = user_scope_fixture()
      referred = establishment_fixture(other_scope)

      referred
      |> Ecto.Changeset.change(%{referred_by_establishment_id: referrer.id})
      |> Loyalty.Repo.update!()

      assert Establishments.count_referral_signups(referrer) == 1
    end

    test "count_referral_conversions/1 counts referred with active subscription" do
      scope = user_scope_fixture()
      referrer = establishment_fixture(scope)

      other_scope = user_scope_fixture()
      referred = establishment_fixture(other_scope)

      referred
      |> Ecto.Changeset.change(%{
        referred_by_establishment_id: referrer.id,
        subscription_status: "active"
      })
      |> Loyalty.Repo.update!()

      assert Establishments.count_referral_conversions(referrer) == 1
    end

    test "count_referral_conversions/1 excludes non-active subscriptions" do
      scope = user_scope_fixture()
      referrer = establishment_fixture(scope)

      other_scope = user_scope_fixture()
      referred = establishment_fixture(other_scope)

      referred
      |> Ecto.Changeset.change(%{
        referred_by_establishment_id: referrer.id,
        subscription_status: "past_due"
      })
      |> Loyalty.Repo.update!()

      assert Establishments.count_referral_conversions(referrer) == 0
    end

    test "get_establishment_for_referral_credit/1 returns establishment by id" do
      scope = user_scope_fixture()
      establishment = establishment_fixture(scope)

      assert Establishments.get_establishment_for_referral_credit(establishment.id).id ==
               establishment.id
    end

    test "get_establishment_for_referral_credit/1 returns nil for unknown id" do
      assert Establishments.get_establishment_for_referral_credit(
               "00000000-0000-0000-0000-000000000000"
             ) == nil
    end

    test "check_new_loyalty_card_allowed/1 with free_access bypasses card limit" do
      scope = user_scope_fixture()

      establishment =
        establishment_fixture(scope, %{subscription_status: "past_due"})

      {:ok, est_with_access} =
        establishment
        |> Ecto.Changeset.change(%{
          free_access_until:
            DateTime.utc_now() |> DateTime.add(10, :day) |> DateTime.truncate(:second)
        })
        |> Loyalty.Repo.update()

      assert Establishments.check_new_loyalty_card_allowed(est_with_access) == :ok
    end
  end
end
