defmodule Loyalty.LoyaltyPrograms do
  @moduledoc """
  The LoyaltyPrograms context.
  """

  import Ecto.Query, warn: false
  alias Loyalty.Repo

  alias Loyalty.Accounts.Scope
  alias Loyalty.LoyaltyPrograms.LoyaltyProgram

  @doc """
  Subscribes to scoped notifications about any loyalty_program changes.

  The broadcasted messages match the pattern:

    * {:created, %LoyaltyProgram{}}
    * {:updated, %LoyaltyProgram{}}
    * {:deleted, %LoyaltyProgram{}}

  """
  def subscribe_loyalty_programs(%Scope{} = scope) do
    key = scope.establishment.id

    Phoenix.PubSub.subscribe(Loyalty.PubSub, "establishment:#{key}:loyalty_programs")
  end

  defp broadcast_loyalty_program(%Scope{} = scope, message) do
    key = scope.establishment.id

    Phoenix.PubSub.broadcast(Loyalty.PubSub, "establishment:#{key}:loyalty_programs", message)
  end

  @doc """
  Returns the list of loyalty_programs.

  ## Examples

      iex> list_loyalty_programs(scope)
      [%LoyaltyProgram{}, ...]

  """
  def list_loyalty_programs(%Scope{} = scope) do
    Repo.all_by(LoyaltyProgram, establishment_id: scope.establishment.id)
  end

  @doc """
  Gets a single loyalty_program.

  Raises `Ecto.NoResultsError` if the Loyalty program does not exist.

  ## Examples

      iex> get_loyalty_program!(scope, 123)
      %LoyaltyProgram{}

      iex> get_loyalty_program!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_loyalty_program!(%Scope{} = scope, id) do
    Repo.get_by!(LoyaltyProgram, id: id, establishment_id: scope.establishment.id)
  end

  @doc """
  Creates a loyalty_program.

  ## Examples

      iex> create_loyalty_program(scope, %{field: value})
      {:ok, %LoyaltyProgram{}}

      iex> create_loyalty_program(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_loyalty_program(%Scope{} = scope, attrs) do
    with {:ok, loyalty_program = %LoyaltyProgram{}} <-
           %LoyaltyProgram{}
           |> LoyaltyProgram.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_loyalty_program(scope, {:created, loyalty_program})
      {:ok, loyalty_program}
    end
  end

  @doc """
  Updates a loyalty_program.

  ## Examples

      iex> update_loyalty_program(scope, loyalty_program, %{field: new_value})
      {:ok, %LoyaltyProgram{}}

      iex> update_loyalty_program(scope, loyalty_program, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_loyalty_program(%Scope{} = scope, %LoyaltyProgram{} = loyalty_program, attrs) do
    true = loyalty_program.establishment_id == scope.establishment.id

    with {:ok, loyalty_program = %LoyaltyProgram{}} <-
           loyalty_program
           |> LoyaltyProgram.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_loyalty_program(scope, {:updated, loyalty_program})
      {:ok, loyalty_program}
    end
  end

  @doc """
  Deletes a loyalty_program.

  ## Examples

      iex> delete_loyalty_program(scope, loyalty_program)
      {:ok, %LoyaltyProgram{}}

      iex> delete_loyalty_program(scope, loyalty_program)
      {:error, %Ecto.Changeset{}}

  """
  def delete_loyalty_program(%Scope{} = scope, %LoyaltyProgram{} = loyalty_program) do
    true = loyalty_program.establishment_id == scope.establishment.id

    with {:ok, loyalty_program = %LoyaltyProgram{}} <-
           Repo.delete(loyalty_program) do
      broadcast_loyalty_program(scope, {:deleted, loyalty_program})
      {:ok, loyalty_program}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking loyalty_program changes.

  ## Examples

      iex> change_loyalty_program(scope, loyalty_program)
      %Ecto.Changeset{data: %LoyaltyProgram{}}

  """
  def change_loyalty_program(%Scope{} = scope, %LoyaltyProgram{} = loyalty_program, attrs \\ %{}) do
    true = loyalty_program.establishment_id == scope.establishment.id

    LoyaltyProgram.changeset(loyalty_program, attrs, scope)
  end
end
