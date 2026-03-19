defmodule Loyalty.Repo.Migrations.CreateLoyaltyCards do
  use Ecto.Migration

  def change do
    create table(:loyalty_cards, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :stamps_current, :integer
      add :stamps_required, :integer
      add :customer_id, references(:customers, on_delete: :nothing, type: :binary_id)

      add :loyalty_program_id,
          references(:loyalty_programs, on_delete: :nothing, type: :binary_id)

      add :establishment_id, references(:establishments, type: :binary_id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:loyalty_cards, [:establishment_id])

    create index(:loyalty_cards, [:customer_id])
    create index(:loyalty_cards, [:loyalty_program_id])
  end
end
