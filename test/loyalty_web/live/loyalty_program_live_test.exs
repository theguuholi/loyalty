defmodule LoyaltyWeb.LoyaltyProgramLiveTest do
  use LoyaltyWeb.ConnCase

  import Phoenix.LiveViewTest
  import Loyalty.LoyaltyProgramsFixtures

  @create_attrs %{
    name: "some name",
    stamps_required: 42,
    reward_description: "some reward_description"
  }
  @update_attrs %{
    name: "some updated name",
    stamps_required: 43,
    reward_description: "some updated reward_description"
  }
  @invalid_attrs %{name: nil, stamps_required: nil, reward_description: nil}

  setup :register_and_log_in_user_with_establishment

  defp create_loyalty_program(%{scope: scope}) do
    loyalty_program = loyalty_program_fixture(scope)

    %{loyalty_program: loyalty_program}
  end

  describe "Index" do
    setup [:create_loyalty_program]

    test "lists all loyalty_programs", %{
      conn: conn,
      loyalty_program: loyalty_program,
      scope: scope
    } do
      {:ok, _index_live, html} =
        live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_programs")

      assert html =~ "Listing Loyalty programs"
      assert html =~ loyalty_program.name
    end

    test "saves new loyalty_program", %{conn: conn, scope: scope} do
      {:ok, index_live, _html} =
        live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_programs")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Loyalty program")
               |> render_click()
               |> follow_redirect(
                 conn,
                 ~p"/establishments/#{scope.establishment.id}/loyalty_programs/new"
               )

      assert render(form_live) =~ "New Loyalty program"

      assert form_live
             |> form("#loyalty_program-form", loyalty_program: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#loyalty_program-form", loyalty_program: @create_attrs)
               |> render_submit()
               |> follow_redirect(
                 conn,
                 ~p"/establishments/#{scope.establishment.id}/loyalty_programs"
               )

      html = render(index_live)
      assert html =~ "Loyalty program created successfully"
      assert html =~ "some name"
    end

    test "updates loyalty_program in listing", %{
      conn: conn,
      loyalty_program: loyalty_program,
      scope: scope
    } do
      {:ok, index_live, _html} =
        live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_programs")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#loyalty_programs-#{loyalty_program.id} a", "Edit")
               |> render_click()
               |> follow_redirect(
                 conn,
                 ~p"/establishments/#{scope.establishment.id}/loyalty_programs/#{loyalty_program}/edit"
               )

      assert render(form_live) =~ "Edit Loyalty program"

      assert form_live
             |> form("#loyalty_program-form", loyalty_program: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#loyalty_program-form", loyalty_program: @update_attrs)
               |> render_submit()
               |> follow_redirect(
                 conn,
                 ~p"/establishments/#{scope.establishment.id}/loyalty_programs"
               )

      html = render(index_live)
      assert html =~ "Loyalty program updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes loyalty_program in listing", %{
      conn: conn,
      loyalty_program: loyalty_program,
      scope: scope
    } do
      {:ok, index_live, _html} =
        live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_programs")

      assert index_live
             |> element("#loyalty_programs-#{loyalty_program.id} a", "Delete")
             |> render_click()

      refute has_element?(index_live, "#loyalty_programs-#{loyalty_program.id}")
    end
  end

  describe "Show" do
    setup [:create_loyalty_program]

    test "displays loyalty_program", %{conn: conn, loyalty_program: loyalty_program, scope: scope} do
      {:ok, _show_live, html} =
        live(
          conn,
          ~p"/establishments/#{scope.establishment.id}/loyalty_programs/#{loyalty_program}"
        )

      assert html =~ "Show Loyalty program"
      assert html =~ loyalty_program.name
    end

    test "updates loyalty_program and returns to show", %{
      conn: conn,
      loyalty_program: loyalty_program,
      scope: scope
    } do
      {:ok, show_live, _html} =
        live(
          conn,
          ~p"/establishments/#{scope.establishment.id}/loyalty_programs/#{loyalty_program}"
        )

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(
                 conn,
                 ~p"/establishments/#{scope.establishment.id}/loyalty_programs/#{loyalty_program}/edit?return_to=show"
               )

      assert render(form_live) =~ "Edit Loyalty program"

      assert form_live
             |> form("#loyalty_program-form", loyalty_program: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#loyalty_program-form", loyalty_program: @update_attrs)
               |> render_submit()
               |> follow_redirect(
                 conn,
                 ~p"/establishments/#{scope.establishment.id}/loyalty_programs/#{loyalty_program}"
               )

      html = render(show_live)
      assert html =~ "Loyalty program updated successfully"
      assert html =~ "some updated name"
    end
  end
end
