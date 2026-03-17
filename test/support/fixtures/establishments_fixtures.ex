defmodule Loyalty.EstablishmentsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Loyalty.Establishments` context.
  """
  import Loyalty.AccountsFixtures, only: [user_scope_fixture: 0]
  alias Loyalty.Accounts.Scope

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

  def establishment_scope_fixture(scope \\ user_scope_fixture()) do
    establishment = establishment_fixture(scope)
    Scope.put_establishment(scope, establishment)
  end
end
