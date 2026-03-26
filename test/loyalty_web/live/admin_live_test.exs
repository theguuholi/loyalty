defmodule LoyaltyWeb.AdminLiveTest do
  use LoyaltyWeb.ConnCase

  import Phoenix.LiveViewTest
  import Loyalty.{AccountsFixtures, EstablishmentsFixtures}

  @admin_email Application.compile_env(:loyalty, :admin_email)

  defp log_in_admin(conn) do
    user = user_fixture(%{email: @admin_email})
    log_in_user(conn, user)
  end

  describe "Admin dashboard — access control" do
    test "redirects unauthenticated users", %{conn: conn} do
      {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/admin")
    end

    test "redirects non-admin users with flash error", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      {:error, {:redirect, %{to: "/", flash: %{"error" => _}}}} = live(conn, ~p"/admin")
    end

    test "allows admin user to access the page", %{conn: conn} do
      conn = log_in_admin(conn)
      {:ok, _lv, html} = live(conn, ~p"/admin")
      assert html =~ "Admin Dashboard"
    end
  end

  describe "Admin dashboard — content" do
    setup %{conn: conn} do
      conn = log_in_admin(conn)
      %{conn: conn}
    end

    test "shows all establishments with owner email and card count", %{conn: conn} do
      user = user_fixture()
      scope = Loyalty.Accounts.Scope.for_user(user)
      establishment_fixture(scope)

      {:ok, _lv, html} = live(conn, ~p"/admin")

      assert html =~ user.email
      assert html =~ "Admin Dashboard"
      assert html =~ "All registered establishments"
    end

    test "shows empty state when no establishments", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin")
      assert html =~ "No establishments found."
    end

    test "filters by active subscription", %{conn: conn} do
      user = user_fixture()
      scope = Loyalty.Accounts.Scope.for_user(user)
      establishment_fixture(scope)

      {:ok, lv, _html} = live(conn, ~p"/admin")

      html = lv |> element("a", "Active") |> render_click()
      assert_patch(lv, ~p"/admin?filter=active")
      assert html =~ "No establishments found."
    end

    test "filters by unpaid/free", %{conn: conn} do
      user = user_fixture()
      scope = Loyalty.Accounts.Scope.for_user(user)
      establishment_fixture(scope)

      {:ok, lv, _html} = live(conn, ~p"/admin")

      html = lv |> element("a", "Unpaid / Free") |> render_click()
      assert_patch(lv, ~p"/admin?filter=unpaid")
      assert html =~ user.email
    end

    test "all filter shows all establishments", %{conn: conn} do
      user = user_fixture()
      scope = Loyalty.Accounts.Scope.for_user(user)
      establishment_fixture(scope)

      {:ok, lv, _html} = live(conn, ~p"/admin?filter=unpaid")

      html = lv |> element("a", "All") |> render_click()
      assert_patch(lv, ~p"/admin")
      assert html =~ user.email
    end

    test "invalid filter param defaults to all", %{conn: conn} do
      user = user_fixture()
      scope = Loyalty.Accounts.Scope.for_user(user)
      establishment_fixture(scope)

      {:ok, _lv, html} = live(conn, ~p"/admin?filter=invalid")
      assert html =~ user.email
    end

    test "renders status badge for free plan", %{conn: conn} do
      user = user_fixture()
      scope = Loyalty.Accounts.Scope.for_user(user)
      establishment_fixture(scope)

      {:ok, _lv, html} = live(conn, ~p"/admin")
      assert html =~ "Free"
    end
  end
end
