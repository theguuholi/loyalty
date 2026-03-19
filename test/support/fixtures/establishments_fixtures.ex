defmodule Loyalty.EstablishmentsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Loyalty.Establishments` context.
  """
  alias Loyalty.Accounts.Scope

  @doc """
  Generate a establishment.
  """
  def establishment_fixture(scope, attrs \\ %{}) do
    {billing_attrs, attrs} =
      Map.split(attrs, [:stripe_customer_id, :stripe_subscription_id, :subscription_status])

    attrs =
      Enum.into(attrs, %{
        name: "some name"
      })

    {:ok, establishment} = Loyalty.Establishments.create_establishment(scope, attrs)

    if billing_attrs != %{} do
      {:ok, establishment} =
        establishment
        |> Ecto.Changeset.change(billing_attrs)
        |> Loyalty.Repo.update()

      establishment
    else
      establishment
    end
  end

  def establishment_scope_fixture(scope \\ nil) do
    scope = scope || Loyalty.AccountsFixtures.user_scope_fixture()
    establishment = establishment_fixture(scope)
    Scope.put_establishment(scope, establishment)
  end
end
