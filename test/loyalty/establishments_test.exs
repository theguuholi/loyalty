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
  end
end
