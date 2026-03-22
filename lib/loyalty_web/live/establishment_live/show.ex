defmodule LoyaltyWeb.EstablishmentLive.Show do
  use LoyaltyWeb, :live_view

  alias Loyalty.{Accounts.Scope, Billing, Establishments, LoyaltyPrograms}
  alias Loyalty.Billing.Stripe
  alias Loyalty.Establishments.Establishment

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} locale={@locale}>
      <.header>
        {@establishment.name}
        <:subtitle>
          <span class="block">
            {@plan_label}
            <%= if @client_limit do %>
              · {@client_count} / {@client_limit} {gettext("clients")}
            <% else %>
              · {@client_count} {gettext("clients")}
            <% end %>
          </span>
          <%= if @loyalty_program do %>
            <span class="block mt-1 text-sm font-normal text-base-content/70">
              {@loyalty_program.stamps_required} {gettext("stamps")} = {@loyalty_program.reward_description}
            </span>
          <% else %>
            <span class="block mt-1 text-sm font-normal text-base-content/70">
              {gettext("Create a loyalty program")}
            </span>
          <% end %>
        </:subtitle>
        <:actions>
          <.button navigate={~p"/establishments"}>
            <.icon name="hero-arrow-left" /> {gettext("Back")}
          </.button>
          <.button
            variant="primary"
            navigate={~p"/establishments/#{@establishment}/edit?return_to=show"}
          >
            <.icon name="hero-pencil-square" /> {gettext("Edit establishment")}
          </.button>
        </:actions>
      </.header>

      <div
        :if={@payment_issue}
        class="mb-4 rounded-xl border border-amber-300 bg-amber-50 px-4 py-3 text-sm text-amber-950"
        id="dashboard-payment-issue-banner"
      >
        {gettext(
          "There is a problem with your subscription payment. New clients cannot be registered until billing is active. Existing cards still work."
        )}
      </div>

      <div
        id="dashboard-billing-card"
        class="mb-4 rounded-xl border border-base-300 bg-base-100 p-4 shadow-sm"
      >
        <p class="font-semibold text-base-content">{@plan_label}</p>
        <p class="mt-1 text-sm text-base-content/70">
          <%= if @client_limit do %>
            {gettext("Clients (loyalty cards):")} {@client_count} / {@client_limit}
          <% else %>
            {gettext("Clients (loyalty cards):")} {@client_count}
          <% end %>
        </p>
        <%= if @on_free_plan and @show_subscribe_cta do %>
          <p class="mt-2 text-sm text-base-content/70">
            {gettext(
              "The free plan allows up to %{count} loyalty cards (clients). More clients require the monthly paid plan.",
              count: @client_limit
            )}
          </p>
        <% end %>
        <%= if @show_free_plan_near_limit_hint do %>
          <p
            class="mt-2 rounded-lg border border-warning/40 bg-warning/10 px-3 py-2 text-sm text-base-content"
            id="dashboard-free-plan-near-limit"
            role="status"
          >
            {gettext("You're close to the free plan limit — subscribe to add more clients.")}
          </p>
        <% end %>
        <%= if @show_subscribe_cta do %>
          <div class="mt-3">
            <.button
              variant="primary"
              phx-click="start_stripe_checkout"
              id="dashboard-stripe-checkout"
            >
              {gettext("Subscribe (monthly) for more clients")}
            </.button>
          </div>
        <% end %>
      </div>

      <div
        id="dashboard-program-card"
        class="mb-4 rounded-xl border border-base-300 bg-base-100 p-4 shadow-sm"
      >
        <%= if @loyalty_program do %>
          <p class="font-semibold text-base-content">{gettext("Active program")}</p>
          <p class="mt-1 text-sm text-base-content/70">
            {@loyalty_program.stamps_required} {gettext("stamps")} = {@loyalty_program.reward_description}
          </p>
          <div class="mt-3">
            <.button
              variant="primary"
              id="dashboard-edit-program-link"
              navigate={
                ~p"/establishments/#{@establishment}/loyalty_programs/#{@loyalty_program}/edit?return_to=show"
              }
              class="btn btn-primary btn-sm"
            >
              {gettext("Edit program")}
            </.button>
          </div>
        <% else %>
          <p class="font-semibold text-base-content">{gettext("Program")}</p>
          <p class="mt-1 text-sm text-base-content/70">{gettext("No program yet.")}</p>
          <div class="mt-3">
            <.button
              variant="primary"
              navigate={~p"/establishments/#{@establishment}/loyalty_programs/new?return_to=show"}
              class="btn btn-primary btn-sm"
            >
              {gettext("Create program")}
            </.button>
          </div>
        <% end %>
      </div>

      <p class="text-sm font-semibold mb-2">{gettext("Quick actions")}</p>
      <div class="flex flex-wrap gap-2">
        <%= if @loyalty_program do %>
          <.button
            id="dashboard-program-and-clients-link"
            variant="primary"
            navigate={~p"/establishments/#{@establishment}/loyalty_programs/#{@loyalty_program}"}
          >
            {gettext("Program and clients")}
          </.button>
          <%= if @can_add_new_client do %>
            <.link
              id="dashboard-register-client-link"
              navigate={~p"/establishments/#{@establishment}/loyalty_cards/new"}
              class="btn btn-primary btn-soft"
            >
              <.icon name="hero-plus" /> {gettext("Register client")}
            </.link>
          <% else %>
            <span class="rounded-lg border border-base-300 bg-base-200/50 px-3 py-2 text-sm text-base-content/70">
              {gettext("Client limit reached or billing inactive — use Subscribe above.")}
            </span>
          <% end %>
        <% else %>
          <.button
            id="dashboard-create-program-link"
            variant="primary"
            navigate={~p"/establishments/#{@establishment}/loyalty_programs/new"}
          >
            <.icon name="hero-plus" /> {gettext("Create program")}
          </.button>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Establishments.subscribe_establishments(socket.assigns.current_scope)
    end

    establishment = Establishments.get_establishment!(socket.assigns.current_scope, id)
    scope = Scope.put_establishment(socket.assigns.current_scope, establishment)

    loyalty_program =
      case LoyaltyPrograms.list_loyalty_programs(scope) do
        [p | _] -> p
        [] -> nil
      end

    socket =
      socket
      |> assign(:page_title, establishment.name)
      |> assign(:establishment, establishment)
      |> assign(:loyalty_program, loyalty_program)
      |> assign_billing(establishment)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      case params["checkout"] do
        "success" ->
          id = socket.assigns.establishment.id

          establishment =
            Establishments.get_establishment!(socket.assigns.current_scope, id)

          socket
          |> assign(:establishment, establishment)
          |> assign_billing(establishment)
          |> put_flash(:info, gettext("Thank you! Your subscription should be active shortly."))

        "cancel" ->
          put_flash(socket, :info, gettext("Checkout was canceled."))

        _ ->
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("start_stripe_checkout", _params, socket) do
    est = socket.assigns.establishment
    base = LoyaltyWeb.Endpoint.url()

    success =
      base <>
        "/establishments/#{est.id}?checkout=success"

    cancel =
      base <>
        "/establishments/#{est.id}?checkout=cancel"

    case Stripe.create_subscription_checkout_session(est, success, cancel) do
      {:ok, url} ->
        {:noreply, redirect(socket, external: url)}

      {:error, :stripe_not_configured} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Stripe is not configured. Set STRIPE_SECRET_KEY and STRIPE_PRICE_ID.")
         )}

      {:error, _} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Could not start checkout. Try again later.")
         )}
    end
  end

  @impl true
  def handle_info(
        {:updated, %Establishment{id: id} = establishment},
        %{assigns: %{establishment: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> assign(:establishment, establishment)
     |> assign_billing(establishment)}
  end

  def handle_info(
        {:deleted, %Establishment{id: id}},
        %{assigns: %{establishment: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, gettext("The current establishment was deleted."))
     |> push_navigate(to: ~p"/establishments")}
  end

  def handle_info({type, %Establishment{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end

  defp assign_billing(socket, %Establishment{} = establishment) do
    count = Establishments.count_loyalty_cards(establishment.id)
    can_add = Establishments.check_new_loyalty_card_allowed(establishment) == :ok

    {plan_label, limit} =
      cond do
        Billing.paid_subscription_allows_new_clients?(establishment) ->
          {gettext("Paid plan"), Billing.paid_client_limit()}

        Billing.on_free_plan?(establishment) ->
          {gettext("Free plan"), Billing.free_client_limit()}

        true ->
          {gettext("Subscription inactive"), nil}
      end

    payment_issue = establishment.subscription_status in ["past_due", "unpaid"]

    show_subscribe = not Billing.paid_subscription_allows_new_clients?(establishment)
    on_free = Billing.on_free_plan?(establishment)
    free_limit = Billing.free_client_limit()

    near_limit_hint =
      on_free && show_subscribe && limit == free_limit &&
        count >= free_limit - 2

    socket
    |> assign(:client_count, count)
    |> assign(:client_limit, limit)
    |> assign(:plan_label, plan_label)
    |> assign(:can_add_new_client, can_add)
    |> assign(:payment_issue, payment_issue)
    |> assign(:show_subscribe_cta, show_subscribe)
    |> assign(:on_free_plan, on_free)
    |> assign(:show_free_plan_near_limit_hint, near_limit_hint)
  end
end
