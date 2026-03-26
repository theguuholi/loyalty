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

  defp insert_customer(attrs) do
    %Customer{}
    |> Customer.changeset(attrs)
    |> Repo.insert()
  end
end
