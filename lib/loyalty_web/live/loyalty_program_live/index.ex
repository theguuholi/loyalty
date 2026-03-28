defmodule LoyaltyWeb.LoyaltyProgramLive.Index do
  use LoyaltyWeb, :live_view

  alias Loyalty.LoyaltyPrograms

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
