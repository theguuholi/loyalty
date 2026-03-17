defmodule Loyalty.LoyaltyPrograms.LoyaltyProgram do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "loyalty_programs" do
    field :name, :string
    field :stamps_required, :integer
    field :reward_description, :string
    field :establishment_id, :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(loyalty_program, attrs, establishment_scope) do
    loyalty_program
    |> cast(attrs, [:name, :stamps_required, :reward_description])
    |> validate_required([:name, :stamps_required, :reward_description])
    |> validate_number(:stamps_required, greater_than: 0, less_than_or_equal_to: 999)
    |> validate_length(:reward_description, max: 500)
    |> foreign_key_constraint(:establishment_id)
    |> put_change(:establishment_id, establishment_scope.establishment.id)
  end
end
