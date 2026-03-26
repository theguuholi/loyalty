defmodule LoyaltyWeb.CardsLiveTest do
  use LoyaltyWeb.ConnCase

  import Phoenix.LiveViewTest
  import Loyalty.{AccountsFixtures, LoyaltyCardsFixtures}

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

      assert has_element?(view, "#cards-change-contact-link")
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
      assert view |> element("#cards-change-contact-link") |> render_click()
      assert has_element?(view, "#cards-entry-form")
    end

    test "given whatsapp number with no cards when they open /cards?whatsapp=... then they see empty message",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/cards?whatsapp=+5511999999999")
      assert has_element?(view, "#cards-empty-message")
    end
  end

  describe "contact type toggle" do
    test "switching to whatsapp shows phone input", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/cards")
      view |> element("#lookup-type-whatsapp") |> render_click()
      assert has_element?(view, "#cards-entry-whatsapp")
    end

    test "switching back to email shows email input", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/cards")
      view |> element("#lookup-type-whatsapp") |> render_click()
      view |> element("#lookup-type-email") |> render_click()
      assert has_element?(view, "#cards-entry-email")
    end

    test "submitting whatsapp lookup shows list view", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/cards")
      view |> element("#lookup-type-whatsapp") |> render_click()

      view
      |> form("#cards-entry-form", %{"cards_entry" => %{"whatsapp_number" => "+5511900000099"}})
      |> render_submit()

      assert has_element?(view, "#cards-change-contact-link")
    end

    test "submitting invalid whatsapp shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/cards")
      view |> element("#lookup-type-whatsapp") |> render_click()

      view
      |> form("#cards-entry-form", %{"cards_entry" => %{"whatsapp_number" => "notaphone"}})
      |> render_submit()

      assert has_element?(view, "#cards-entry-form")
    end

    test "submitting empty whatsapp shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/cards")
      view |> element("#lookup-type-whatsapp") |> render_click()

      view
      |> form("#cards-entry-form", %{"cards_entry" => %{"whatsapp_number" => ""}})
      |> render_submit()

      assert has_element?(view, "#cards-entry-form")
    end

    test "submitting empty email shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/cards")

      view
      |> form("#cards-entry-form", %{"cards_entry" => %{"email" => ""}})
      |> render_submit()

      assert has_element?(view, "#cards-entry-form")
    end

    test "navigating to /cards?whatsapp= empty resets to entry form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/cards?whatsapp=")
      assert has_element?(view, "#cards-entry-form")
    end

    test "navigating to /cards?email= empty resets to entry form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/cards?email=")
      assert has_element?(view, "#cards-entry-form")
    end
  end

  describe "list with real cards" do
    test "shows card items when customer has loyalty cards", %{conn: conn} do
      scope = establishment_scope_fixture()
      loyalty_card = loyalty_card_fixture(scope)
      email = "customer-#{scope.establishment.id}@example.com"

      {:ok, view, _html} = live(conn, "/cards?email=#{URI.encode_www_form(email)}")

      assert has_element?(view, "#cards-list")
      assert has_element?(view, "#card-item-#{loyalty_card.id}")
    end

    test "shows reward ready message when stamps are complete", %{conn: conn} do
      scope = establishment_scope_fixture()
      _card = loyalty_card_fixture(scope, %{stamps_current: 42, stamps_required: 42})
      email = "customer-#{scope.establishment.id}@example.com"

      {:ok, _view, html} = live(conn, "/cards?email=#{URI.encode_www_form(email)}")

      assert html =~ "pronto para usar!"
    end
  end
end
