defmodule Loyalty.Repo.Migrations.AddWhatsappToCustomers do
  use Ecto.Migration

  def change do
    alter table(:customers) do
      add :whatsapp_number, :string
    end

    create unique_index(:customers, [:whatsapp_number])
  end
end
