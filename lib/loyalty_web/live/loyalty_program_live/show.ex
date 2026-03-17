defmodule LoyaltyWeb.LoyaltyProgramLive.Show do
  use LoyaltyWeb, :live_view

  alias Loyalty.LoyaltyPrograms

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Loyalty program {@loyalty_program.id}
        <:subtitle>This is a loyalty_program record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/establishments/#{@current_scope.establishment.id}/loyalty_programs"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button
            variant="primary"
            navigate={
              ~p"/establishments/#{@current_scope.establishment.id}/loyalty_programs/#{@loyalty_program}/edit?return_to=show"
            }
          >
            <.icon name="hero-pencil-square" /> Edit loyalty_program
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@loyalty_program.name}</:item>
        <:item title="Stamps required">{@loyalty_program.stamps_required}</:item>
        <:item title="Reward description">{@loyalty_program.reward_description}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      LoyaltyPrograms.subscribe_loyalty_programs(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Show Loyalty program")
     |> assign(
       :loyalty_program,
       LoyaltyPrograms.get_loyalty_program!(socket.assigns.current_scope, id)
     )}
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
     |> put_flash(:error, "The current loyalty_program was deleted.")
     |> push_navigate(
       to: ~p"/establishments/#{socket.assigns.current_scope.establishment.id}/loyalty_programs"
     )}
  end

  def handle_info({type, %Loyalty.LoyaltyPrograms.LoyaltyProgram{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end
