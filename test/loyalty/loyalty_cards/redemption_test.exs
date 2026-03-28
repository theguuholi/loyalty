defmodule Loyalty.LoyaltyCards.RedemptionTest do
  use Loyalty.DataCase

  import Loyalty.EstablishmentsFixtures, only: [establishment_scope_fixture: 0]

  alias Loyalty.LoyaltyCards.Redemption

  describe "changeset/2" do
    setup do
      scope = establishment_scope_fixture()

      {:ok, customer} =
        Loyalty.Customers.get_or_create_customer_by_email("redemption-test@example.com")

      program = Loyalty.LoyaltyProgramsFixtures.loyalty_program_fixture(scope)

      {:ok, loyalty_card} =
        Loyalty.LoyaltyCards.create_loyalty_card(scope, %{
          customer_id: customer.id,
          loyalty_program_id: program.id,
          stamps_current: 0,
          stamps_required: 10
        })

      %{
        scope: scope,
        customer: customer,
        loyalty_card: loyalty_card
      }
    end

    test "valid attrs produces a valid changeset", %{
      scope: scope,
      customer: customer,
      loyalty_card: loyalty_card
    } do
      attrs = %{
        loyalty_card_id: loyalty_card.id,
        establishment_id: scope.establishment.id,
        customer_id: customer.id,
        reward_description: "Free Coffee",
        stamps_required: 10
      }

      changeset = Redemption.changeset(%Redemption{}, attrs)
      assert changeset.valid?
    end

    test "missing required fields returns invalid changeset" do
      changeset = Redemption.changeset(%Redemption{}, %{})
      refute changeset.valid?

      errors = errors_on(changeset)
      assert :loyalty_card_id in Map.keys(errors)
      assert :establishment_id in Map.keys(errors)
      assert :customer_id in Map.keys(errors)
      assert :reward_description in Map.keys(errors)
      assert :stamps_required in Map.keys(errors)
    end

    test "missing loyalty_card_id returns invalid changeset", %{
      scope: scope,
      customer: customer
    } do
      attrs = %{
        establishment_id: scope.establishment.id,
        customer_id: customer.id,
        reward_description: "Free Coffee",
        stamps_required: 10
      }

      changeset = Redemption.changeset(%Redemption{}, attrs)
      refute changeset.valid?
      assert %{loyalty_card_id: [_ | _]} = errors_on(changeset)
    end

    test "missing reward_description returns invalid changeset", %{
      scope: scope,
      customer: customer,
      loyalty_card: loyalty_card
    } do
      attrs = %{
        loyalty_card_id: loyalty_card.id,
        establishment_id: scope.establishment.id,
        customer_id: customer.id,
        stamps_required: 10
      }

      changeset = Redemption.changeset(%Redemption{}, attrs)
      refute changeset.valid?
      assert %{reward_description: [_ | _]} = errors_on(changeset)
    end
  end
end
