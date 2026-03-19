defmodule LoyaltyWeb.LoyaltyProgramLive.Show do
  use LoyaltyWeb, :live_view

  alias Loyalty.{Establishments, LoyaltyCards, LoyaltyPrograms}
  alias Loyalty.Establishments.Establishment

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} locale={@locale}>
      <.header>
        {@loyalty_program.name}
        <:subtitle>
          {@loyalty_program.stamps_required} {gettext("stamps")} = {@loyalty_program.reward_description}
        </:subtitle>
        <:actions>
          <.button navigate={~p"/establishments/#{@current_scope.establishment.id}"}>
            <.icon name="hero-arrow-left" /> {gettext("Back")}
          </.button>
          <.button
            variant="primary"
            navigate={
              ~p"/establishments/#{@current_scope.establishment.id}/loyalty_programs/#{@loyalty_program}/edit?return_to=show"
            }
          >
            <.icon name="hero-pencil-square" /> {gettext("Edit program")}
          </.button>
          <%= if @can_add_new_client do %>
            <.button
              variant="primary"
              navigate={~p"/establishments/#{@current_scope.establishment.id}/loyalty_cards/new"}
            >
              <.icon name="hero-plus" /> {gettext("Register client")}
            </.button>
          <% end %>
        </:actions>
      </.header>

      <.list>
        <:item title={gettext("Name")}>{@loyalty_program.name}</:item>
        <:item title={gettext("Stamps required")}>{@loyalty_program.stamps_required}</:item>
        <:item title={gettext("Reward description")}>{@loyalty_program.reward_description}</:item>
      </.list>

      <div class="mt-8">
        <h2 class="text-lg font-semibold text-base-content mb-2">{gettext("Clients and cards")}</h2>
        <div
          :if={@payment_issue_billing}
          class="mb-4 rounded-lg border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-950"
        >
          {gettext("Payment issue: new clients are blocked until billing is active.")}
          <.link
            class="link link-primary ml-1"
            navigate={~p"/establishments/#{@current_scope.establishment.id}"}
          >
            {gettext("Establishment dashboard")}
          </.link>
        </div>
        <div
          :if={not @can_add_new_client and not @payment_issue_billing}
          class="mb-4 text-sm text-base-content/70"
        >
          {gettext("New clients are limited by your plan.")}
          <.link
            class="link link-primary"
            navigate={~p"/establishments/#{@current_scope.establishment.id}"}
          >
            {gettext("Subscribe or view dashboard")}
          </.link>
        </div>
        <%= if @cards_empty? do %>
          <div class="rounded-xl border-2 border-base-300 bg-base-100 p-10 text-center shadow-sm">
            <p id="program-cards-empty-message" class="text-base-content/70 mb-1 font-medium">
              {gettext("No cards yet.")}
            </p>
            <p class="text-sm text-base-content/60 mb-6">
              {gettext("Register a client by email to create their first loyalty card.")}
            </p>
            <%= if @can_add_new_client do %>
              <.button
                id="program-cards-empty-cta"
                variant="primary"
                navigate={~p"/establishments/#{@current_scope.establishment.id}/loyalty_cards/new"}
              >
                <.icon name="hero-plus" class="w-4 h-4" /> {gettext("Register first client")}
              </.button>
            <% end %>
          </div>
        <% else %>
          <p class="text-sm text-base-content/70 mb-4">
            {gettext(
              "Click \"+ 1 stamp\" when the client earns a stamp. Edit to change progress or delete to remove the card."
            )}
          </p>
          <div id="program_loyalty_cards" phx-update="stream" class="space-y-4">
            <div
              :for={{id, loyalty_card} <- @streams.loyalty_cards}
              id={id}
              class="rounded-xl border-2 border-base-300 bg-base-100 p-5 shadow-sm transition-shadow hover:shadow-md"
            >
              <div class="flex flex-wrap items-start justify-between gap-3">
                <div class="min-w-0 flex-1">
                  <p class="text-sm font-medium uppercase tracking-wide text-base-content/60">
                    {gettext("Client")}
                  </p>
                  <p class="mt-0.5 truncate font-semibold text-base-content">
                    {loyalty_card.customer.email}
                  </p>
                </div>
                <div class="flex shrink-0 gap-2">
                  <button
                    id={"program-add-stamp-#{id}"}
                    type="button"
                    phx-click="add_stamp"
                    phx-value-id={loyalty_card.id}
                    class="btn btn-primary btn-sm"
                  >
                    <.icon name="hero-plus" class="w-4 h-4" /> {gettext("+ 1 stamp")}
                  </button>
                  <.link
                    navigate={
                      ~p"/establishments/#{@current_scope.establishment.id}/loyalty_cards/#{loyalty_card}/edit"
                    }
                    class="btn btn-ghost btn-sm"
                  >
                    {gettext("Edit")}
                  </.link>
                  <.link
                    phx-click={JS.push("delete", value: %{id: loyalty_card.id}) |> hide("##{id}")}
                    data-confirm={gettext("Are you sure?")}
                    class="btn btn-ghost btn-sm text-error"
                  >
                    {gettext("Delete")}
                  </.link>
                </div>
              </div>
              <div id={"program-stamp-progress-#{id}"} class="mt-4">
                <div class="flex items-center justify-between text-sm">
                  <span class="text-base-content/70">
                    {loyalty_card.stamps_current} {gettext("of")} {loyalty_card.stamps_required} {gettext(
                      "stamps"
                    )}
                  </span>
                  <%= if loyalty_card.stamps_current >= loyalty_card.stamps_required do %>
                    <span class="font-medium text-primary">{gettext("Reward ready!")}</span>
                  <% end %>
                </div>
                <div class="mt-1.5 h-3 w-full overflow-hidden rounded-full bg-base-300">
                  <div
                    class="h-full rounded-full bg-primary transition-all duration-300"
                    style={"width: #{progress_pct(loyalty_card)}%"}
                  >
                  </div>
                </div>
              </div>
              <p class="mt-2 text-sm text-base-content/70">
                {gettext("Reward")}: {loyalty_card.loyalty_program.reward_description}
              </p>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Establishments.subscribe_establishments(socket.assigns.current_scope)
      LoyaltyPrograms.subscribe_loyalty_programs(socket.assigns.current_scope)
      LoyaltyCards.subscribe_loyalty_cards(socket.assigns.current_scope)
    end

    scope = socket.assigns.current_scope
    loyalty_program = LoyaltyPrograms.get_loyalty_program!(scope, id)
    cards = list_loyalty_cards(scope)

    establishment = Establishments.get_establishment!(scope, scope.establishment.id)
    billing = billing_assigns(establishment)

    {:ok,
     socket
     |> assign(:page_title, loyalty_program.name)
     |> assign(:loyalty_program, loyalty_program)
     |> assign(:cards_empty?, cards == [])
     |> assign(:can_add_new_client, billing.can_add_new_client)
     |> assign(:payment_issue_billing, billing.payment_issue)
     |> stream(:loyalty_cards, cards)}
  end

  @impl true
  def handle_event("add_stamp", %{"id" => card_id}, socket) do
    loyalty_card = LoyaltyCards.get_loyalty_card!(socket.assigns.current_scope, card_id)

    case LoyaltyCards.add_stamp(socket.assigns.current_scope, loyalty_card) do
      {:ok, _updated} ->
        {:noreply, put_flash(socket, :info, gettext("Stamp added."))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Could not add stamp."))}
    end
  end

  def handle_event("delete", %{"id" => card_id}, socket) do
    loyalty_card = LoyaltyCards.get_loyalty_card!(socket.assigns.current_scope, card_id)
    {:ok, _} = LoyaltyCards.delete_loyalty_card(socket.assigns.current_scope, loyalty_card)

    scope = socket.assigns.current_scope
    list_after = list_loyalty_cards(scope)

    establishment = Establishments.get_establishment!(scope, scope.establishment.id)
    billing = billing_assigns(establishment)

    {:noreply,
     socket
     |> assign(:cards_empty?, list_after == [])
     |> assign(:can_add_new_client, billing.can_add_new_client)
     |> assign(:payment_issue_billing, billing.payment_issue)
     |> stream_delete(:loyalty_cards, loyalty_card)}
  end

  @impl true
  def handle_info(
        {:updated, %Loyalty.LoyaltyPrograms.LoyaltyProgram{id: id} = loyalty_program},
        %{assigns: %{loyalty_program: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :loyalty_program, loyalty_program)}
  end

  def handle_info(
        {:deleted, %Loyalty.LoyaltyPrograms.LoyaltyProgram{id: id}},
        %{assigns: %{loyalty_program: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, gettext("The current program was deleted."))
     |> push_navigate(to: ~p"/establishments/#{socket.assigns.current_scope.establishment.id}")}
  end

  def handle_info({type, %Loyalty.LoyaltyPrograms.LoyaltyProgram{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end

  def handle_info({type, %Loyalty.LoyaltyCards.LoyaltyCard{}}, socket)
      when type in [:created, :updated, :deleted] do
    scope = socket.assigns.current_scope
    list = list_loyalty_cards(scope)

    establishment = Establishments.get_establishment!(scope, scope.establishment.id)
    billing = billing_assigns(establishment)

    {:noreply,
     socket
     |> assign(:cards_empty?, list == [])
     |> assign(:can_add_new_client, billing.can_add_new_client)
     |> assign(:payment_issue_billing, billing.payment_issue)
     |> stream(:loyalty_cards, list, reset: true)}
  end

  def handle_info(
        {:updated, %Establishment{id: eid}},
        %{assigns: %{current_scope: %{establishment: %{id: eid}}}} = socket
      ) do
    scope = socket.assigns.current_scope
    establishment = Establishments.get_establishment!(scope, eid)
    billing = billing_assigns(establishment)

    {:noreply,
     socket
     |> assign(:can_add_new_client, billing.can_add_new_client)
     |> assign(:payment_issue_billing, billing.payment_issue)}
  end

  def handle_info({type, %Establishment{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end

  defp list_loyalty_cards(current_scope) do
    LoyaltyCards.list_loyalty_cards(current_scope)
  end

  defp progress_pct(card) do
    required = max(1, card.stamps_required)
    current = card.stamps_current || 0
    min(100, div(current * 100, required))
  end

  defp billing_assigns(%Establishment{} = establishment) do
    can_add = Establishments.check_new_loyalty_card_allowed(establishment) == :ok
    payment_issue = establishment.subscription_status in ["past_due", "unpaid"]
    %{can_add_new_client: can_add, payment_issue: payment_issue}
  end
end
