defmodule LoyaltyWeb.ReferralController do
  use LoyaltyWeb, :controller

  def establishment(conn, %{"code" => code}) do
    conn
    |> put_session("establishment_referral_code", code)
    |> redirect(to: ~p"/users/register")
  end

  def customer(conn, %{"code" => code}) do
    conn
    |> put_session("customer_referral_code", code)
    |> redirect(to: ~p"/users/register")
  end
end
