defmodule Loyalty.Establishments do
  @moduledoc """
  The Establishments context.
  """

  import Ecto.Query, warn: false
  alias Loyalty.Repo

  alias Loyalty.Accounts.Scope
  alias Loyalty.Establishments.Establishment

  @doc """
  Subscribes to scoped notifications about any establishment changes.

  The broadcasted messages match the pattern:

    * {:created, %Establishment{}}
    * {:updated, %Establishment{}}
    * {:deleted, %Establishment{}}

  """
  def subscribe_establishments(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(Loyalty.PubSub, "user:#{key}:establishments")
  end

  defp broadcast_establishment(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(Loyalty.PubSub, "user:#{key}:establishments", message)
  end

  @doc """
  Returns the list of establishments.

  ## Examples

      iex> list_establishments(scope)
      [%Establishment{}, ...]

  """
  def list_establishments(%Scope{} = scope) do
    Repo.all_by(Establishment, user_id: scope.user.id)
  end

  @doc """
  Gets a single establishment.

  Raises `Ecto.NoResultsError` if the Establishment does not exist.

  ## Examples

      iex> get_establishment!(scope, 123)
      %Establishment{}

      iex> get_establishment!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_establishment!(%Scope{} = scope, id) do
    Repo.get_by!(Establishment, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a establishment.

  ## Examples

      iex> create_establishment(scope, %{field: value})
      {:ok, %Establishment{}}

      iex> create_establishment(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_establishment(%Scope{} = scope, attrs) do
    with {:ok, establishment = %Establishment{}} <-
           %Establishment{}
           |> Establishment.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_establishment(scope, {:created, establishment})
      {:ok, establishment}
    end
  end

  @doc """
  Updates a establishment.

  ## Examples

      iex> update_establishment(scope, establishment, %{field: new_value})
      {:ok, %Establishment{}}

      iex> update_establishment(scope, establishment, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_establishment(%Scope{} = scope, %Establishment{} = establishment, attrs) do
    true = establishment.user_id == scope.user.id

    with {:ok, establishment = %Establishment{}} <-
           establishment
           |> Establishment.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_establishment(scope, {:updated, establishment})
      {:ok, establishment}
    end
  end

  @doc """
  Deletes a establishment.

  ## Examples

      iex> delete_establishment(scope, establishment)
      {:ok, %Establishment{}}

      iex> delete_establishment(scope, establishment)
      {:error, %Ecto.Changeset{}}

  """
  def delete_establishment(%Scope{} = scope, %Establishment{} = establishment) do
    true = establishment.user_id == scope.user.id

    with {:ok, establishment = %Establishment{}} <-
           Repo.delete(establishment) do
      broadcast_establishment(scope, {:deleted, establishment})
      {:ok, establishment}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking establishment changes.

  ## Examples

      iex> change_establishment(scope, establishment)
      %Ecto.Changeset{data: %Establishment{}}

  """
  def change_establishment(%Scope{} = scope, %Establishment{} = establishment, attrs \\ %{}) do
    true = establishment.user_id == scope.user.id

    Establishment.changeset(establishment, attrs, scope)
  end
end
