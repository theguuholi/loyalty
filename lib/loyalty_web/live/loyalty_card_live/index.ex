defmodule LoyaltyWeb.LoyaltyCardLive.Index do
  use LoyaltyWeb, :live_view

  alias Loyalty.LoyaltyCards

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} locale={@locale}>
      <.header>
        {gettext("Clients and cards")}
        <:subtitle>{@current_scope.establishment.name}</:subtitle>
        <:actions>
          <.button navigate={~p"/establishments/#{@current_scope.establishment.id}/"}>
            <.icon name="hero-arrow-left" /> {gettext("Back")}
          </.button>
          <.button
            variant="primary"
            navigate={~p"/establishments/#{@current_scope.establishment.id}/loyalty_cards/new"}
          >
            <.icon name="hero-plus" /> {gettext("Register client")}
          </.button>
        </:actions>
      </.header>

      <div
        :if={@cards_empty?}
        class="rounded-xl border-2 border-base-300 bg-base-100 p-10 text-center shadow-sm"
      >
        <p id="loyalty-cards-empty-message" class="text-base-content/70 mb-1 font-medium">
          {gettext("No cards yet.")}
        </p>
        <p class="text-sm text-base-content/60 mb-6">
          {gettext("Register a client by email to create their first loyalty card.")}
        </p>
        <.button
          id="loyalty-cards-empty-cta"
          variant="primary"
          navigate={~p"/establishments/#{@current_scope.establishment.id}/loyalty_cards/new"}
        >
          <.icon name="hero-plus" class="w-4 h-4" /> {gettext("Register first client")}
        </.button>
      </div>

      <div :if={not @cards_empty?} class="space-y-4">
        <p class="text-sm text-base-content/70">
          {gettext(
            "Click \"+ 1 stamp\" when the client earns a stamp. Edit to change progress or delete to remove the card."
          )}
        </p>
        <div id="loyalty_cards" phx-update="stream" class="space-y-4">
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
                  id={"add-stamp-button-#{id}"}
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
            <div id={"add-stamp-progress-#{id}"} class="mt-4">
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
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      LoyaltyCards.subscribe_loyalty_cards(socket.assigns.current_scope)
    end

    list = list_loyalty_cards(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, gettext("Clients and cards"))
     |> assign(:cards_empty?, list == [])
     |> stream(:loyalty_cards, list)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    loyalty_card = LoyaltyCards.get_loyalty_card!(socket.assigns.current_scope, id)
    {:ok, _} = LoyaltyCards.delete_loyalty_card(socket.assigns.current_scope, loyalty_card)

    list_after = list_loyalty_cards(socket.assigns.current_scope)

    {:noreply,
     socket
     |> assign(:cards_empty?, list_after == [])
     |> stream_delete(:loyalty_cards, loyalty_card)}
  end

  @impl true
  def handle_event("add_stamp", %{"id" => id}, socket) do
    loyalty_card = LoyaltyCards.get_loyalty_card!(socket.assigns.current_scope, id)

    case LoyaltyCards.add_stamp(socket.assigns.current_scope, loyalty_card) do
      {:ok, updated} ->
        updated = Loyalty.Repo.preload(updated, [:customer, :establishment, :loyalty_program])

        {:noreply,
         socket
         |> put_flash(:info, gettext("Stamp added."))
         |> assign(:loyalty_card, updated)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Could not add stamp."))}
    end
  end

  @impl true
  def handle_info({type, %Loyalty.LoyaltyCards.LoyaltyCard{}}, socket)
      when type in [:created, :updated, :deleted] do
    list = list_loyalty_cards(socket.assigns.current_scope)

    {:noreply,
     socket
     |> assign(:cards_empty?, list == [])
     |> stream(:loyalty_cards, list, reset: true)}
  end

  defp list_loyalty_cards(current_scope) do
    LoyaltyCards.list_loyalty_cards(current_scope)
  end

  defp progress_pct(card) do
    required = max(1, card.stamps_required)
    current = card.stamps_current || 0
    min(100, div(current * 100, required))
  end
end
