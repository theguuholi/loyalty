defmodule Loyalty.CustomersTest do
  use Loyalty.DataCase

  alias Loyalty.Customers
  alias Loyalty.LoyaltyPrograms.Customer

  describe "get_customer_by_email/1" do
    test "given existing email when get_customer_by_email then returns the customer" do
      {:ok, customer} = Customers.get_or_create_customer_by_email("existing@example.com")
      assert Customers.get_customer_by_email("existing@example.com") == customer
    end

    test "given unknown email when get_customer_by_email then returns nil" do
      assert Customers.get_customer_by_email("missing@example.com") == nil
    end
  end

  describe "get_or_create_customer_by_email/1" do
    test "given new email when get_or_create_customer_by_email then creates and returns customer" do
      assert {:ok, %Customer{} = customer} =
               Customers.get_or_create_customer_by_email("new@example.com")

      assert customer.email == "new@example.com"
    end

    test "given existing email when get_or_create_customer_by_email then returns same customer" do
      {:ok, first} = Customers.get_or_create_customer_by_email("same@example.com")
      assert {:ok, second} = Customers.get_or_create_customer_by_email("same@example.com")
      assert first.id == second.id
    end
  end
end
