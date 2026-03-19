defmodule Loyalty.LoyaltyCardsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Loyalty.LoyaltyCards` context.
  """

  @doc """
  Generate a loyalty_card. Ensures a loyalty program and customer exist for the scope.
  """
  def loyalty_card_fixture(scope, attrs \\ %{}) do
    program =
      case Loyalty.LoyaltyPrograms.list_loyalty_programs(scope) do
        [p | _] -> p
        [] -> Loyalty.LoyaltyProgramsFixtures.loyalty_program_fixture(scope)
      end

    {:ok, customer} =
      Loyalty.Customers.get_or_create_customer_by_email(
        "customer-#{scope.establishment.id}@example.com"
      )

    attrs =
      Enum.into(attrs, %{
        stamps_current: 42,
        stamps_required: 42,
        customer_id: customer.id,
        loyalty_program_id: program.id
      })

    {:ok, loyalty_card} = Loyalty.LoyaltyCards.create_loyalty_card(scope, attrs)
    loyalty_card
  end
end
