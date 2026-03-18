defmodule LoyaltyWeb.PageControllerTest do
  use LoyaltyWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "lang=\"pt-BR\""
    assert html_response(conn, 200) =~ "MyRewards - Fidelidade digital para negócios locais"
    assert html_response(conn, 200) =~ "Transforme cartões de papel em recorrência"
    assert html_response(conn, 200) =~ "Ver meus cartões"
    assert html_response(conn, 200) =~ "landing-cta-cards"
    assert html_response(conn, 200) =~ "landing-link-establishment"
    assert html_response(conn, 200) =~ "R$ 10/mês"
    assert html_response(conn, 200) =~ "Feito para parecer simples"
  end
end
