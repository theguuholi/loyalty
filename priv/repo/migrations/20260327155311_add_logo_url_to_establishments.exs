defmodule Loyalty.Repo.Migrations.AddLogoUrlToEstablishments do
  use Ecto.Migration

  def change do
    alter table(:establishments) do
      add :logo_url, :string
    end
  end
end
