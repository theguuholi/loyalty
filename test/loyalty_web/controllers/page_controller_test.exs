defmodule LoyaltyWeb.PageControllerTest do
  use LoyaltyWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "lang=\"pt-BR\""
    assert html_response(conn, 200) =~ "Volta Sempre - Fidelidade digital para negócios locais"
    assert html_response(conn, 200) =~ "Volta Sempre ajuda seu negócio"
    assert html_response(conn, 200) =~ "Ver meus cartões"
    assert html_response(conn, 200) =~ "landing-cta-cards"
    assert html_response(conn, 200) =~ "landing-link-establishment"
    assert html_response(conn, 200) =~ "R$ 49/mês"
    assert html_response(conn, 200) =~ "Quero fidelizar meus clientes"
  end
end
