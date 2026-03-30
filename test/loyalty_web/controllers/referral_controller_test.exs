defmodule LoyaltyWeb.ReferralControllerTest do
  use LoyaltyWeb.ConnCase

  describe "GET /ref/:code (establishment referral)" do
    test "stores establishment_referral_code in session and redirects to register", %{conn: conn} do
      conn = get(conn, ~p"/ref/ABC12345")

      assert redirected_to(conn) == ~p"/users/register"
      assert get_session(conn, "establishment_referral_code") == "ABC12345"
    end
  end

  describe "GET /ref/c/:code (customer referral)" do
    test "stores customer_referral_code in session and redirects to register", %{conn: conn} do
      conn = get(conn, ~p"/ref/c/CUST1234")

      assert redirected_to(conn) == ~p"/users/register"
      assert get_session(conn, "customer_referral_code") == "CUST1234"
    end
  end
end
