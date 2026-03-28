defmodule LoyaltyWeb.LoyaltyCardLive.Index do
  use LoyaltyWeb, :live_view

  alias Loyalty.{Establishments, LoyaltyCards}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      LoyaltyCards.subscribe_loyalty_cards(socket.assigns.current_scope)
    end

    scope = socket.assigns.current_scope

    establishment =
      Establishments.get_establishment!(scope, scope.establishment.id)

    can_add = Establishments.check_new_loyalty_card_allowed(establishment) == :ok
    list = list_loyalty_cards(scope)

    {:ok,
     socket
     |> assign(:page_title, gettext("Clients and cards"))
     |> assign(:cards_empty?, list == [])
     |> assign(:can_add_new_client, can_add)
     |> stream(:loyalty_cards, list)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    loyalty_card = LoyaltyCards.get_loyalty_card!(socket.assigns.current_scope, id)
    {:ok, _} = LoyaltyCards.delete_loyalty_card(socket.assigns.current_scope, loyalty_card)

    scope = socket.assigns.current_scope
    list_after = list_loyalty_cards(scope)

    establishment = Establishments.get_establishment!(scope, scope.establishment.id)
    can_add = Establishments.check_new_loyalty_card_allowed(establishment) == :ok

    {:noreply,
     socket
     |> assign(:cards_empty?, list_after == [])
     |> assign(:can_add_new_client, can_add)
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
    scope = socket.assigns.current_scope
    list = list_loyalty_cards(scope)

    establishment = Establishments.get_establishment!(scope, scope.establishment.id)
    can_add = Establishments.check_new_loyalty_card_allowed(establishment) == :ok

    {:noreply,
     socket
     |> assign(:cards_empty?, list == [])
     |> assign(:can_add_new_client, can_add)
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

  defp card_gradient(id) do
    gradients = [
      "background: linear-gradient(135deg, #1b4d3e 0%, #1e5c4a 50%, #0f3329 100%)",
      "background: linear-gradient(135deg, #1b3a4d 0%, #1e4d5c 50%, #0f2533 100%)",
      "background: linear-gradient(135deg, #3d1a4d 0%, #4d1e5c 50%, #250f33 100%)",
      "background: linear-gradient(135deg, #3d2a1b 0%, #5c3a1e 50%, #2d1a0f 100%)",
      "background: linear-gradient(135deg, #1b3d2a 0%, #1e5c3a 50%, #0f2d1a 100%)"
    ]

    Enum.at(gradients, :erlang.phash2(id, length(gradients)))
  end
end
