defmodule Loyalty.Repo.Migrations.CreateEstablishments do
  use Ecto.Migration

  def change do
    create table(:establishments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:establishments, [:user_id])
  end
end
