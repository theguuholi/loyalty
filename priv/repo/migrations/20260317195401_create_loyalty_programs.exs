defmodule Loyalty.Repo.Migrations.CreateLoyaltyPrograms do
  use Ecto.Migration

  def change do
    create table(:loyalty_programs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :stamps_required, :integer
      add :reward_description, :string
      add :establishment_id, references(:establishments, type: :binary_id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:loyalty_programs, [:establishment_id])
  end
end
