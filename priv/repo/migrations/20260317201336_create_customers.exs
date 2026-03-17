defmodule Loyalty.Repo.Migrations.CreateCustomers do
  use Ecto.Migration

  def change do
    create table(:customers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:customers, [:email])
  end
end
