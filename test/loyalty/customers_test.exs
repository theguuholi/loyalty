defmodule Loyalty.CustomersTest do
  use Loyalty.DataCase

  alias Loyalty.Customers
  alias Loyalty.LoyaltyPrograms.Customer

  describe "Customer.changeset/2" do
    test "requires at least one contact" do
      changeset = Customer.changeset(%Customer{}, %{})
      assert {"at least one of email or WhatsApp number is required", _} = changeset.errors[:base]
    end

    test "empty string fields count as blank" do
      changeset = Customer.changeset(%Customer{}, %{email: "", whatsapp_number: ""})
      assert {"at least one of email or WhatsApp number is required", _} = changeset.errors[:base]
    end

    test "whitespace-only email counts as blank contact" do
      changeset = Customer.changeset(%Customer{}, %{email: "   ", whatsapp_number: ""})
      assert {"at least one of email or WhatsApp number is required", _} = changeset.errors[:base]
    end

    test "struct with existing empty string email is treated as blank" do
      changeset = Customer.changeset(%Customer{email: ""}, %{})
      assert {"at least one of email or WhatsApp number is required", _} = changeset.errors[:base]
    end

    test "valid with both email and whatsapp" do
      changeset =
        Customer.changeset(%Customer{}, %{
          email: "both@example.com",
          whatsapp_number: "+5511988888888"
        })

      assert changeset.valid?
    end

    test "valid with email only" do
      changeset = Customer.changeset(%Customer{}, %{email: "only@example.com"})
      assert changeset.valid?
    end

    test "valid with whatsapp only" do
      changeset = Customer.changeset(%Customer{}, %{whatsapp_number: "+5511977777777"})
      assert changeset.valid?
    end

    test "update_changeset allows adding email to existing whatsapp-only customer" do
      {:ok, customer} = Customers.get_or_create_customer_by_whatsapp("+5511966666666")
      changeset = Customer.update_changeset(customer, %{email: "update@example.com"})
      assert changeset.valid?
    end
  end

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

  describe "get_customer_by_whatsapp/1" do
    test "given existing number returns the customer" do
      {:ok, customer} = Customers.get_or_create_customer_by_whatsapp("+5511900000001")
      assert Customers.get_customer_by_whatsapp("+5511900000001") == customer
    end

    test "given unknown number returns nil" do
      assert Customers.get_customer_by_whatsapp("+5511999999999") == nil
    end
  end

  describe "get_or_create_customer_by_whatsapp/1" do
    test "creates a new customer when number is not found" do
      assert {:ok, %Customer{} = customer} =
               Customers.get_or_create_customer_by_whatsapp("+5511900000002")

      assert customer.whatsapp_number == "+5511900000002"
    end

    test "returns existing customer when number already exists" do
      {:ok, first} = Customers.get_or_create_customer_by_whatsapp("+5511900000003")
      assert {:ok, second} = Customers.get_or_create_customer_by_whatsapp("+5511900000003")
      assert first.id == second.id
    end

    test "returns error for invalid phone format" do
      assert {:error, changeset} = Customers.get_or_create_customer_by_whatsapp("invalid")

      assert {"must be in E.164 format (e.g. +5511999999999)", _} =
               changeset.errors[:whatsapp_number]
    end
  end

  describe "get_or_create_customer_by_contact/2" do
    test "returns error when both are blank" do
      assert {:error, :contact_required} =
               Customers.get_or_create_customer_by_contact("", "")
    end

    test "creates customer with email only" do
      assert {:ok, %Customer{} = c} =
               Customers.get_or_create_customer_by_contact("contact-email@example.com", "")

      assert c.email == "contact-email@example.com"
      assert is_nil(c.whatsapp_number)
    end

    test "creates customer with whatsapp only" do
      assert {:ok, %Customer{} = c} =
               Customers.get_or_create_customer_by_contact("", "+5511900000020")

      assert c.whatsapp_number == "+5511900000020"
      assert is_nil(c.email)
    end

    test "creates customer with both email and whatsapp" do
      assert {:ok, %Customer{} = c} =
               Customers.get_or_create_customer_by_contact("both2@example.com", "+5511900000021")

      assert c.email == "both2@example.com"
      assert c.whatsapp_number == "+5511900000021"
    end

    test "returns existing customer when found by email and adds whatsapp" do
      {:ok, existing} = Customers.get_or_create_customer_by_email("found-by-email@example.com")

      assert {:ok, updated} =
               Customers.get_or_create_customer_by_contact(
                 "found-by-email@example.com",
                 "+5511900000022"
               )

      assert updated.id == existing.id
      assert updated.whatsapp_number == "+5511900000022"
    end

    test "returns existing customer when found by whatsapp and adds email" do
      {:ok, existing} = Customers.get_or_create_customer_by_whatsapp("+5511900000023")

      assert {:ok, updated} =
               Customers.get_or_create_customer_by_contact(
                 "found-by-wa@example.com",
                 "+5511900000023"
               )

      assert updated.id == existing.id
      assert updated.email == "found-by-wa@example.com"
    end

    test "returns error for invalid whatsapp format" do
      assert {:error, %Ecto.Changeset{}} =
               Customers.get_or_create_customer_by_contact("", "not-a-number")
    end
  end

  describe "update_customer_contact/2" do
    test "adds email to a whatsapp-only customer" do
      {:ok, customer} = Customers.get_or_create_customer_by_whatsapp("+5511900000004")

      assert {:ok, updated} =
               Customers.update_customer_contact(customer, %{email: "add@example.com"})

      assert updated.email == "add@example.com"
      assert updated.whatsapp_number == "+5511900000004"
    end

    test "adds whatsapp to an email-only customer" do
      {:ok, customer} = Customers.get_or_create_customer_by_email("only@example.com")

      assert {:ok, updated} =
               Customers.update_customer_contact(customer, %{whatsapp_number: "+5511900000005"})

      assert updated.whatsapp_number == "+5511900000005"
    end

    test "returns error when whatsapp number already taken" do
      {:ok, _} = Customers.get_or_create_customer_by_whatsapp("+5511900000006")
      {:ok, other} = Customers.get_or_create_customer_by_email("other@example.com")

      assert {:error, changeset} =
               Customers.update_customer_contact(other, %{whatsapp_number: "+5511900000006"})

      assert changeset.errors[:whatsapp_number]
    end
  end
end
