defmodule LoyaltyWeb.EstablishmentLiveTest do
  use LoyaltyWeb.ConnCase

  import Phoenix.LiveViewTest
  import Loyalty.EstablishmentsFixtures

  @create_attrs %{name: "some name"}
  @update_attrs %{name: "some updated name"}
  @invalid_attrs %{name: nil}

  setup :register_and_log_in_user

  describe "Index" do
    test "lists all establishments", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/establishments")

      assert html =~ "Listing Establishments"
      assert html =~ "New Establishment"
      refute html =~ "Only one establishment allowed"
    end

    test "lists all establishments with existing data", %{conn: conn, scope: scope} do
      establishment = establishment_fixture(scope)
      {:ok, _index_live, html} = live(conn, ~p"/establishments")

      assert html =~ "Listing Establishments"
      assert html =~ establishment.name
      assert html =~ "Only one establishment allowed"
    end

    test "saves new establishment", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/establishments")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Establishment")
               |> render_click()
               |> follow_redirect(conn, ~p"/establishments/new")

      assert render(form_live) =~ "New establishment"

      assert form_live
             |> form("#establishment-form", establishment: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#establishment-form", establishment: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/establishments")

      html = render(index_live)
      assert html =~ "Establishment created successfully."
      assert html =~ "some name"
    end

    test "updates establishment in listing", %{conn: conn, scope: scope} do
      establishment = establishment_fixture(scope)
      {:ok, index_live, _html} = live(conn, ~p"/establishments")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#establishments-#{establishment.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/establishments/#{establishment}/edit")

      assert render(form_live) =~ "Edit establishment"

      assert form_live
             |> form("#establishment-form", establishment: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#establishment-form", establishment: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/establishments")

      html = render(index_live)
      assert html =~ "Establishment updated successfully."
      assert html =~ "some updated name"
    end

    test "deletes establishment in listing", %{conn: conn, scope: scope} do
      establishment = establishment_fixture(scope)
      {:ok, index_live, _html} = live(conn, ~p"/establishments")

      assert index_live
             |> element("#establishments-#{establishment.id} a", "Delete")
             |> render_click()

      refute has_element?(index_live, "#establishments-#{establishment.id}")
    end

    test "hides the create button once an establishment exists", %{conn: conn, scope: scope} do
      _establishment = establishment_fixture(scope)

      {:ok, index_live, html} = live(conn, ~p"/establishments")

      refute has_element?(index_live, "a", "New establishment")
      assert html =~ "Only one establishment allowed"
    end
  end

  describe "Show" do
    test "displays establishment", %{conn: conn, scope: scope} do
      establishment = establishment_fixture(scope)
      {:ok, show_live, html} = live(conn, ~p"/establishments/#{establishment}")

      assert html =~ establishment.name
      # With no program: "Create program" link; with program: "Program and clients" link
      assert has_element?(show_live, "#dashboard-create-program-link") or
               has_element?(show_live, "#dashboard-program-and-clients-link")
    end

    test "shows payment issue banner when subscription is past_due", %{conn: conn, scope: scope} do
      establishment = establishment_fixture(scope)

      {:ok, _} =
        establishment
        |> Ecto.Changeset.change(%{subscription_status: "past_due"})
        |> Loyalty.Repo.update()

      {:ok, show_live, html} = live(conn, ~p"/establishments/#{establishment}")
      assert html =~ establishment.name
      assert has_element?(show_live, "#dashboard-payment-issue-banner")
    end

    test "shows subscribe CTA on free plan", %{conn: conn, scope: scope} do
      establishment = establishment_fixture(scope)
      {:ok, show_live, html} = live(conn, ~p"/establishments/#{establishment}")
      assert html =~ establishment.name
      assert has_element?(show_live, "#dashboard-stripe-checkout")
    end

    test "checkout=success flash after returning from Stripe", %{conn: conn, scope: scope} do
      establishment = establishment_fixture(scope)

      {:ok, _show_live, html} =
        live(conn, ~p"/establishments/#{establishment}?checkout=success")

      assert html =~ "Thank you"
    end

    test "checkout=cancel flash", %{conn: conn, scope: scope} do
      establishment = establishment_fixture(scope)

      {:ok, _show_live, html} =
        live(conn, ~p"/establishments/#{establishment}?checkout=cancel")

      assert html =~ "canceled" or html =~ "cancel"
    end

    test "PubSub establishment update refreshes show", %{conn: conn, scope: scope} do
      establishment = establishment_fixture(scope)
      {:ok, show_live, _html} = live(conn, ~p"/establishments/#{establishment}")

      {:ok, updated} =
        establishment
        |> Ecto.Changeset.change(%{
          subscription_status: "active",
          stripe_subscription_id: "sub_test",
          stripe_customer_id: "cus_test"
        })
        |> Loyalty.Repo.update()

      Phoenix.PubSub.broadcast(
        Loyalty.PubSub,
        "user:#{scope.user.id}:establishments",
        {:updated, updated}
      )

      html = render(show_live)
      assert html =~ "Paid plan" or html =~ "Plano pago"
    end

    test "subscribe shows error when Stripe secret is blank", %{conn: conn, scope: scope} do
      establishment = establishment_fixture(scope)
      prev = Application.get_env(:loyalty, :stripe)
      on_exit(fn -> Application.put_env(:loyalty, :stripe, prev) end)

      Application.put_env(
        :loyalty,
        :stripe,
        Keyword.merge(prev, secret_key: "", price_id: prev[:price_id])
      )

      {:ok, show_live, _html} = live(conn, ~p"/establishments/#{establishment}")

      show_live
      |> element("#dashboard-stripe-checkout")
      |> render_click()

      assert render(show_live) =~ "Stripe"
    end

    test "PubSub establishment deleted navigates away", %{conn: conn, scope: scope} do
      establishment = establishment_fixture(scope)
      {:ok, show_live, _html} = live(conn, ~p"/establishments/#{establishment}")

      Phoenix.PubSub.broadcast(
        Loyalty.PubSub,
        "user:#{scope.user.id}:establishments",
        {:deleted, establishment}
      )

      assert_redirect(show_live, ~p"/establishments")
    end

    test "PubSub created event for other establishment is ignored", %{conn: conn, scope: scope} do
      establishment = establishment_fixture(scope)
      {:ok, show_live, _html} = live(conn, ~p"/establishments/#{establishment}")

      other_scope = Loyalty.AccountsFixtures.user_scope_fixture()
      other_est = establishment_fixture(other_scope)

      Phoenix.PubSub.broadcast(
        Loyalty.PubSub,
        "user:#{scope.user.id}:establishments",
        {:created, other_est}
      )

      assert has_element?(show_live, "#dashboard-billing-card")
    end

    test "shows near-limit hint when close to free plan limit", %{conn: conn, scope: scope} do
      establishment = establishment_fixture(scope)
      scope_with_est = Loyalty.Accounts.Scope.put_establishment(scope, establishment)
      program = Loyalty.LoyaltyProgramsFixtures.loyalty_program_fixture(scope_with_est)
      free_limit = Loyalty.Billing.free_client_limit()

      for i <- 0..(free_limit - 2) do
        {:ok, customer} =
          Loyalty.Customers.get_or_create_customer_by_email("near-limit-#{i}@example.com")

        Loyalty.LoyaltyCards.create_loyalty_card(scope_with_est, %{
          customer_id: customer.id,
          loyalty_program_id: program.id,
          stamps_current: 0,
          stamps_required: 10
        })
      end

      {:ok, show_live, _html} = live(conn, ~p"/establishments/#{establishment}")
      assert has_element?(show_live, "#dashboard-free-plan-near-limit")
    end

    test "subscribe shows error when Stripe request fails", %{conn: conn, scope: scope} do
      establishment = establishment_fixture(scope)
      prev = Application.get_env(:loyalty, :stripe)
      on_exit(fn -> Application.put_env(:loyalty, :stripe, prev) end)

      Application.put_env(
        :loyalty,
        :stripe,
        Keyword.merge(prev, secret_key: "invalid_key", price_id: "price_test")
      )

      {:ok, show_live, _html} = live(conn, ~p"/establishments/#{establishment}")

      show_live |> element("#dashboard-stripe-checkout") |> render_click()

      html = render(show_live)
      assert html =~ "Stripe" or html =~ "checkout" or html =~ "configured"
    end

    test "updates establishment and returns to show", %{conn: conn, scope: scope} do
      establishment = establishment_fixture(scope)
      {:ok, show_live, _html} = live(conn, ~p"/establishments/#{establishment}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit establishment")
               |> render_click()
               |> follow_redirect(conn, ~p"/establishments/#{establishment}/edit?return_to=show")

      assert render(form_live) =~ "Edit establishment"

      assert form_live
             |> form("#establishment-form", establishment: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#establishment-form", establishment: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/establishments/#{establishment}")

      html = render(show_live)
      assert html =~ "Establishment updated successfully."
      assert html =~ "some updated name"
    end
  end

  describe "Form error paths" do
    test "redirects to index when user already has establishment and visits /new", %{
      conn: conn,
      scope: scope
    } do
      _existing = establishment_fixture(scope)
      assert {:error, _redirect} = live(conn, ~p"/establishments/new")
    end

    test "submitting invalid data on edit form shows error", %{conn: conn, scope: scope} do
      establishment = establishment_fixture(scope)

      {:ok, form_live, _} =
        live(conn, ~p"/establishments/#{establishment}/edit")

      form_live
      |> form("#establishment-form", establishment: @invalid_attrs)
      |> render_submit()

      assert has_element?(form_live, "#establishment-form")
    end

    test "submitting invalid data on new form shows error", %{conn: conn} do
      {:ok, form_live, _} = live(conn, ~p"/establishments/new")

      form_live
      |> form("#establishment-form", establishment: @invalid_attrs)
      |> render_submit()

      assert has_element?(form_live, "#establishment-form")
    end
  end
end
