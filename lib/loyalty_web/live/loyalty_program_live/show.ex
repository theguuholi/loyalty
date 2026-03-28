defmodule LoyaltyWeb.LoyaltyProgramLive.Show do
  use LoyaltyWeb, :live_view

  alias Loyalty.{Establishments, LoyaltyPrograms}
  alias Loyalty.Establishments.Establishment

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Establishments.subscribe_establishments(socket.assigns.current_scope)
      LoyaltyPrograms.subscribe_loyalty_programs(socket.assigns.current_scope)
    end

    scope = socket.assigns.current_scope
    loyalty_program = LoyaltyPrograms.get_loyalty_program!(scope, id)
    establishment = Establishments.get_establishment!(scope, scope.establishment.id)
    billing = billing_assigns(establishment)

    {:ok,
     socket
     |> assign(:page_title, loyalty_program.name)
     |> assign(:loyalty_program, loyalty_program)
     |> assign(:can_add_new_client, billing.can_add_new_client)
     |> assign(:payment_issue_billing, billing.payment_issue)}
  end

  @impl true
  def handle_info(
        {:updated, %LoyaltyPrograms.LoyaltyProgram{id: id} = loyalty_program},
        %{assigns: %{loyalty_program: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :loyalty_program, loyalty_program)}
  end

  def handle_info(
        {:deleted, %LoyaltyPrograms.LoyaltyProgram{id: id}},
        %{assigns: %{loyalty_program: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, gettext("The current program was deleted."))
     |> push_navigate(to: ~p"/establishments/#{socket.assigns.current_scope.establishment.id}")}
  end

  def handle_info({type, %LoyaltyPrograms.LoyaltyProgram{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end

  def handle_info(
        {:updated, %Establishment{id: eid}},
        %{assigns: %{current_scope: %{establishment: %{id: eid}}}} = socket
      ) do
    scope = socket.assigns.current_scope
    establishment = Establishments.get_establishment!(scope, eid)
    billing = billing_assigns(establishment)

    {:noreply,
     socket
     |> assign(:can_add_new_client, billing.can_add_new_client)
     |> assign(:payment_issue_billing, billing.payment_issue)}
  end

  def handle_info({type, %Establishment{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end

  defp billing_assigns(%Establishment{} = establishment) do
    can_add = Establishments.check_new_loyalty_card_allowed(establishment) == :ok
    payment_issue = establishment.subscription_status in ["past_due", "unpaid"]
    %{can_add_new_client: can_add, payment_issue: payment_issue}
  end
end
