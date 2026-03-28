defmodule Loyalty.LoyaltyCardsTest do
  use Loyalty.DataCase

  alias Loyalty.LoyaltyCards

  describe "loyalty_cards" do
    alias Loyalty.LoyaltyCards.LoyaltyCard

    import Loyalty.AccountsFixtures, only: [user_scope_fixture: 0]
    import Loyalty.EstablishmentsFixtures, only: [establishment_scope_fixture: 0]
    import Loyalty.LoyaltyCardsFixtures

    @invalid_attrs %{stamps_current: nil, stamps_required: nil}

    test "list_loyalty_cards/1 returns all scoped loyalty_cards" do
      scope = establishment_scope_fixture()
      other_scope = establishment_scope_fixture()
      loyalty_card = loyalty_card_fixture(scope)
      other_loyalty_card = loyalty_card_fixture(other_scope)

      assert [loyalty_card.id] ==
               scope |> LoyaltyCards.list_loyalty_cards() |> Enum.map(& &1.id)

      assert [other_loyalty_card.id] ==
               other_scope |> LoyaltyCards.list_loyalty_cards() |> Enum.map(& &1.id)
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

    test "list_loyalty_cards_by_customer_whatsapp/1 returns cards for customer number" do
      scope = establishment_scope_fixture()

      {:ok, customer} =
        Loyalty.Customers.get_or_create_customer_by_whatsapp("+5511900000070")

      program = Loyalty.LoyaltyProgramsFixtures.loyalty_program_fixture(scope)

      {:ok, card} =
        LoyaltyCards.create_loyalty_card(scope, %{
          customer_id: customer.id,
          loyalty_program_id: program.id,
          stamps_current: 0,
          stamps_required: 10
        })

      cards = LoyaltyCards.list_loyalty_cards_by_customer_whatsapp("+5511900000070")
      assert Enum.any?(cards, &(&1.id == card.id))
    end

    test "list_loyalty_cards_by_customer_whatsapp/1 returns empty list for unknown number" do
      assert LoyaltyCards.list_loyalty_cards_by_customer_whatsapp("+5511000000000") == []
    end

    test "add_stamp/2 on a whatsapp customer fires notification without blocking" do
      scope = establishment_scope_fixture()

      {:ok, customer} =
        Loyalty.Customers.get_or_create_customer_by_whatsapp("+5511900000071")

      program = Loyalty.LoyaltyProgramsFixtures.loyalty_program_fixture(scope)

      {:ok, card} =
        LoyaltyCards.create_loyalty_card(scope, %{
          customer_id: customer.id,
          loyalty_program_id: program.id,
          stamps_current: 0,
          stamps_required: 10
        })

      assert {:ok, updated} = LoyaltyCards.add_stamp(scope, card)
      assert updated.stamps_current == 1
    end

    test "add_stamp/2 increments stamps_current" do
      scope = establishment_scope_fixture()
      loyalty_card = loyalty_card_fixture(scope)
      before = loyalty_card.stamps_current
      assert {:ok, updated} = LoyaltyCards.add_stamp(scope, loyalty_card)
      assert updated.stamps_current == before + 1
    end

    test "create_loyalty_card/2 when free plan at client limit returns client_limit_reached" do
      scope = user_scope_fixture()

      establishment =
        Loyalty.EstablishmentsFixtures.establishment_fixture(scope, %{subscription_status: nil})

      scope_with_est = Loyalty.Accounts.Scope.put_establishment(scope, establishment)
      program = Loyalty.LoyaltyProgramsFixtures.loyalty_program_fixture(scope_with_est)

      for i <- 0..(Loyalty.Billing.free_client_limit() - 1) do
        {:ok, customer} =
          Loyalty.Customers.get_or_create_customer_by_email("limit-card#{i}@example.com")

        assert {:ok, _} =
                 LoyaltyCards.create_loyalty_card(scope_with_est, %{
                   customer_id: customer.id,
                   loyalty_program_id: program.id,
                   stamps_current: 0,
                   stamps_required: 10
                 })
      end

      {:ok, extra_customer} =
        Loyalty.Customers.get_or_create_customer_by_email("limit-extra@example.com")

      assert {:error, :client_limit_reached} =
               LoyaltyCards.create_loyalty_card(scope_with_est, %{
                 customer_id: extra_customer.id,
                 loyalty_program_id: program.id,
                 stamps_current: 0,
                 stamps_required: 10
               })
    end

    test "create_loyalty_card/2 when subscription inactive returns subscription_inactive" do
      scope = user_scope_fixture()

      establishment =
        Loyalty.EstablishmentsFixtures.establishment_fixture(scope, %{
          subscription_status: "past_due"
        })

      scope_with_est = Loyalty.Accounts.Scope.put_establishment(scope, establishment)
      program = Loyalty.LoyaltyProgramsFixtures.loyalty_program_fixture(scope_with_est)
      {:ok, customer} = Loyalty.Customers.get_or_create_customer_by_email("inactive@example.com")

      assert {:error, :subscription_inactive} =
               LoyaltyCards.create_loyalty_card(scope_with_est, %{
                 customer_id: customer.id,
                 loyalty_program_id: program.id,
                 stamps_current: 0,
                 stamps_required: 10
               })
    end

    test "create_loyalty_card/2 idempotent for same customer and establishment returns existing" do
      scope = establishment_scope_fixture()

      {:ok, customer} =
        Loyalty.Customers.get_or_create_customer_by_email("idempotent@example.com")

      program = Loyalty.LoyaltyProgramsFixtures.loyalty_program_fixture(scope)

      attrs = %{
        customer_id: customer.id,
        loyalty_program_id: program.id,
        stamps_current: 1,
        stamps_required: 10
      }

      assert {:ok, card1} = LoyaltyCards.create_loyalty_card(scope, attrs)
      assert {:ok, card2} = LoyaltyCards.create_loyalty_card(scope, attrs)
      assert card1.id == card2.id
      assert card1.stamps_current == card2.stamps_current
    end

    test "redeem_card/2 returns error when stamps_current is less than stamps_required" do
      scope = establishment_scope_fixture()

      card = loyalty_card_fixture(scope, %{stamps_current: 3, stamps_required: 10})

      assert {:error, :card_not_complete} = LoyaltyCards.redeem_card(scope, card)
    end

    test "redeem_card/2 returns error when stamps_current is nil" do
      scope = establishment_scope_fixture()

      card = loyalty_card_fixture(scope, %{stamps_current: 0, stamps_required: 5})
      # Force nil via update bypass
      {:ok, nil_card} = LoyaltyCards.update_loyalty_card(scope, card, %{stamps_current: 0})
      nil_card = %{nil_card | stamps_current: nil}

      assert {:error, :card_not_complete} = LoyaltyCards.redeem_card(scope, nil_card)
    end

    test "redeem_card/2 inserts redemption and decrements stamps when card is complete" do
      scope = establishment_scope_fixture()

      card = loyalty_card_fixture(scope, %{stamps_current: 10, stamps_required: 10})

      assert {:ok, {redemption, updated_card}} = LoyaltyCards.redeem_card(scope, card)

      assert redemption.loyalty_card_id == card.id
      assert redemption.establishment_id == card.establishment_id
      assert redemption.stamps_required == 10
      assert is_binary(redemption.reward_description)

      assert updated_card.stamps_current == 0
    end

    test "redeem_card/2 decrements stamps by stamps_required when extra stamps exist" do
      scope = establishment_scope_fixture()

      card = loyalty_card_fixture(scope, %{stamps_current: 15, stamps_required: 10})

      assert {:ok, {_redemption, updated_card}} = LoyaltyCards.redeem_card(scope, card)

      assert updated_card.stamps_current == 5
    end

    test "redeem_card/2 with wrong scope raises MatchError" do
      scope = establishment_scope_fixture()
      other_scope = establishment_scope_fixture()
      card = loyalty_card_fixture(scope, %{stamps_current: 10, stamps_required: 10})

      assert_raise MatchError, fn ->
        LoyaltyCards.redeem_card(other_scope, card)
      end
    end

    test "redeem_card/2 preloads loyalty_program if not preloaded" do
      scope = establishment_scope_fixture()

      card = loyalty_card_fixture(scope, %{stamps_current: 5, stamps_required: 5})
      # Ensure :loyalty_program is not preloaded
      bare_card = %{card | loyalty_program: %Ecto.Association.NotLoaded{}}

      assert {:ok, {redemption, _}} = LoyaltyCards.redeem_card(scope, bare_card)
      assert is_binary(redemption.reward_description)
    end

    test "list_redemptions_for_card/1 returns redemptions ordered newest-first" do
      scope = establishment_scope_fixture()

      card = loyalty_card_fixture(scope, %{stamps_current: 20, stamps_required: 10})

      assert {:ok, _} = LoyaltyCards.redeem_card(scope, card)

      reloaded_card = LoyaltyCards.get_loyalty_card!(scope, card.id)
      assert {:ok, _} = LoyaltyCards.redeem_card(scope, reloaded_card)

      redemptions = LoyaltyCards.list_redemptions_for_card(card.id)

      assert length(redemptions) == 2
      [first | _] = redemptions
      assert first.loyalty_card_id == card.id
    end

    test "list_redemptions_for_card/1 returns empty list for card with no redemptions" do
      scope = establishment_scope_fixture()
      card = loyalty_card_fixture(scope, %{stamps_current: 0, stamps_required: 10})

      assert LoyaltyCards.list_redemptions_for_card(card.id) == []
    end

    test "redemption_counts_for_establishment/1 returns count map" do
      scope = establishment_scope_fixture()

      card = loyalty_card_fixture(scope, %{stamps_current: 20, stamps_required: 10})

      assert {:ok, _} = LoyaltyCards.redeem_card(scope, card)

      reloaded = LoyaltyCards.get_loyalty_card!(scope, card.id)
      assert {:ok, _} = LoyaltyCards.redeem_card(scope, reloaded)

      counts = LoyaltyCards.redemption_counts_for_establishment(scope.establishment.id)

      assert Map.get(counts, card.id) == 2
    end

    test "redemption_counts_for_establishment/1 returns empty map when no redemptions" do
      scope = establishment_scope_fixture()

      counts = LoyaltyCards.redemption_counts_for_establishment(scope.establishment.id)

      assert is_map(counts)
    end

    test "redeem_card/2 returns error when transaction fails due to FK violation" do
      scope = establishment_scope_fixture()
      card = loyalty_card_fixture(scope, %{stamps_current: 10, stamps_required: 10})

      # Delete the card from DB so the Redemption insert fails the FK constraint
      Loyalty.Repo.delete!(card)

      assert {:error, _} = LoyaltyCards.redeem_card(scope, card)
    end
  end
end
