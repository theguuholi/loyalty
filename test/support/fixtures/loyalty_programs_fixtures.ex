defmodule Loyalty.LoyaltyProgramsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Loyalty.LoyaltyPrograms` context.
  """

  @doc """
  Generate a loyalty_program.
  """
  def loyalty_program_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "some name",
        reward_description: "some reward_description",
        stamps_required: 42
      })

    {:ok, loyalty_program} = Loyalty.LoyaltyPrograms.create_loyalty_program(scope, attrs)
    loyalty_program
  end
end
