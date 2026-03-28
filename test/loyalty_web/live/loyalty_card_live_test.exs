defmodule LoyaltyWeb.LoyaltyCardLiveTest do
  use LoyaltyWeb.ConnCase

  import Phoenix.LiveViewTest
  import Loyalty.{LoyaltyCardsFixtures, LoyaltyProgramsFixtures}

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

      assert html =~ "Clients and cards"
    end

    test "saves new loyalty_card", %{conn: conn, scope: scope} do
      {:ok, index_live, _html} =
        live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_cards")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "Register client")
               |> render_click()
               |> follow_redirect(
                 conn,
                 ~p"/establishments/#{scope.establishment.id}/loyalty_cards/new"
               )

      assert has_element?(form_live, "h1", "Register client")
      assert has_element?(form_live, "label", "Client email")

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
               |> element("#loyalty_cards a", "Edit")
               |> render_click()
               |> follow_redirect(
                 conn,
                 ~p"/establishments/#{scope.establishment.id}/loyalty_cards/#{loyalty_card}/edit"
               )

      assert render(form_live) =~ "Edit card"

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
      scope: scope
    } do
      {:ok, index_live, _html} =
        live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_cards")

      assert index_live
             |> element("#loyalty_cards a", "Delete")
             |> render_click()

      assert has_element?(index_live, "#loyalty-cards-empty-message")
    end

    test "saves new loyalty_card using whatsapp number only", %{conn: conn, scope: scope} do
      {:ok, form_live, _html} =
        live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_cards/new")

      assert has_element?(form_live, "input[name='loyalty_card[whatsapp_number]']")

      assert {:ok, _index_live, _html} =
               form_live
               |> form("#loyalty_card-form",
                 loyalty_card: %{
                   whatsapp_number: "+5511900000088",
                   stamps_current: 0,
                   stamps_required: 10
                 }
               )
               |> render_submit()
               |> follow_redirect(
                 conn,
                 ~p"/establishments/#{scope.establishment.id}/loyalty_cards"
               )
    end

    test "saves new loyalty_card using both email and whatsapp", %{conn: conn, scope: scope} do
      {:ok, form_live, _html} =
        live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_cards/new")

      assert {:ok, _index_live, _html} =
               form_live
               |> form("#loyalty_card-form",
                 loyalty_card: %{
                   email: "both@example.com",
                   whatsapp_number: "+5511900000099",
                   stamps_current: 0,
                   stamps_required: 10
                 }
               )
               |> render_submit()
               |> follow_redirect(
                 conn,
                 ~p"/establishments/#{scope.establishment.id}/loyalty_cards"
               )
    end

    test "submitting with both blank contacts shows error", %{conn: conn, scope: scope} do
      {:ok, form_live, _html} =
        live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_cards/new")

      form_live
      |> form("#loyalty_card-form",
        loyalty_card: %{email: "", whatsapp_number: "", stamps_current: 0, stamps_required: 10}
      )
      |> render_submit()

      assert has_element?(form_live, "#loyalty_card-form")
    end

    test "validate event on new form updates the form", %{conn: conn, scope: scope} do
      {:ok, form_live, _html} =
        live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_cards/new")

      form_live
      |> form("#loyalty_card-form", loyalty_card: %{stamps_current: "5", stamps_required: "10"})
      |> render_change()

      assert has_element?(form_live, "#loyalty_card-form")
    end

    test "submitting invalid whatsapp format shows error", %{conn: conn, scope: scope} do
      {:ok, form_live, _html} =
        live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_cards/new")

      form_live
      |> form("#loyalty_card-form",
        loyalty_card: %{whatsapp_number: "not-a-phone", stamps_current: 0, stamps_required: 10}
      )
      |> render_submit()

      assert has_element?(form_live, "#loyalty_card-form")
    end

    test "adds stamp to loyalty card", %{conn: conn, scope: scope, loyalty_card: loyalty_card} do
      {:ok, index_live, _html} =
        live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_cards")

      index_live
      |> element("#add-stamp-button-loyalty_cards-#{loyalty_card.id}")
      |> render_click()

      assert render(index_live) =~ "Stamp added."
    end
  end

  describe "Index billing" do
    test "shows blocked message when empty cards and subscription inactive", %{
      conn: conn,
      scope: scope
    } do
      scope.establishment
      |> Ecto.Changeset.change(%{subscription_status: "past_due"})
      |> Loyalty.Repo.update()

      {:ok, _index_live, html} =
        live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_cards")

      assert html =~ "cannot register new clients"
    end
  end

  describe "New form" do
    test "redirects away when billing is inactive", %{conn: conn, scope: scope} do
      scope.establishment
      |> Ecto.Changeset.change(%{subscription_status: "past_due"})
      |> Loyalty.Repo.update()

      assert {:error, _} =
               live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_cards/new")
    end

    test "auto-creates loyalty program when none exists", %{conn: conn, scope: scope} do
      {:ok, form_live, _html} =
        live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_cards/new")

      assert {:ok, _index_live, _html} =
               form_live
               |> form("#loyalty_card-form",
                 loyalty_card: %{
                   email: "autoprog@example.com",
                   stamps_current: 0,
                   stamps_required: 10
                 }
               )
               |> render_submit()
               |> follow_redirect(
                 conn,
                 ~p"/establishments/#{scope.establishment.id}/loyalty_cards"
               )
    end

    test "shows subscription inactive error when billing changes after mount", %{
      conn: conn,
      scope: scope
    } do
      _program = loyalty_program_fixture(scope)

      {:ok, form_live, _html} =
        live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_cards/new")

      scope.establishment
      |> Ecto.Changeset.change(%{subscription_status: "past_due"})
      |> Loyalty.Repo.update()

      form_live
      |> form("#loyalty_card-form",
        loyalty_card: %{email: "inactive@example.com", stamps_current: 0, stamps_required: 10}
      )
      |> render_submit()

      assert render(form_live) =~ "Billing is not active"
    end

    test "shows client limit error when limit reached between mount and save", %{
      conn: conn,
      scope: scope
    } do
      program = loyalty_program_fixture(scope)
      free_limit = Loyalty.Billing.free_client_limit()

      for i <- 0..(free_limit - 2) do
        {:ok, customer} =
          Loyalty.Customers.get_or_create_customer_by_email("limit-lv#{i}@example.com")

        {:ok, _} =
          Loyalty.LoyaltyCards.create_loyalty_card(scope, %{
            customer_id: customer.id,
            loyalty_program_id: program.id,
            stamps_current: 0,
            stamps_required: 10
          })
      end

      {:ok, form_live, _html} =
        live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_cards/new")

      {:ok, extra_customer} =
        Loyalty.Customers.get_or_create_customer_by_email("limit-extra-lv@example.com")

      {:ok, _} =
        Loyalty.LoyaltyCards.create_loyalty_card(scope, %{
          customer_id: extra_customer.id,
          loyalty_program_id: program.id,
          stamps_current: 0,
          stamps_required: 10
        })

      form_live
      |> form("#loyalty_card-form",
        loyalty_card: %{
          email: "overlimit-lv@example.com",
          stamps_current: 0,
          stamps_required: 10
        }
      )
      |> render_submit()

      assert render(form_live) =~ "limit"
    end
  end

  describe "Edit form" do
    test "shows whatsapp number as client label when customer has no email", %{
      conn: conn,
      scope: scope
    } do
      {:ok, customer} = Loyalty.Customers.get_or_create_customer_by_whatsapp("+5511900000097")
      program = loyalty_program_fixture(scope)

      {:ok, card} =
        Loyalty.LoyaltyCards.create_loyalty_card(scope, %{
          customer_id: customer.id,
          loyalty_program_id: program.id,
          stamps_current: 0,
          stamps_required: 10
        })

      {:ok, _form_live, html} =
        live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_cards/#{card}/edit")

      assert html =~ "+5511900000097"
    end

    test "submitting invalid data on edit shows validation error", %{conn: conn, scope: scope} do
      program = loyalty_program_fixture(scope)

      {:ok, customer} =
        Loyalty.Customers.get_or_create_customer_by_email("edit-inv@example.com")

      {:ok, card} =
        Loyalty.LoyaltyCards.create_loyalty_card(scope, %{
          customer_id: customer.id,
          loyalty_program_id: program.id,
          stamps_current: 5,
          stamps_required: 10
        })

      {:ok, form_live, _html} =
        live(conn, ~p"/establishments/#{scope.establishment.id}/loyalty_cards/#{card}/edit")

      form_live
      |> form("#loyalty_card-form", loyalty_card: %{stamps_current: "", stamps_required: ""})
      |> render_submit()

      assert has_element?(form_live, "#loyalty_card-form")
    end
  end
end
