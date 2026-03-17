defmodule Loyalty.EstablishmentsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Loyalty.Establishments` context.
  """

  @doc """
  Generate a establishment.
  """
  def establishment_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "some name"
      })

    {:ok, establishment} = Loyalty.Establishments.create_establishment(scope, attrs)
    establishment
  end
end
