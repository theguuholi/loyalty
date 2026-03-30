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
    field :logo_url, :string
    field :referral_code, :string
    field :referred_by_establishment_id, :binary_id
    field :free_access_until, :utc_datetime

    has_one :loyalty_program, LoyaltyProgram, foreign_key: :establishment_id
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(establishment, attrs, user_scope) do
    establishment
    |> cast(attrs, [:name, :logo_url])
    |> validate_required([:name])
    |> put_change(:user_id, user_scope.user.id)
    |> unique_constraint(:referral_code)
    |> prepare_changes(&generate_referral_code/1)
  end

  defp generate_referral_code(changeset) do
    if get_field(changeset, :referral_code) do
      changeset
    else
      code =
        6
        |> :crypto.strong_rand_bytes()
        |> Base.url_encode64(padding: false)
        |> String.slice(0, 8)

      put_change(changeset, :referral_code, code)
    end
  end
end
