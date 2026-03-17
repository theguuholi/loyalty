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
end
