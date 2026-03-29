defmodule Loyalty.LoyaltyCards.LoyaltyCard do
  use Ecto.Schema
  import Ecto.Changeset

  alias Loyalty.{
    Establishments.Establishment,
    LoyaltyPrograms.Customer,
    LoyaltyPrograms.LoyaltyProgram
  }

  @type t() :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "loyalty_cards" do
    field :stamps_current, :integer
    field :stamps_required, :integer

    # Virtual fields used only by the new-card form
    field :email, :string, virtual: true
    field :whatsapp_number, :string, virtual: true

    belongs_to :customer, Customer
    belongs_to :loyalty_program, LoyaltyProgram
    belongs_to :establishment, Establishment

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(loyalty_card, attrs, establishment_scope) do
    loyalty_card
    |> cast(attrs, [:stamps_current, :stamps_required, :customer_id, :loyalty_program_id])
    |> validate_required([:stamps_current, :stamps_required, :customer_id])
    |> foreign_key_constraint(:customer_id)
    |> foreign_key_constraint(:loyalty_program_id)
    |> foreign_key_constraint(:establishment_id)
    |> put_change(:establishment_id, establishment_scope.establishment.id)
  end

  @doc """
  Changeset for the new-loyalty-card form. Validates that at least one contact
  field (email or whatsapp_number) is present. Does not touch customer_id or
  establishment_id — those are resolved by the LiveView after this changeset passes.
  """
  def new_card_changeset(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, [:email, :whatsapp_number, :stamps_current, :stamps_required])
    |> validate_at_least_one_contact()
    |> validate_number(:stamps_required, greater_than: 0)
    |> validate_number(:stamps_current, greater_than_or_equal_to: 0)
  end

  defp validate_at_least_one_contact(changeset) do
    email = changeset |> get_field(:email) |> to_string() |> String.trim()
    whatsapp = changeset |> get_field(:whatsapp_number) |> to_string() |> String.trim()

    if email == "" and whatsapp == "" do
      add_error(changeset, :email, "enter an email or WhatsApp number")
    else
      changeset
    end
  end
end
