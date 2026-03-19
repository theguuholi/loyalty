defmodule Loyalty.Repo.Migrations.AddBillingFieldsToEstablishments do
  use Ecto.Migration

  def change do
    alter table(:establishments) do
      add :stripe_customer_id, :string
      add :stripe_subscription_id, :string
      add :subscription_status, :string
    end
  end
end
