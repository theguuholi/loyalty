defmodule LoyaltyWeb.PageController do
  use LoyaltyWeb, :controller

  def home(conn, _params) do
    render(conn, :home,
      page_title: "MyRewards - Fidelidade digital para negócios locais",
      page_description:
        "Transforme cartões de papel em recorrência com cartões digitais, progresso visível e cobrança simples por estabelecimento."
    )
  end
end
