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
            navigate={~p"/establishments/#{@current_scope.establishment.id}/loyalty_cards/new"}
          >
            <.icon name="hero-plus" /> New Loyalty card
          </.button>
        </:actions>
      </.header>

      <.table
        id="loyalty_cards"
        rows={@streams.loyalty_cards}
        row_click={
          fn {_id, loyalty_card} ->
            JS.navigate(
              ~p"/establishments/#{@current_scope.establishment.id}/loyalty_cards/#{loyalty_card}"
            )
          end
        }
      >
        <:col :let={{_id, loyalty_card}} label="Stamps current">{loyalty_card.stamps_current}</:col>
        <:col :let={{_id, loyalty_card}} label="Stamps required">{loyalty_card.stamps_required}</:col>
        <:action :let={{_id, loyalty_card}}>
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
        </:action>
        <:action :let={{id, loyalty_card}}>
          <.link
            phx-click={JS.push("delete", value: %{id: loyalty_card.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
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
end
