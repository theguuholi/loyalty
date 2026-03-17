defmodule LoyaltyWeb.LoyaltyCardLive.Show do
  use LoyaltyWeb, :live_view

  alias Loyalty.LoyaltyCards

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Adicionar carimbo
        <:subtitle>{customer_email(@loyalty_card)}</:subtitle>
        <:actions>
          <.link
            id="add-stamp-back-link"
            navigate={~p"/establishments/#{@current_scope.establishment.id}/loyalty_cards"}
            class="text-sm text-[#1b4d3e] hover:underline"
          >
            ← Voltar aos cartões
          </.link>
          <.button navigate={
            ~p"/establishments/#{@current_scope.establishment.id}/loyalty_cards/#{@loyalty_card}/edit?return_to=show"
          }>
            <.icon name="hero-pencil-square" /> Editar
          </.button>
        </:actions>
      </.header>

      <div id="add-stamp-card" class="rounded-xl border-2 border-[#e2e5e8] bg-white p-4 shadow-sm">
        <p class="font-semibold text-[#1a1d21]">{establishment_name(@loyalty_card)}</p>
        <div id="add-stamp-progress" class="mt-2 flex items-center gap-2">
          <div class="h-2 flex-1 rounded-full bg-[#eef0f2] overflow-hidden">
            <div
              class="h-full rounded-full bg-[#1b4d3e] transition-all"
              style={"width: #{progress_pct(@loyalty_card)}%"}
            >
            </div>
          </div>
          <span class="text-sm text-[#6b7280]">
            {@loyalty_card.stamps_current} de {@loyalty_card.stamps_required} carimbos
          </span>
        </div>
        <p class="mt-2 text-sm text-[#40916c]">
          {reward_description(@loyalty_card)} Ao completar {@loyalty_card.stamps_required}, o cliente ganha a recompensa.
        </p>
        <button
          id="add-stamp-button"
          type="button"
          phx-click="add_stamp"
          class="mt-4 btn btn-primary"
        >
          + 1 carimbo
        </button>
      </div>
    </Layouts.app>
    """
  end

  defp customer_email(card) do
    if Ecto.assoc_loaded?(card.customer) && card.customer do
      card.customer.email
    else
      "—"
    end
  end

  defp establishment_name(card) do
    if Ecto.assoc_loaded?(card.establishment) && card.establishment do
      card.establishment.name
    else
      "—"
    end
  end

  defp reward_description(card) do
    if Ecto.assoc_loaded?(card.loyalty_program) && card.loyalty_program do
      card.loyalty_program.reward_description <> ". "
    else
      ""
    end
  end

  defp progress_pct(card) do
    required = max(1, card.stamps_required)
    current = card.stamps_current || 0
    min(100, div(current * 100, required))
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      LoyaltyCards.subscribe_loyalty_cards(socket.assigns.current_scope)
    end

    scope = socket.assigns.current_scope

    loyalty_card =
      scope
      |> LoyaltyCards.get_loyalty_card!(id)
      |> Loyalty.Repo.preload([:customer, :establishment, :loyalty_program])

    {:ok,
     socket
     |> assign(:page_title, "Adicionar carimbo")
     |> assign(:loyalty_card, loyalty_card)}
  end

  @impl true
  def handle_event("add_stamp", _params, socket) do
    case LoyaltyCards.add_stamp(socket.assigns.current_scope, socket.assigns.loyalty_card) do
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

  @impl true
  def handle_info(
        {:updated, %Loyalty.LoyaltyCards.LoyaltyCard{id: id} = loyalty_card},
        %{assigns: %{loyalty_card: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :loyalty_card, loyalty_card)}
  end

  def handle_info(
        {:deleted, %Loyalty.LoyaltyCards.LoyaltyCard{id: id}},
        %{assigns: %{loyalty_card: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "The current loyalty_card was deleted.")
     |> push_navigate(
       to: ~p"/establishments/#{socket.assigns.current_scope.establishment.id}/loyalty_cards"
     )}
  end

  def handle_info({type, %Loyalty.LoyaltyCards.LoyaltyCard{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end
