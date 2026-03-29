defmodule Loyalty.LoyaltyCards.Redemption do
  use Ecto.Schema
  import Ecto.Changeset

  alias Loyalty.{
    Establishments.Establishment,
    LoyaltyCards.LoyaltyCard,
    LoyaltyPrograms.Customer
  }

  @type t() :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "redemptions" do
    field :reward_description, :string
    field :stamps_required, :integer

    belongs_to :loyalty_card, LoyaltyCard
    belongs_to :establishment, Establishment
    belongs_to :customer, Customer

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(redemption, attrs) do
    redemption
    |> cast(attrs, [
      :loyalty_card_id,
      :establishment_id,
      :customer_id,
      :reward_description,
      :stamps_required
    ])
    |> validate_required([
      :loyalty_card_id,
      :establishment_id,
      :customer_id,
      :reward_description,
      :stamps_required
    ])
    |> foreign_key_constraint(:loyalty_card_id)
    |> foreign_key_constraint(:establishment_id)
    |> foreign_key_constraint(:customer_id)
  end
end
