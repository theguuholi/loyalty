defmodule LoyaltyWeb.LoyaltyProgramLive.Index do
  use LoyaltyWeb, :live_view

  alias Loyalty.LoyaltyPrograms

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} locale={@locale}>
      <.header>
        {gettext("Loyalty programs")}
        <:subtitle>{@current_scope.establishment.name}</:subtitle>
        <:actions>
          <.button navigate={~p"/establishments/#{@current_scope.establishment.id}"}>
            <.icon name="hero-arrow-left" /> {gettext("Back")}
          </.button>
          <.button
            variant="primary"
            navigate={~p"/establishments/#{@current_scope.establishment.id}/loyalty_programs/new"}
          >
            <.icon name="hero-plus" /> {gettext("New program")}
          </.button>
        </:actions>
      </.header>

      <.table
        id="loyalty_programs"
        rows={@streams.loyalty_programs}
        row_click={
          fn {_id, loyalty_program} ->
            JS.navigate(
              ~p"/establishments/#{@current_scope.establishment.id}/loyalty_programs/#{loyalty_program}"
            )
          end
        }
      >
        <:col :let={{_id, loyalty_program}} label={gettext("Name")}>{loyalty_program.name}</:col>
        <:col :let={{_id, loyalty_program}} label={gettext("Stamps required")}>
          {loyalty_program.stamps_required}
        </:col>
        <:col :let={{_id, loyalty_program}} label={gettext("Reward description")}>
          {loyalty_program.reward_description}
        </:col>
        <:action :let={{_id, loyalty_program}}>
          <.link
            navigate={
              ~p"/establishments/#{@current_scope.establishment.id}/loyalty_programs/#{loyalty_program}/edit"
            }
            class="btn btn-ghost btn-sm"
          >
            {gettext("Edit")}
          </.link>
        </:action>
        <:action :let={{id, loyalty_program}}>
          <.link
            phx-click={JS.push("delete", value: %{id: loyalty_program.id}) |> hide("##{id}")}
            data-confirm={gettext("Are you sure?")}
            class="btn btn-ghost btn-sm text-error"
          >
            {gettext("Delete")}
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      LoyaltyPrograms.subscribe_loyalty_programs(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, gettext("Loyalty programs"))
     |> stream(:loyalty_programs, list_loyalty_programs(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    loyalty_program = LoyaltyPrograms.get_loyalty_program!(socket.assigns.current_scope, id)

    {:ok, _} =
      LoyaltyPrograms.delete_loyalty_program(socket.assigns.current_scope, loyalty_program)

    {:noreply, stream_delete(socket, :loyalty_programs, loyalty_program)}
  end

  @impl true
  def handle_info({type, %Loyalty.LoyaltyPrograms.LoyaltyProgram{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply,
     stream(socket, :loyalty_programs, list_loyalty_programs(socket.assigns.current_scope),
       reset: true
     )}
  end

  defp list_loyalty_programs(current_scope) do
    LoyaltyPrograms.list_loyalty_programs(current_scope)
  end
end
