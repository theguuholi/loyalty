defmodule LoyaltyWeb.EstablishmentLive.Show do
  use LoyaltyWeb, :live_view

  alias Loyalty.Establishments

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Establishment {@establishment.id}
        <:subtitle>This is a establishment record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/establishments"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button
            variant="primary"
            navigate={~p"/establishments/#{@establishment}/edit?return_to=show"}
          >
            <.icon name="hero-pencil-square" /> Edit establishment
          </.button>

          <.button
            variant="primary"
            navigate={~p"/establishments/#{@establishment}/loyalty_programs"}
          >
            <.icon name="hero-plus" /> New Loyalty Program
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@establishment.name}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Establishments.subscribe_establishments(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Show Establishment")
     |> assign(
       :establishment,
       Establishments.get_establishment!(socket.assigns.current_scope, id)
     )}
  end

  @impl true
  def handle_info(
        {:updated, %Loyalty.Establishments.Establishment{id: id} = establishment},
        %{assigns: %{establishment: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :establishment, establishment)}
  end

  def handle_info(
        {:deleted, %Loyalty.Establishments.Establishment{id: id}},
        %{assigns: %{establishment: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "The current establishment was deleted.")
     |> push_navigate(to: ~p"/establishments")}
  end

  def handle_info({type, %Loyalty.Establishments.Establishment{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end
