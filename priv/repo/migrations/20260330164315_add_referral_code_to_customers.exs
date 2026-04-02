defmodule Loyalty.Repo.Migrations.AddReferralCodeToCustomers do
  use Ecto.Migration

  def change do
    alter table(:customers) do
      add :referral_code, :string, null: true
    end

    execute(
      "UPDATE customers SET referral_code = replace(gen_random_uuid()::text, '-', '') WHERE referral_code IS NULL"
    )

    execute("ALTER TABLE customers ALTER COLUMN referral_code SET NOT NULL")

    create unique_index(:customers, [:referral_code])
  end
end
