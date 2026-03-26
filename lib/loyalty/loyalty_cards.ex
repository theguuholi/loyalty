defmodule Loyalty.LoyaltyCards do
  @moduledoc """
  The LoyaltyCards context.
  """

  import Ecto.Query, warn: false
  alias Loyalty.Repo

  alias Loyalty.{
    Accounts.Scope,
    Customers,
    Establishments,
    Establishments.Establishment,
    LoyaltyCards.LoyaltyCard,
    LoyaltyPrograms.Customer,
    WhatsApp
  }

  @doc """
  Subscribes to scoped notifications about any loyalty_card changes.

  The broadcasted messages match the pattern:

    * {:created, %LoyaltyCard{}}
    * {:updated, %LoyaltyCard{}}
    * {:deleted, %LoyaltyCard{}}

  """
  def subscribe_loyalty_cards(%Scope{} = scope) do
    key = scope.establishment.id

    Phoenix.PubSub.subscribe(Loyalty.PubSub, "establishment:#{key}:loyalty_cards")
  end

  defp broadcast_loyalty_card(%Scope{} = scope, message) do
    key = scope.establishment.id

    Phoenix.PubSub.broadcast(Loyalty.PubSub, "establishment:#{key}:loyalty_cards", message)
  end

  @doc """
  Returns the list of loyalty_cards.

  ## Examples

      iex> list_loyalty_cards(scope)
      [%LoyaltyCard{}, ...]

  """
  def list_loyalty_cards(%Scope{} = scope) do
    LoyaltyCard
    |> Repo.all_by(establishment_id: scope.establishment.id)
    |> Repo.preload([:customer, :establishment, :loyalty_program])
  end

  @doc """
  Gets a single loyalty_card.

  Raises `Ecto.NoResultsError` if the Loyalty card does not exist.

  ## Examples

      iex> get_loyalty_card!(scope, 123)
      %LoyaltyCard{}

      iex> get_loyalty_card!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_loyalty_card!(%Scope{} = scope, id) do
    Repo.get_by!(LoyaltyCard, id: id, establishment_id: scope.establishment.id)
  end

  @doc """
  Creates a loyalty_card.

  ## Examples

      iex> create_loyalty_card(scope, %{field: value})
      {:ok, %LoyaltyCard{}}

      iex> create_loyalty_card(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_loyalty_card(%Scope{} = scope, attrs) do
    establishment = Repo.get!(Establishment, scope.establishment.id)

    customer_id = attrs["customer_id"] || attrs[:customer_id]

    if is_binary(customer_id) do
      existing =
        Repo.get_by(LoyaltyCard,
          establishment_id: establishment.id,
          customer_id: customer_id
        )

      if existing do
        {:ok, existing}
      else
        do_create_loyalty_card(scope, establishment, attrs)
      end
    else
      do_create_loyalty_card(scope, establishment, attrs)
    end
  end

  defp do_create_loyalty_card(%Scope{} = scope, %Establishment{} = establishment, attrs) do
    case Establishments.check_new_loyalty_card_allowed(establishment) do
      :ok ->
        with {:ok, loyalty_card = %LoyaltyCard{}} <-
               %LoyaltyCard{}
               |> LoyaltyCard.changeset(attrs, scope)
               |> Repo.insert() do
          broadcast_loyalty_card(scope, {:created, loyalty_card})
          {:ok, loyalty_card}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Updates a loyalty_card.

  ## Examples

      iex> update_loyalty_card(scope, loyalty_card, %{field: new_value})
      {:ok, %LoyaltyCard{}}

      iex> update_loyalty_card(scope, loyalty_card, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_loyalty_card(%Scope{} = scope, %LoyaltyCard{} = loyalty_card, attrs) do
    true = loyalty_card.establishment_id == scope.establishment.id

    with {:ok, loyalty_card = %LoyaltyCard{}} <-
           loyalty_card
           |> LoyaltyCard.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_loyalty_card(scope, {:updated, loyalty_card})
      {:ok, loyalty_card}
    end
  end

  @doc """
  Deletes a loyalty_card.

  ## Examples

      iex> delete_loyalty_card(scope, loyalty_card)
      {:ok, %LoyaltyCard{}}

      iex> delete_loyalty_card(scope, loyalty_card)
      {:error, %Ecto.Changeset{}}

  """
  def delete_loyalty_card(%Scope{} = scope, %LoyaltyCard{} = loyalty_card) do
    true = loyalty_card.establishment_id == scope.establishment.id

    with {:ok, loyalty_card = %LoyaltyCard{}} <-
           Repo.delete(loyalty_card) do
      broadcast_loyalty_card(scope, {:deleted, loyalty_card})
      {:ok, loyalty_card}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking loyalty_card changes.

  ## Examples

      iex> change_loyalty_card(scope, loyalty_card)
      %Ecto.Changeset{data: %LoyaltyCard{}}

  """
  def change_loyalty_card(%Scope{} = scope, %LoyaltyCard{} = loyalty_card, attrs \\ %{}) do
    true = loyalty_card.establishment_id == scope.establishment.id

    LoyaltyCard.changeset(loyalty_card, attrs, scope)
  end

  @doc """
  Returns all loyalty cards for the customer with the given email (for "Meus cartões").
  Returns an empty list if no customer exists for that email. Cards are preloaded with
  establishment and loyalty_program.
  """
  @spec list_loyalty_cards_by_customer_email(String.t()) :: [LoyaltyCard.t()]
  def list_loyalty_cards_by_customer_email(email) when is_binary(email) do
    case Customers.get_customer_by_email(email) do
      nil ->
        []

      %Customer{id: customer_id} ->
        LoyaltyCard
        |> Ecto.Query.where([c], c.customer_id == ^customer_id)
        |> Ecto.Query.preload([:establishment, :loyalty_program])
        |> Repo.all()
    end
  end

  @doc """
  Returns all loyalty cards for the customer with the given WhatsApp number.
  Returns an empty list if no customer exists for that number.
  """
  @spec list_loyalty_cards_by_customer_whatsapp(String.t()) :: [LoyaltyCard.t()]
  def list_loyalty_cards_by_customer_whatsapp(number) when is_binary(number) do
    case Customers.get_customer_by_whatsapp(number) do
      nil ->
        []

      %Customer{id: customer_id} ->
        LoyaltyCard
        |> Ecto.Query.where([c], c.customer_id == ^customer_id)
        |> Ecto.Query.preload([:establishment, :loyalty_program])
        |> Repo.all()
    end
  end

  @doc """
  Adds one stamp to the given loyalty card. Returns `{:ok, updated_card}` or `{:error, changeset}`.
  The card must belong to the scope's establishment.
  """
  @spec add_stamp(Scope.t(), LoyaltyCard.t()) ::
          {:ok, LoyaltyCard.t()} | {:error, Ecto.Changeset.t()}
  def add_stamp(%Scope{} = scope, %LoyaltyCard{} = loyalty_card) do
    true = loyalty_card.establishment_id == scope.establishment.id

    attrs = %{stamps_current: (loyalty_card.stamps_current || 0) + 1}

    with {:ok, updated_card} <- update_loyalty_card(scope, loyalty_card, attrs) do
      notify_whatsapp(updated_card)
      {:ok, updated_card}
    end
  end

  defp notify_whatsapp(%LoyaltyCard{} = card) do
    card = Repo.preload(card, [:customer, :establishment, :loyalty_program])

    if is_binary(card.customer.whatsapp_number) do
      stamps_current = card.stamps_current || 0
      stamps_required = card.stamps_required
      reward = card.loyalty_program.reward_description
      establishment_name = card.establishment.name
      whatsapp_number = card.customer.whatsapp_number

      Task.start(fn ->
        WhatsApp.send_stamp_update(
          whatsapp_number,
          stamps_current,
          stamps_required,
          reward,
          establishment_name
        )
      end)
    end

    :ok
  end
end
