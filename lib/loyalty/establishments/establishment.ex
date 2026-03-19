defmodule Loyalty.Establishments.Establishment do
  use Ecto.Schema
  import Ecto.Changeset
  alias Loyalty.LoyaltyPrograms.LoyaltyProgram

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "establishments" do
    field :name, :string
    field :user_id, :binary_id
    field :stripe_customer_id, :string
    field :stripe_subscription_id, :string
    field :subscription_status, :string

    has_one :loyalty_program, LoyaltyProgram, foreign_key: :establishment_id
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(establishment, attrs, user_scope) do
    establishment
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> put_change(:user_id, user_scope.user.id)
  end
end
