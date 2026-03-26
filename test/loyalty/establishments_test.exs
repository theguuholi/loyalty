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
  end
end
