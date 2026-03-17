defmodule LoyaltyWeb.CardsLiveTest do
  use LoyaltyWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "mount and entry" do
    test "given a visitor when they visit /cards then they see the email entry form", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/cards")
      assert has_element?(view, "#cards-entry-form")
      assert has_element?(view, "#cards-entry-email")
      assert has_element?(view, "#cards-entry-submit")
      assert has_element?(view, "p", "Digite seu e-mail para ver todos os cartões de fidelidade.")
    end

    test "given valid email when they submit then they see list or empty state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/cards")

      view
      |> form("#cards-entry-form", %{"cards_entry" => %{"email" => "guest@example.com"}})
      |> render_submit()

      assert has_element?(view, "#cards-change-email-link")
    end
  end

  describe "list view" do
    test "given email with no cards when they open /cards?email=... then they see empty message",
         %{
           conn: conn
         } do
      {:ok, view, _html} = live(conn, ~p"/cards?email=nocards@example.com")
      assert has_element?(view, "#cards-empty-message")
    end

    test "given list view when they click Trocar e-mail then they go back to entry", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/cards?email=someone@example.com")
      assert view |> element("#cards-change-email-link") |> render_click()
      assert has_element?(view, "#cards-entry-form")
    end
  end
end
