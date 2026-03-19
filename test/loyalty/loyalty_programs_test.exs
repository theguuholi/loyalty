defmodule Loyalty.LoyaltyProgramsTest do
  use Loyalty.DataCase

  alias Loyalty.LoyaltyPrograms

  describe "loyalty_programs" do
    alias Loyalty.LoyaltyPrograms.LoyaltyProgram

    import Loyalty.EstablishmentsFixtures, only: [establishment_scope_fixture: 0]
    import Loyalty.LoyaltyProgramsFixtures

    @invalid_attrs %{name: nil, stamps_required: nil, reward_description: nil}

    test "list_loyalty_programs/1 returns all scoped loyalty_programs" do
      scope = establishment_scope_fixture()
      other_scope = establishment_scope_fixture()
      loyalty_program = loyalty_program_fixture(scope)
      other_loyalty_program = loyalty_program_fixture(other_scope)
      assert LoyaltyPrograms.list_loyalty_programs(scope) == [loyalty_program]
      assert LoyaltyPrograms.list_loyalty_programs(other_scope) == [other_loyalty_program]
    end

    test "get_loyalty_program!/2 returns the loyalty_program with given id" do
      scope = establishment_scope_fixture()
      loyalty_program = loyalty_program_fixture(scope)
      other_scope = establishment_scope_fixture()
      assert LoyaltyPrograms.get_loyalty_program!(scope, loyalty_program.id) == loyalty_program

      assert_raise Ecto.NoResultsError, fn ->
        LoyaltyPrograms.get_loyalty_program!(other_scope, loyalty_program.id)
      end
    end

    test "create_loyalty_program/2 with valid data creates a loyalty_program" do
      valid_attrs = %{
        name: "some name",
        stamps_required: 42,
        reward_description: "some reward_description"
      }

      scope = establishment_scope_fixture()

      assert {:ok, %LoyaltyProgram{} = loyalty_program} =
               LoyaltyPrograms.create_loyalty_program(scope, valid_attrs)

      assert loyalty_program.name == "some name"
      assert loyalty_program.stamps_required == 42
      assert loyalty_program.reward_description == "some reward_description"
      assert loyalty_program.establishment_id == scope.establishment.id
    end

    test "create_loyalty_program/2 with invalid data returns error changeset" do
      scope = establishment_scope_fixture()

      assert {:error, %Ecto.Changeset{}} =
               LoyaltyPrograms.create_loyalty_program(scope, @invalid_attrs)
    end

    test "update_loyalty_program/3 with valid data updates the loyalty_program" do
      scope = establishment_scope_fixture()
      loyalty_program = loyalty_program_fixture(scope)

      update_attrs = %{
        name: "some updated name",
        stamps_required: 43,
        reward_description: "some updated reward_description"
      }

      assert {:ok, %LoyaltyProgram{} = loyalty_program} =
               LoyaltyPrograms.update_loyalty_program(scope, loyalty_program, update_attrs)

      assert loyalty_program.name == "some updated name"
      assert loyalty_program.stamps_required == 43
      assert loyalty_program.reward_description == "some updated reward_description"
    end

    test "update_loyalty_program/3 with invalid scope raises" do
      scope = establishment_scope_fixture()
      other_scope = establishment_scope_fixture()
      loyalty_program = loyalty_program_fixture(scope)

      assert_raise MatchError, fn ->
        LoyaltyPrograms.update_loyalty_program(other_scope, loyalty_program, %{})
      end
    end

    test "update_loyalty_program/3 with invalid data returns error changeset" do
      scope = establishment_scope_fixture()
      loyalty_program = loyalty_program_fixture(scope)

      assert {:error, %Ecto.Changeset{}} =
               LoyaltyPrograms.update_loyalty_program(scope, loyalty_program, @invalid_attrs)

      assert loyalty_program == LoyaltyPrograms.get_loyalty_program!(scope, loyalty_program.id)
    end

    test "delete_loyalty_program/2 deletes the loyalty_program" do
      scope = establishment_scope_fixture()
      loyalty_program = loyalty_program_fixture(scope)

      assert {:ok, %LoyaltyProgram{}} =
               LoyaltyPrograms.delete_loyalty_program(scope, loyalty_program)

      assert_raise Ecto.NoResultsError, fn ->
        LoyaltyPrograms.get_loyalty_program!(scope, loyalty_program.id)
      end
    end

    test "delete_loyalty_program/2 with invalid scope raises" do
      scope = establishment_scope_fixture()
      other_scope = establishment_scope_fixture()
      loyalty_program = loyalty_program_fixture(scope)

      assert_raise MatchError, fn ->
        LoyaltyPrograms.delete_loyalty_program(other_scope, loyalty_program)
      end
    end

    test "change_loyalty_program/2 returns a loyalty_program changeset" do
      scope = establishment_scope_fixture()
      loyalty_program = loyalty_program_fixture(scope)
      assert %Ecto.Changeset{} = LoyaltyPrograms.change_loyalty_program(scope, loyalty_program)
    end
  end
end
