defmodule LoyaltyWeb.LoyaltyCardLiveTest do
  use LoyaltyWeb.ConnCase

  import Phoenix.LiveViewTest
  import Loyalty.LoyaltyCardsFixtures

  @create_attrs %{stamps_current: 42, stamps_required: 42, email: "newcard@example.com"}
  @update_attrs %{stamps_current: 43, stamps_required: 43}
  @invalid_attrs %{stamps_current: nil, stamps_required: nil}

  setup :register_and_log_in_user_with_establishment

  defp create_loyalty_card(%{scope: scope}) do
    loyalty_card = loyalty_card_fixture(scope)

    %{loyalty_card: loyalty_card}
  end

  describe "Index" do
    setup [:create_loyalty_card]

    test "lists all loyalty_cards", %{conn: conn, scope: scope} do
      {:ok, _index_live, html} =
        live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_cards")

      assert html =~ "Listing Loyalty cards"
    end

    test "saves new loyalty_card", %{conn: conn, scope: scope} do
      {:ok, index_live, _html} =
        live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_cards")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Loyalty card")
               |> render_click()
               |> follow_redirect(
                 conn,
                 ~p"/establishments/#{scope.establishment.id}/loyalty_cards/new"
               )

      assert render(form_live) =~ "New Loyalty card"
      assert render(form_live) =~ "Customer email"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#loyalty_card-form", loyalty_card: @create_attrs)
               |> render_submit()
               |> follow_redirect(
                 conn,
                 ~p"/establishments/#{scope.establishment.id}/loyalty_cards"
               )

      html = render(index_live)
      assert html =~ "Loyalty card created successfully"
    end

    test "updates loyalty_card in listing", %{
      conn: conn,
      loyalty_card: loyalty_card,
      scope: scope
    } do
      {:ok, index_live, _html} =
        live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_cards")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#loyalty_cards-#{loyalty_card.id} a", "Edit")
               |> render_click()
               |> follow_redirect(
                 conn,
                 ~p"/establishments/#{scope.establishment.id}/loyalty_cards/#{loyalty_card}/edit"
               )

      assert render(form_live) =~ "Edit Loyalty card"

      assert form_live
             |> form("#loyalty_card-form", loyalty_card: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#loyalty_card-form", loyalty_card: @update_attrs)
               |> render_submit()
               |> follow_redirect(
                 conn,
                 ~p"/establishments/#{scope.establishment.id}/loyalty_cards"
               )

      html = render(index_live)
      assert html =~ "Loyalty card updated successfully"
    end

    test "deletes loyalty_card in listing", %{
      conn: conn,
      loyalty_card: loyalty_card,
      scope: scope
    } do
      {:ok, index_live, _html} =
        live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_cards")

      assert index_live
             |> element("#loyalty_cards-#{loyalty_card.id} a", "Delete")
             |> render_click()

      refute has_element?(index_live, "#loyalty_cards-#{loyalty_card.id}")
    end
  end

  describe "Show" do
    setup [:create_loyalty_card]

    test "displays loyalty_card", %{conn: conn, loyalty_card: loyalty_card, scope: scope} do
      {:ok, _show_live, html} =
        live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_cards/#{loyalty_card}")

      assert html =~ "Adicionar carimbo"
    end

    test "updates loyalty_card and returns to show", %{
      conn: conn,
      loyalty_card: loyalty_card,
      scope: scope
    } do
      {:ok, show_live, _html} =
        live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_cards/#{loyalty_card}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Editar")
               |> render_click()
               |> follow_redirect(
                 conn,
                 ~p"/establishments/#{scope.establishment.id}/loyalty_cards/#{loyalty_card}/edit?return_to=show"
               )

      assert render(form_live) =~ "Edit Loyalty card"

      assert form_live
             |> form("#loyalty_card-form", loyalty_card: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#loyalty_card-form", loyalty_card: @update_attrs)
               |> render_submit()
               |> follow_redirect(
                 conn,
                 ~p"/establishments/#{scope.establishment.id}/loyalty_cards/#{loyalty_card}"
               )

      html = render(show_live)
      assert html =~ "Loyalty card updated successfully"
    end
  end
end
