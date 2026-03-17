defmodule LoyaltyWeb.EstablishmentLive.Index do
  use LoyaltyWeb, :live_view

  alias Loyalty.Establishments

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Listing Establishments
        <:actions>
          <.button variant="primary" navigate={~p"/establishments/new"}>
            <.icon name="hero-plus" /> New Establishment
          </.button>
        </:actions>
      </.header>

      <.table
        id="establishments"
        rows={@streams.establishments}
        row_click={fn {_id, establishment} -> JS.navigate(~p"/establishments/#{establishment}") end}
      >
        <:col :let={{_id, establishment}} label="Name">{establishment.name}</:col>
        <:action :let={{_id, establishment}}>
          <div class="sr-only">
            <.link navigate={~p"/establishments/#{establishment}"}>Show</.link>
          </div>
          <.link navigate={~p"/establishments/#{establishment}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, establishment}}>
          <.link
            phx-click={JS.push("delete", value: %{id: establishment.id}) |> hide("##{id}")}
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
      Establishments.subscribe_establishments(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Listing Establishments")
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
    {:noreply,
     stream(socket, :establishments, list_establishments(socket.assigns.current_scope),
       reset: true
     )}
  end

  defp list_establishments(current_scope) do
    Establishments.list_establishments(current_scope)
  end
end
