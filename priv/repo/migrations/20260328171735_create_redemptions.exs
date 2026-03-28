defmodule Loyalty.Repo.Migrations.CreateRedemptions do
  use Ecto.Migration

  def change do
    create table(:redemptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :loyalty_card_id, references(:loyalty_cards, type: :binary_id, on_delete: :delete_all)
      add :establishment_id, references(:establishments, type: :binary_id, on_delete: :delete_all)
      add :customer_id, references(:customers, type: :binary_id, on_delete: :nothing)
      add :reward_description, :string, null: false
      add :stamps_required, :integer, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:redemptions, [:loyalty_card_id])
    create index(:redemptions, [:establishment_id])
    create index(:redemptions, [:customer_id])
  end
end
