defmodule LoyaltyWeb.PageControllerTest do
  use LoyaltyWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "MyRewards"
    assert html_response(conn, 200) =~ "Ver meus cartões"
    assert html_response(conn, 200) =~ "landing-cta-cards"
    assert html_response(conn, 200) =~ "landing-link-establishment"
  end
end
