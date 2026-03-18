defmodule LoyaltyWeb.LoyaltyCardLive.Index do
  use LoyaltyWeb, :live_view

  alias Loyalty.LoyaltyCards

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Listing Loyalty cards
        <:actions>
          <.button
            variant="primary"
            navigate={~p"/establishments/#{@current_scope.establishment.id}/"}
          >
            <.icon name="hero-plus" /> back
          </.button>
          <.button
            variant="primary"
            navigate={~p"/establishments/#{@current_scope.establishment.id}/loyalty_cards/new"}
          >
            <.icon name="hero-plus" /> New Loyalty card
          </.button>
        </:actions>
      </.header>

      <div :for={{id, loyalty_card} <- @streams.loyalty_cards}>
        <div
          id={"add-stamp-card-#{id}"}
          class="rounded-xl border-2 border-[#e2e5e8] bg-white p-4 shadow-sm"
        >
          <p class="font-semibold text-[#1a1d21]">
            {loyalty_card.customer.email} - {loyalty_card.establishment.name}
          </p>
          <div id="add-stamp-progress" class="mt-2 flex items-center gap-2">
            <div class="h-2 flex-1 rounded-full bg-[#eef0f2] overflow-hidden">
              <div
                class="h-full rounded-full bg-[#1b4d3e] transition-all"
                style={"width: #{progress_pct(loyalty_card)}%"}
              >
              </div>
            </div>
            <span class="text-sm text-[#6b7280]">
              {loyalty_card.stamps_current} de {loyalty_card.stamps_required} carimbos
            </span>
          </div>
          <p class="mt-2 text-sm text-[#40916c]">
            {loyalty_card.loyalty_program.reward_description} Ao completar {loyalty_card.stamps_required}, o cliente ganha a recompensa.
          </p>
          <button
            id="add-stamp-button"
            type="button"
            phx-click="add_stamp"
            phx-value-id={loyalty_card.id}
            class="mt-4 btn btn-primary"
          >
            + 1 carimbo
          </button>
        </div>
        <div class="sr-only">
          <.link navigate={
            ~p"/establishments/#{@current_scope.establishment.id}/loyalty_cards/#{loyalty_card}"
          }>
            Show
          </.link>
        </div>
        <.link navigate={
          ~p"/establishments/#{@current_scope.establishment.id}/loyalty_cards/#{loyalty_card}/edit"
        }>
          Edit
        </.link>
        <.link
          phx-click={JS.push("delete", value: %{id: loyalty_card.id}) |> hide("##{id}")}
          data-confirm="Are you sure?"
        >
          Delete
        </.link>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      LoyaltyCards.subscribe_loyalty_cards(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Listing Loyalty cards")
     |> stream(:loyalty_cards, list_loyalty_cards(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    loyalty_card = LoyaltyCards.get_loyalty_card!(socket.assigns.current_scope, id)
    {:ok, _} = LoyaltyCards.delete_loyalty_card(socket.assigns.current_scope, loyalty_card)

    {:noreply, stream_delete(socket, :loyalty_cards, loyalty_card)}
  end

  @impl true
  def handle_info({type, %Loyalty.LoyaltyCards.LoyaltyCard{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply,
     stream(socket, :loyalty_cards, list_loyalty_cards(socket.assigns.current_scope), reset: true)}
  end

  defp list_loyalty_cards(current_scope) do
    LoyaltyCards.list_loyalty_cards(current_scope)
  end

  @impl true
  def handle_event("add_stamp", %{"id" => id}, socket) do
    loyalty_card = LoyaltyCards.get_loyalty_card!(socket.assigns.current_scope, id)

    case LoyaltyCards.add_stamp(socket.assigns.current_scope, loyalty_card) do
      {:ok, updated} ->
        updated = Loyalty.Repo.preload(updated, [:customer, :establishment, :loyalty_program])

        {:noreply,
         socket
         |> put_flash(:info, "Carimbo adicionado.")
         |> assign(:loyalty_card, updated)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Não foi possível adicionar o carimbo.")}
    end
  end

  defp progress_pct(card) do
    required = max(1, card.stamps_required)
    current = card.stamps_current || 0
    min(100, div(current * 100, required))
  end
end
