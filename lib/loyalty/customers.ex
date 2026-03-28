defmodule Loyalty.Customers do
  @moduledoc """
  Public API for customers (identified by email or WhatsApp number).
  Used by "Meus cartões" and by establishments when registering a client.
  """

  alias Loyalty.LoyaltyPrograms.Customer
  alias Loyalty.Repo

  @doc """
  Finds a customer by email. Returns the customer or `nil` if not found.
  """
  @spec get_customer_by_email(String.t()) :: Customer.t() | nil
  def get_customer_by_email(email) when is_binary(email) do
    Repo.get_by(Customer, email: String.trim(email))
  end

  @doc """
  Finds a customer by WhatsApp number. Returns the customer or `nil` if not found.
  """
  @spec get_customer_by_whatsapp(String.t()) :: Customer.t() | nil
  def get_customer_by_whatsapp(number) when is_binary(number) do
    Repo.get_by(Customer, whatsapp_number: String.trim(number))
  end

  @doc """
  Finds a customer by email, or creates one if not found. Returns `{:ok, customer}` or `{:error, changeset}`.
  """
  @spec get_or_create_customer_by_email(String.t()) ::
          {:ok, Customer.t()} | {:error, Ecto.Changeset.t()}
  def get_or_create_customer_by_email(email) when is_binary(email) do
    case get_customer_by_email(email) do
      nil -> insert_customer(%{email: String.trim(email)})
      customer -> {:ok, customer}
    end
  end

  @doc """
  Finds a customer by WhatsApp number, or creates one if not found. Returns `{:ok, customer}` or `{:error, changeset}`.
  """
  @spec get_or_create_customer_by_whatsapp(String.t()) ::
          {:ok, Customer.t()} | {:error, Ecto.Changeset.t()}
  def get_or_create_customer_by_whatsapp(number) when is_binary(number) do
    case get_customer_by_whatsapp(number) do
      nil -> insert_customer(%{whatsapp_number: String.trim(number)})
      customer -> {:ok, customer}
    end
  end

  @doc """
  Finds or creates a customer by email and/or WhatsApp number.
  At least one contact must be non-blank; returns `{:error, :contact_required}` otherwise.

  When both are given:
  - Looks up by email first; if found, adds WhatsApp if the customer doesn't have one yet.
  - Otherwise looks up by WhatsApp; if found, adds email if the customer doesn't have one yet.
  - If neither is found, creates a new customer with both contacts.
  """
  @spec get_or_create_customer_by_contact(String.t() | nil, String.t() | nil) ::
          {:ok, Customer.t()} | {:error, :contact_required} | {:error, Ecto.Changeset.t()}
  def get_or_create_customer_by_contact(email, whatsapp) do
    email = email |> to_string() |> String.trim() |> presence()
    whatsapp = whatsapp |> to_string() |> String.trim() |> presence()
    resolve_contact(email, whatsapp)
  end

  defp resolve_contact(nil, nil), do: {:error, :contact_required}
  defp resolve_contact(email, nil), do: get_or_create_customer_by_email(email)
  defp resolve_contact(nil, whatsapp), do: get_or_create_customer_by_whatsapp(whatsapp)

  defp resolve_contact(email, whatsapp) do
    case get_customer_by_email(email) do
      %Customer{} = customer -> add_whatsapp_if_missing(customer, whatsapp)
      nil -> resolve_contact_by_whatsapp(email, whatsapp)
    end
  end

  defp resolve_contact_by_whatsapp(email, whatsapp) do
    case get_customer_by_whatsapp(whatsapp) do
      %Customer{} = customer -> add_email_if_missing(customer, email)
      nil -> insert_customer(%{email: email, whatsapp_number: whatsapp})
    end
  end

  defp add_whatsapp_if_missing(%Customer{whatsapp_number: nil} = customer, whatsapp),
    do: update_customer_contact(customer, %{whatsapp_number: whatsapp})

  defp add_whatsapp_if_missing(%Customer{} = customer, _whatsapp), do: {:ok, customer}

  defp add_email_if_missing(%Customer{email: nil} = customer, email),
    do: update_customer_contact(customer, %{email: email})

  defp add_email_if_missing(%Customer{} = customer, _email), do: {:ok, customer}

  @doc """
  Adds or updates email/whatsapp_number on an existing customer.
  Returns `{:ok, customer}` or `{:error, changeset}`.
  """
  @spec update_customer_contact(Customer.t(), map()) ::
          {:ok, Customer.t()} | {:error, Ecto.Changeset.t()}
  def update_customer_contact(%Customer{} = customer, attrs) do
    customer
    |> Customer.update_changeset(attrs)
    |> Repo.update()
  end

  defp presence(""), do: nil
  defp presence(str), do: str

  defp insert_customer(attrs) do
    %Customer{}
    |> Customer.changeset(attrs)
    |> Repo.insert()
  end
end
