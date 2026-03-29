defmodule LoyaltyWeb.EstablishmentLive.Index do
  use LoyaltyWeb, :live_view

  alias Loyalty.Establishments

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Establishments.subscribe_establishments(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, gettext("Listing Establishments"))
     |> assign(:can_create_establishment, list_establishments(socket.assigns.current_scope) == [])
     |> stream(:establishments, list_establishments(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    establishment = Establishments.get_establishment!(socket.assigns.current_scope, id)
    {:ok, _} = Establishments.delete_establishment(socket.assigns.current_scope, establishment)

    {:noreply, stream_delete(socket, :establishments, establishment)}
  end

  @impl true
  def handle_info({type, %Loyalty.Establishments.Establishment{}}, socket)
      when type in [:created, :updated, :deleted] do
    establishments = list_establishments(socket.assigns.current_scope)

    {:noreply,
     socket
     |> assign(:can_create_establishment, establishments == [])
     |> stream(:establishments, establishments, reset: true)}
  end

  defp list_establishments(current_scope) do
    Establishments.list_establishments(current_scope)
  end
end
