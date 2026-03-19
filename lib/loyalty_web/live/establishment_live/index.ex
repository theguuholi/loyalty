defmodule LoyaltyWeb.EstablishmentLive.Index do
  use LoyaltyWeb, :live_view

  alias Loyalty.Establishments

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} locale={@locale}>
      <.header>
        Listing Establishments
        <:actions>
          <%= if @can_create_establishment do %>
            <.button variant="primary" navigate={~p"/establishments/new"}>
              <.icon name="hero-plus" /> New Establishment
            </.button>
          <% else %>
            <span class="rounded-full border border-base-300 bg-base-100 px-3 py-2 text-sm text-base-content/70">
              Only one establishment allowed
            </span>
          <% end %>
        </:actions>
      </.header>

      <.table
        id="establishments"
        rows={@streams.establishments}
        row_click={fn {_id, establishment} -> JS.navigate(~p"/establishments/#{establishment}") end}
      >
        <:col :let={{_id, establishment}} label="Name">{establishment.name}</:col>
        <:action :let={{id, establishment}}>
          <div class="sr-only">
            <.link navigate={~p"/establishments/#{establishment}"}>Show</.link>
          </div>
          <.link navigate={~p"/establishments/#{establishment}/edit"}>Edit</.link>
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
