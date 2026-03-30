defmodule Loyalty.BillingTest do
  use Loyalty.DataCase

  alias Loyalty.Billing

  describe "has_free_access?/1" do
    test "returns false when free_access_until is nil" do
      refute Billing.has_free_access?(%{free_access_until: nil})
    end

    test "returns false when free_access_until is in the past" do
      past = DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)
      refute Billing.has_free_access?(%{free_access_until: past})
    end

    test "returns true when free_access_until is in the future" do
      future = DateTime.utc_now() |> DateTime.add(10, :day) |> DateTime.truncate(:second)
      assert Billing.has_free_access?(%{free_access_until: future})
    end
  end
end
