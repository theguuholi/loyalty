defmodule Loyalty.Repo.Migrations.AddReferralFieldsToEstablishments do
  use Ecto.Migration

  def change do
    alter table(:establishments) do
      add :referral_code, :string

      add :referred_by_establishment_id,
          references(:establishments, type: :binary_id, on_delete: :nothing)

      add :free_access_until, :utc_datetime
    end

    # Backfill existing rows with a unique referral code derived from their id before enforcing NOT NULL
    execute(
      "UPDATE establishments SET referral_code = replace(id::text, '-', '') WHERE referral_code IS NULL",
      ""
    )

    alter table(:establishments) do
      modify :referral_code, :string, null: false
    end

    create unique_index(:establishments, [:referral_code])
    create index(:establishments, [:referred_by_establishment_id])
  end
end
