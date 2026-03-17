defmodule Loyalty.LoyaltyCardsTest do
  use Loyalty.DataCase

  alias Loyalty.LoyaltyCards

  describe "loyalty_cards" do
    alias Loyalty.LoyaltyCards.LoyaltyCard

    import Loyalty.EstablishmentsFixtures, only: [establishment_scope_fixture: 0]
    import Loyalty.LoyaltyCardsFixtures

    @invalid_attrs %{stamps_current: nil, stamps_required: nil}

    test "list_loyalty_cards/1 returns all scoped loyalty_cards" do
      scope = establishment_scope_fixture()
      other_scope = establishment_scope_fixture()
      loyalty_card = loyalty_card_fixture(scope)
      other_loyalty_card = loyalty_card_fixture(other_scope)
      assert LoyaltyCards.list_loyalty_cards(scope) == [loyalty_card]
      assert LoyaltyCards.list_loyalty_cards(other_scope) == [other_loyalty_card]
    end

    test "get_loyalty_card!/2 returns the loyalty_card with given id" do
      scope = establishment_scope_fixture()
      loyalty_card = loyalty_card_fixture(scope)
      other_scope = establishment_scope_fixture()
      assert LoyaltyCards.get_loyalty_card!(scope, loyalty_card.id) == loyalty_card

      assert_raise Ecto.NoResultsError, fn ->
        LoyaltyCards.get_loyalty_card!(other_scope, loyalty_card.id)
      end
    end

    test "create_loyalty_card/2 with valid data creates a loyalty_card" do
      scope = establishment_scope_fixture()

      {:ok, customer} =
        Loyalty.Customers.get_or_create_customer_by_email("create-test@example.com")

      program = Loyalty.LoyaltyProgramsFixtures.loyalty_program_fixture(scope)

      valid_attrs = %{
        stamps_current: 42,
        stamps_required: 42,
        customer_id: customer.id,
        loyalty_program_id: program.id
      }

      assert {:ok, %LoyaltyCard{} = loyalty_card} =
               LoyaltyCards.create_loyalty_card(scope, valid_attrs)

      assert loyalty_card.stamps_current == 42
      assert loyalty_card.stamps_required == 42
      assert loyalty_card.establishment_id == scope.establishment.id
    end

    test "create_loyalty_card/2 with invalid data returns error changeset" do
      scope = establishment_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = LoyaltyCards.create_loyalty_card(scope, @invalid_attrs)
    end

    test "update_loyalty_card/3 with valid data updates the loyalty_card" do
      scope = establishment_scope_fixture()
      loyalty_card = loyalty_card_fixture(scope)
      update_attrs = %{stamps_current: 43, stamps_required: 43}

      assert {:ok, %LoyaltyCard{} = loyalty_card} =
               LoyaltyCards.update_loyalty_card(scope, loyalty_card, update_attrs)

      assert loyalty_card.stamps_current == 43
      assert loyalty_card.stamps_required == 43
    end

    test "update_loyalty_card/3 with invalid scope raises" do
      scope = establishment_scope_fixture()
      other_scope = establishment_scope_fixture()
      loyalty_card = loyalty_card_fixture(scope)

      assert_raise MatchError, fn ->
        LoyaltyCards.update_loyalty_card(other_scope, loyalty_card, %{})
      end
    end

    test "update_loyalty_card/3 with invalid data returns error changeset" do
      scope = establishment_scope_fixture()
      loyalty_card = loyalty_card_fixture(scope)

      assert {:error, %Ecto.Changeset{}} =
               LoyaltyCards.update_loyalty_card(scope, loyalty_card, @invalid_attrs)

      assert loyalty_card == LoyaltyCards.get_loyalty_card!(scope, loyalty_card.id)
    end

    test "delete_loyalty_card/2 deletes the loyalty_card" do
      scope = establishment_scope_fixture()
      loyalty_card = loyalty_card_fixture(scope)
      assert {:ok, %LoyaltyCard{}} = LoyaltyCards.delete_loyalty_card(scope, loyalty_card)

      assert_raise Ecto.NoResultsError, fn ->
        LoyaltyCards.get_loyalty_card!(scope, loyalty_card.id)
      end
    end

    test "delete_loyalty_card/2 with invalid scope raises" do
      scope = establishment_scope_fixture()
      other_scope = establishment_scope_fixture()
      loyalty_card = loyalty_card_fixture(scope)

      assert_raise MatchError, fn ->
        LoyaltyCards.delete_loyalty_card(other_scope, loyalty_card)
      end
    end

    test "change_loyalty_card/2 returns a loyalty_card changeset" do
      scope = establishment_scope_fixture()
      loyalty_card = loyalty_card_fixture(scope)
      assert %Ecto.Changeset{} = LoyaltyCards.change_loyalty_card(scope, loyalty_card)
    end

    test "list_loyalty_cards_by_customer_email/1 returns cards for customer email" do
      scope = establishment_scope_fixture()
      loyalty_card = loyalty_card_fixture(scope)
      email = "customer-#{scope.establishment.id}@example.com"
      cards = LoyaltyCards.list_loyalty_cards_by_customer_email(email)
      assert cards != []
      assert Enum.any?(cards, &(&1.id == loyalty_card.id))
    end

    test "list_loyalty_cards_by_customer_email/1 returns empty list for unknown email" do
      assert LoyaltyCards.list_loyalty_cards_by_customer_email("unknown@example.com") == []
    end

    test "add_stamp/2 increments stamps_current" do
      scope = establishment_scope_fixture()
      loyalty_card = loyalty_card_fixture(scope)
      before = loyalty_card.stamps_current
      assert {:ok, updated} = LoyaltyCards.add_stamp(scope, loyalty_card)
      assert updated.stamps_current == before + 1
    end
  end
end
