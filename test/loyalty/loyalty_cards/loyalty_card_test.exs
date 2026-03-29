defmodule Loyalty.LoyaltyCards.LoyaltyCardTest do
  use Loyalty.DataCase

  alias Loyalty.LoyaltyCards.LoyaltyCard

  describe "new_card_changeset/1" do
    test "valid with email only" do
      changeset = LoyaltyCard.new_card_changeset(%{email: "a@b.com", stamps_required: 10})
      assert changeset.valid?
    end

    test "valid with whatsapp only" do
      changeset =
        LoyaltyCard.new_card_changeset(%{whatsapp_number: "+5511999999999", stamps_required: 10})

      assert changeset.valid?
    end

    test "valid with both email and whatsapp" do
      changeset =
        LoyaltyCard.new_card_changeset(%{
          email: "a@b.com",
          whatsapp_number: "+5511999999999",
          stamps_required: 10
        })

      assert changeset.valid?
    end

    test "invalid when both email and whatsapp are blank" do
      changeset =
        LoyaltyCard.new_card_changeset(%{email: "", whatsapp_number: "", stamps_required: 10})

      refute changeset.valid?
      assert {_, _} = List.keyfind(changeset.errors, :email, 0)
    end

    test "invalid when stamps_required is zero" do
      changeset =
        LoyaltyCard.new_card_changeset(%{email: "a@b.com", stamps_required: 0})

      refute changeset.valid?
      assert {_, _} = List.keyfind(changeset.errors, :stamps_required, 0)
    end

    test "invalid when stamps_current is negative" do
      changeset =
        LoyaltyCard.new_card_changeset(%{
          email: "a@b.com",
          stamps_required: 10,
          stamps_current: -1
        })

      refute changeset.valid?
      assert {_, _} = List.keyfind(changeset.errors, :stamps_current, 0)
    end
  end
end
