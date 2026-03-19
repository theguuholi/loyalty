defmodule LoyaltyWeb.CardsLive do
  @moduledoc """
  Public "Meus cartões" flow: customer enters email and sees their loyalty cards (or empty state).
  """
  use LoyaltyWeb, :live_view

  alias Loyalty.LoyaltyCards

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Meus cartões")
     |> assign(:email, nil)
     |> assign(:cards, [])
     |> assign(:show_list?, false)
     |> assign(:form, to_form(%{"email" => ""}, as: :cards_entry))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    email = (params["email"] || "") |> String.trim()
    show_list? = email != ""

    socket =
      if show_list? do
        cards = LoyaltyCards.list_loyalty_cards_by_customer_email(email)

        socket
        |> assign(:email, email)
        |> assign(:cards, cards)
        |> assign(:show_list?, true)
      else
        socket
        |> assign(:email, nil)
        |> assign(:cards, [])
        |> assign(:show_list?, false)
        |> assign(:form, to_form(%{"email" => params["email"] || ""}, as: :cards_entry))
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} locale={@locale}>
      <div class="space-y-6">
        <h1 class="text-xl font-semibold text-[#1a1d21]">Meus cartões</h1>

        <%= if @show_list? do %>
          <.list_view email={@email} cards={@cards} />
        <% else %>
          <.entry_form form={@form} />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp entry_form(assigns) do
    ~H"""
    <div>
      <p class="text-[#6b7280] mb-4">
        Digite seu e-mail para ver todos os cartões de fidelidade.
      </p>
      <.form
        id="cards-entry-form"
        for={@form}
        phx-submit="submit_email"
        class="space-y-4"
      >
        <.input
          id="cards-entry-email"
          field={@form[:email]}
          type="email"
          label="E-mail"
          placeholder="seu@email.com"
          required
        />
        <button type="submit" id="cards-entry-submit" class="btn btn-primary w-full max-w-xs">
          Ver cartões
        </button>
      </.form>
    </div>
    """
  end

  defp list_view(assigns) do
    ~H"""
    <div>
      <p class="text-[#6b7280] mb-4">{@email}</p>
      <.link
        id="cards-change-email-link"
        patch={~p"/cards"}
        class="text-sm text-[#1b4d3e] hover:underline mb-4 inline-block"
      >
        Trocar e-mail
      </.link>

      <%= if @cards == [] do %>
        <p id="cards-empty-message" class="text-[#6b7280]">
          Nenhum cartão encontrado para este e-mail.
        </p>
      <% else %>
        <div id="cards-list" class="space-y-4">
          <div
            :for={card <- @cards}
            id={"card-item-#{card.id}"}
            class="rounded-xl border-2 border-[#e2e5e8] bg-white p-4 shadow-sm"
          >
            <p id="card-establishment" class="font-semibold text-[#1a1d21]">
              {card.establishment.name}
            </p>
            <div id="card-progress" class="mt-2 flex items-center gap-2">
              <div class="h-2 flex-1 rounded-full bg-[#eef0f2] overflow-hidden">
                <div
                  class="h-full rounded-full bg-[#1b4d3e] transition-all"
                  style={"width: #{min(100, div((card.stamps_current || 0) * 100, max(1, card.stamps_required)))}%"}
                >
                </div>
              </div>
              <span class="text-sm text-[#6b7280]">
                {card.stamps_current || 0} de {card.stamps_required} carimbos
              </span>
            </div>
            <p id="card-reward" class="mt-2 text-sm text-[#40916c]">
              {card.loyalty_program.reward_description}
              <%= if (card.stamps_current || 0) >= card.stamps_required do %>
                — pronto para usar!
              <% end %>
            </p>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("submit_email", params, socket) do
    email =
      (get_in(params, ["cards_entry", "email"]) || params["email"] || "")
      |> String.trim()

    cond do
      email == "" ->
        {:noreply,
         socket
         |> put_flash(:error, "Informe seu e-mail.")
         |> assign(:form, to_form(%{"email" => ""}, as: :cards_entry))}

      not valid_email?(email) ->
        {:noreply,
         socket
         |> put_flash(:error, "E-mail inválido.")
         |> assign(:form, to_form(%{"email" => email}, as: :cards_entry))}

      true ->
        {:noreply, push_patch(socket, to: "/cards?email=" <> URI.encode_www_form(email))}
    end
  end

  defp valid_email?(email) do
    ~r/^[^\s]+@[^\s]+\.[^\s]+$/ |> Regex.match?(email)
  end
end
