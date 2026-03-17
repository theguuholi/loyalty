defmodule LoyaltyWeb.EstablishmentLiveTest do
  use LoyaltyWeb.ConnCase

  import Phoenix.LiveViewTest
  import Loyalty.EstablishmentsFixtures

  @create_attrs %{name: "some name"}
  @update_attrs %{name: "some updated name"}
  @invalid_attrs %{name: nil}

  setup :register_and_log_in_user

  defp create_establishment(%{scope: scope}) do
    establishment = establishment_fixture(scope)

    %{establishment: establishment}
  end

  describe "Index" do
    setup [:create_establishment]

    test "lists all establishments", %{conn: conn, establishment: establishment} do
      {:ok, _index_live, html} = live(conn, ~p"/establishments")

      assert html =~ "Listing Establishments"
      assert html =~ establishment.name
    end

    test "saves new establishment", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/establishments")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Establishment")
               |> render_click()
               |> follow_redirect(conn, ~p"/establishments/new")

      assert render(form_live) =~ "New Establishment"

      assert form_live
             |> form("#establishment-form", establishment: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#establishment-form", establishment: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/establishments")

      html = render(index_live)
      assert html =~ "Establishment created successfully"
      assert html =~ "some name"
    end

    test "updates establishment in listing", %{conn: conn, establishment: establishment} do
      {:ok, index_live, _html} = live(conn, ~p"/establishments")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#establishments-#{establishment.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/establishments/#{establishment}/edit")

      assert render(form_live) =~ "Edit Establishment"

      assert form_live
             |> form("#establishment-form", establishment: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#establishment-form", establishment: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/establishments")

      html = render(index_live)
      assert html =~ "Establishment updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes establishment in listing", %{conn: conn, establishment: establishment} do
      {:ok, index_live, _html} = live(conn, ~p"/establishments")

      assert index_live
             |> element("#establishments-#{establishment.id} a", "Delete")
             |> render_click()

      refute has_element?(index_live, "#establishments-#{establishment.id}")
    end
  end

  describe "Show" do
    setup [:create_establishment]

    test "displays establishment", %{conn: conn, establishment: establishment} do
      {:ok, _show_live, html} = live(conn, ~p"/establishments/#{establishment}")

      assert html =~ "Show Establishment"
      assert html =~ establishment.name
    end

    test "updates establishment and returns to show", %{conn: conn, establishment: establishment} do
      {:ok, show_live, _html} = live(conn, ~p"/establishments/#{establishment}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/establishments/#{establishment}/edit?return_to=show")

      assert render(form_live) =~ "Edit Establishment"

      assert form_live
             |> form("#establishment-form", establishment: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#establishment-form", establishment: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/establishments/#{establishment}")

      html = render(show_live)
      assert html =~ "Establishment updated successfully"
      assert html =~ "some updated name"
    end
  end
end
