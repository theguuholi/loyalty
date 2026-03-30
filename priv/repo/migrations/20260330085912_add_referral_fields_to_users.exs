defmodule Loyalty.Repo.Migrations.AddReferralFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :establishment_referral_code, :string
      add :referred_by_customer_id, references(:customers, type: :binary_id, on_delete: :nothing)
    end

    create index(:users, [:referred_by_customer_id])
  end
end
