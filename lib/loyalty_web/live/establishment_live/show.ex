defmodule LoyaltyWeb.EstablishmentLive.Show do
  use LoyaltyWeb, :live_view

  alias Loyalty.{Accounts.Scope, Establishments, LoyaltyPrograms}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@establishment.name}
        <:subtitle>
          <%= if @loyalty_program do %>
            Assinatura ativa
          <% else %>
            Crie um programa de fidelidade
          <% end %>
        </:subtitle>
        <:actions>
          <.link
            id="dashboard-logout-link"
            href={~p"/users/log-out"}
            method="delete"
            class="text-sm font-medium"
          >
            Sair
          </.link>
          <.button navigate={~p"/establishments"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button
            variant="primary"
            navigate={~p"/establishments/#{@establishment}/edit?return_to=show"}
          >
            <.icon name="hero-pencil-square" /> Editar estabelecimento
          </.button>
        </:actions>
      </.header>

      <div
        id="dashboard-program-card"
        class="rounded-xl border-2 border-[#e2e5e8] bg-white p-4 shadow-sm mb-4"
      >
        <%= if @loyalty_program do %>
          <p class="font-semibold text-[#1a1d21]">Programa ativo</p>
          <p class="text-sm text-[#6b7280] mt-1">
            {@loyalty_program.stamps_required} carimbos = {@loyalty_program.reward_description}
          </p>
          <.link
            id="dashboard-edit-program-link"
            navigate={
              ~p"/establishments/#{@establishment}/loyalty_programs/#{@loyalty_program}/edit?return_to=show"
            }
            class="text-sm text-[#1b4d3e] hover:underline mt-2 inline-block"
          >
            Editar programa →
          </.link>
        <% else %>
          <p class="text-[#6b7280]">Nenhum programa ainda.</p>
          <.link
            navigate={~p"/establishments/#{@establishment}/loyalty_programs/new"}
            class="text-sm text-[#1b4d3e] hover:underline mt-2 inline-block"
          >
            Criar programa →
          </.link>
        <% end %>
      </div>

      <p class="text-sm font-semibold text-[#1a1d21] mb-2">Ações rápidas</p>
      <div class="flex flex-wrap gap-2">
        <.link
          id="dashboard-cards-link"
          navigate={~p"/establishments/#{@establishment}/loyalty_cards"}
          class="btn btn-primary btn-soft"
        >
          Ver cartões / Clientes
        </.link>
        <.link
          id="dashboard-add-stamp-link"
          navigate={~p"/establishments/#{@establishment}/loyalty_cards"}
          class="btn btn-primary btn-soft"
        >
          Adicionar carimbo
        </.link>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Establishments.subscribe_establishments(socket.assigns.current_scope)
    end

    establishment = Establishments.get_establishment!(socket.assigns.current_scope, id)
    scope = Scope.put_establishment(socket.assigns.current_scope, establishment)

    loyalty_program =
      case LoyaltyPrograms.list_loyalty_programs(scope) do
        [p | _] -> p
        [] -> nil
      end

    {:ok,
     socket
     |> assign(:page_title, establishment.name)
     |> assign(:establishment, establishment)
     |> assign(:loyalty_program, loyalty_program)}
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
