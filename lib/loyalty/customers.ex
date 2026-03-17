defmodule Loyalty.Customers do
  @moduledoc """
  Public API for customers (identified by email). Used by "Meus cartões" and by establishments when registering a client.
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

  defp insert_customer(attrs) do
    %Customer{}
    |> Customer.changeset(attrs)
    |> Repo.insert()
  end
end
