defmodule Loyalty.LoyaltyPrograms.Customer do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @type t() :: %__MODULE__{}

  schema "customers" do
    field :email, :string
    field :whatsapp_number, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(customer, attrs) do
    customer
    |> cast(attrs, [:email, :whatsapp_number])
    |> validate_at_least_one_contact()
    |> validate_email_format()
    |> validate_whatsapp_format()
    |> unique_constraint(:email)
    |> unique_constraint(:whatsapp_number)
  end

  @doc """
  Changeset for updating contact info on an existing customer (adding email or whatsapp).
  """
  def update_changeset(customer, attrs) do
    customer
    |> cast(attrs, [:email, :whatsapp_number])
    |> validate_email_format()
    |> validate_whatsapp_format()
    |> unique_constraint(:email)
    |> unique_constraint(:whatsapp_number)
  end

  defp validate_at_least_one_contact(changeset) do
    email = get_field(changeset, :email)
    whatsapp = get_field(changeset, :whatsapp_number)

    if blank_or_nil?(email) and blank_or_nil?(whatsapp) do
      add_error(changeset, :base, "at least one of email or WhatsApp number is required")
    else
      changeset
    end
  end

  defp validate_email_format(changeset) do
    changeset
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
  end

  defp validate_whatsapp_format(changeset) do
    validate_format(changeset, :whatsapp_number, ~r/^\+[1-9]\d{7,14}$/,
      message: "must be in E.164 format (e.g. +5511999999999)"
    )
  end

  defp blank_or_nil?(nil), do: true
  defp blank_or_nil?(""), do: true
  defp blank_or_nil?(str) when is_binary(str), do: String.trim(str) == ""
end
