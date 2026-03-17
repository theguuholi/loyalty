defmodule LoyaltyWeb.PageController do
  use LoyaltyWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
