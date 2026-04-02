defmodule LoyaltyWeb.PageController do
  use LoyaltyWeb, :controller

  def home(conn, _params) do
    render(conn, :home,
      page_title: "Volta Sempre - Fidelidade digital para negócios locais",
      page_description:
        "Volta Sempre ajuda seu negócio a fidelizar clientes pelo celular, sem app, sem complicação.",
      locale: conn.assigns[:locale] || "pt_BR"
    )
  end
end
