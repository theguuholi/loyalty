defmodule Loyalty.Establishments do
  @moduledoc """
  The Establishments context.
  """

  import Ecto.Query, warn: false
  alias Loyalty.Repo

  alias Loyalty.{Accounts.Scope, Billing, Establishments.Establishment, LoyaltyCards.LoyaltyCard}

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
    if list_establishments(scope) != [] do
      {:error, :establishment_limit_reached}
    else
      with {:ok, establishment = %Establishment{}} <-
             %Establishment{}
             |> Establishment.changeset(attrs, scope)
             |> Repo.insert() do
        broadcast_establishment(scope, {:created, establishment})
        {:ok, establishment}
      end
    end
  end

  @doc """
  Counts loyalty cards for an establishment (each card = one tracked client slot).
  """
  def count_loyalty_cards(establishment_id) when is_binary(establishment_id) do
    from(c in LoyaltyCard,
      where: c.establishment_id == ^establishment_id,
      select: count(c.id)
    )
    |> Repo.one!()
  end

  @doc """
  Returns `:ok` if a **new** loyalty card may be created for this establishment.

  Free plan: up to `Billing.free_client_limit/0` cards.
  Paid plan (`active` / `trialing`): up to `Billing.paid_client_limit/0` cards.
  Other subscription states: `{:error, :subscription_inactive}`.
  """
  def check_new_loyalty_card_allowed(%Establishment{} = establishment) do
    n = count_loyalty_cards(establishment.id)
    free? = Billing.on_free_plan?(establishment)
    paid_ok? = Billing.paid_subscription_allows_new_clients?(establishment)

    cond do
      free? and n < Billing.free_client_limit() ->
        :ok

      free? ->
        {:error, :client_limit_reached}

      paid_ok? and n < Billing.paid_client_limit() ->
        :ok

      paid_ok? ->
        {:error, :client_limit_reached}

      true ->
        {:error, :subscription_inactive}
    end
  end

  @doc """
  Updates Stripe billing fields on an establishment (webhooks only). Does not use user scope.
  """
  def apply_stripe_billing_attrs(establishment_id, attrs)
      when is_binary(establishment_id) and is_map(attrs) do
    allowed = [:stripe_customer_id, :stripe_subscription_id, :subscription_status]

    case Repo.get(Establishment, establishment_id) do
      nil ->
        {:error, :not_found}

      est ->
        case est
             |> Ecto.Changeset.cast(attrs, allowed)
             |> Repo.update() do
          {:ok, updated} ->
            Phoenix.PubSub.broadcast(
              Loyalty.PubSub,
              "user:#{updated.user_id}:establishments",
              {:updated, updated}
            )

            {:ok, updated}

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  @doc """
  Finds an establishment by Stripe subscription id (for subscription webhooks).
  """
  def get_establishment_by_stripe_subscription_id(subscription_id)
      when is_binary(subscription_id) do
    Repo.get_by(Establishment, stripe_subscription_id: subscription_id)
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
