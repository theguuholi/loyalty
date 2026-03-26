# Admin Dashboard: Client Emails + Paid/Unpaid Status

## Context
The product owner needs visibility into all registered establishments (B2B customers) — their email, subscription status, and card count — to understand who is paying and who isn't. No admin view exists today; all queries are scoped to the current user. This adds a protected `/admin` page with filtering.

---

## Approach

A single LiveView page at `/admin` protected by a new `on_mount :require_admin` hook that checks the logged-in user's email against a config value. The data comes from a new unscoped Ecto query that joins `establishments` + `users` and aggregates card counts — all in one query (no N+1).

---

## Files to Change

| File | Action |
|------|--------|
| `config/config.exs` | Add `config :loyalty, :admin_email, "..."` |
| `lib/loyalty/establishments.ex` | Add `list_all_establishments_with_owner_emails/1` |
| `lib/loyalty_web/user_auth.ex` | Add `on_mount(:require_admin, ...)` clause |
| `lib/loyalty_web/router.ex` | Add `live_session :require_admin` with `/admin` route |
| `lib/loyalty_web/live/admin_live.ex` | **New file** — the admin LiveView |

---

## Step 1 — Config (`config/config.exs`)

Add alongside the existing `:stripe` config:

```elixir
config :loyalty, :admin_email, System.get_env("ADMIN_EMAIL") || "your@email.com"
```

Replace the fallback with your real email.

---

## Step 2 — Ecto Query (`lib/loyalty/establishments.ex`)

Add `alias Loyalty.Accounts.User` to the existing alias line (line 9):
```elixir
alias Loyalty.{Accounts.Scope, Accounts.User, Billing, Establishments.Establishment, LoyaltyCards.LoyaltyCard}
```

Add this function before the private helpers:

```elixir
@doc "Returns all establishments with owner email and card count. Admin only, no user scope."
def list_all_establishments_with_owner_emails(filter \\ :all) do
  card_count_query =
    from(c in LoyaltyCard,
      group_by: c.establishment_id,
      select: %{establishment_id: c.establishment_id, count: count(c.id)}
    )

  base =
    from(e in Establishment,
      join: u in User,
      on: u.id == e.user_id,
      left_join: cc in subquery(card_count_query),
      on: cc.establishment_id == e.id,
      select: %{
        id: e.id,
        name: e.name,
        subscription_status: e.subscription_status,
        inserted_at: e.inserted_at,
        user_email: u.email,
        card_count: coalesce(cc.count, 0)
      },
      order_by: [desc: e.inserted_at]
    )

  query =
    case filter do
      :active -> where(base, [e], e.subscription_status == "active")
      :unpaid -> where(base, [e], is_nil(e.subscription_status) or e.subscription_status in ["unpaid", "past_due", "canceled"])
      _ -> base
    end

  Repo.all(query)
end
```

Notes:
- `import Ecto.Query` is already present — `coalesce/2` is available
- Returns plain maps (not structs) — fine for display-only data
- Single query: no N+1

---

## Step 3 — Admin on_mount hook (`lib/loyalty_web/user_auth.ex`)

Add after the `:require_sudo_mode` clause (after line ~258):

```elixir
def on_mount(:require_admin, _params, _session, socket) do
  admin_email = Application.compile_env(:loyalty, :admin_email)

  if socket.assigns.current_scope &&
       socket.assigns.current_scope.user &&
       socket.assigns.current_scope.user.email == admin_email do
    {:cont, socket}
  else
    socket =
      socket
      |> Phoenix.LiveView.put_flash(:error, gettext("Not authorized."))
      |> Phoenix.LiveView.redirect(to: ~p"/")

    {:halt, socket}
  end
end
```

This runs **after** `:require_authenticated` in the on_mount list, so `current_scope.user` is guaranteed populated.

---

## Step 4 — Router (`lib/loyalty_web/router.ex`)

Inside the existing `scope "/", LoyaltyWeb do` that pipes through `[:browser, :require_authenticated_user]`, add a new `live_session` block after the existing `:require_authenticated_user` one:

```elixir
live_session :require_admin,
  on_mount: [
    {LoyaltyWeb.UserAuth, :require_authenticated},
    {LoyaltyWeb.UserAuth, :require_admin}
  ] do
  live "/admin", AdminLive, :index
end
```

Note: `:assign_establishment_to_scope` is intentionally omitted — admin page doesn't need it.

---

## Step 5 — AdminLive (`lib/loyalty_web/live/admin_live.ex`)

New file:

```elixir
defmodule LoyaltyWeb.AdminLive do
  use LoyaltyWeb, :live_view

  alias Loyalty.Establishments

  @valid_filters ~w(all active unpaid)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, gettext("Admin"))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filter =
      case params["filter"] do
        f when f in @valid_filters -> String.to_existing_atom(f)
        _ -> :all
      end

    rows = Establishments.list_all_establishments_with_owner_emails(filter)

    {:noreply, socket |> assign(:filter, filter) |> assign(:rows, rows)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} locale={@locale}>
      <.header>
        {gettext("Admin Dashboard")}
        <:subtitle>{gettext("All registered establishments")}</:subtitle>
      </.header>

      <div class="flex gap-2 my-4">
        <.link patch={~p"/admin"} class={["...", @filter == :all && "font-bold"]}>{gettext("All")}</.link>
        <.link patch={~p"/admin?filter=active"} class={["...", @filter == :active && "font-bold"]}>{gettext("Active")}</.link>
        <.link patch={~p"/admin?filter=unpaid"} class={["...", @filter == :unpaid && "font-bold"]}>{gettext("Unpaid / Free")}</.link>
      </div>

      <.table id="admin-table" rows={@rows}>
        <:col :let={row} label={gettext("Email")}>{row.user_email}</:col>
        <:col :let={row} label={gettext("Establishment")}>{row.name}</:col>
        <:col :let={row} label={gettext("Plan")}><.status_badge status={row.subscription_status} /></:col>
        <:col :let={row} label={gettext("Cards")}>{row.card_count}</:col>
        <:col :let={row} label={gettext("Registered")}>{Calendar.strftime(row.inserted_at, "%d/%m/%Y")}</:col>
      </.table>

      <p :if={@rows == []} class="text-center mt-6 opacity-60">{gettext("No establishments found.")}</p>
    </Layouts.app>
    """
  end

  defp status_badge(assigns) do
    {label, color} =
      case assigns.status do
        "active"   -> {gettext("Active"), "text-green-600"}
        "past_due" -> {gettext("Past due"), "text-yellow-600"}
        "unpaid"   -> {gettext("Unpaid"), "text-red-600"}
        "canceled" -> {gettext("Canceled"), "text-gray-500"}
        _          -> {gettext("Free"), "text-gray-400"}
      end

    assigns = assign(assigns, label: label, color: color)
    ~H"<span class={@color}>{@label}</span>"
  end
end
```

Key decisions:
- Uses `<.table>` component with `rows={@rows}` — works with plain maps
- Filter tabs use `patch` so only `handle_params` re-runs on filter change — bookmarkable URLs
- `String.to_existing_atom` is safe: atoms are guarded by `when f in @valid_filters` before conversion
- Plain `@rows` assign (not a stream) — the whole list reloads on filter change anyway

---

## Verification

1. Log in with the admin email → visit `/admin` → table shows all establishments
2. Log in with a non-admin email → visit `/admin` → redirected to `/` with flash error
3. Click "Active" filter → URL becomes `/admin?filter=active` → only active subscriptions shown
4. Click "Unpaid / Free" → shows nil + unpaid + past_due + canceled
5. Run `mix precommit` — passes compile, format, credo, dialyzer, tests, coverage
