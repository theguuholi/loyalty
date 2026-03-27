defmodule LoyaltyWeb.CardsLive do
  @moduledoc """
  Public "My Cards" flow: customer enters email or WhatsApp and sees their loyalty cards.
  """
  use LoyaltyWeb, :live_view

  alias Loyalty.LoyaltyCards

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("My cards"))
     |> assign(:contact_type, :email)
     |> assign(:identifier, nil)
     |> assign(:cards, [])
     |> assign(:show_list?, false)
     |> assign(:form, to_form(%{"email" => ""}, as: :cards_entry))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    cond do
      email = params["email"] ->
        email = String.trim(email)

        if email != "" do
          cards = LoyaltyCards.list_loyalty_cards_by_customer_email(email)

          {:noreply,
           socket
           |> assign(:contact_type, :email)
           |> assign(:identifier, email)
           |> assign(:cards, cards)
           |> assign(:show_list?, true)}
        else
          {:noreply, assign_reset(socket, :email)}
        end

      whatsapp = params["whatsapp"] ->
        number = String.trim(whatsapp)

        if number != "" do
          cards = LoyaltyCards.list_loyalty_cards_by_customer_whatsapp(number)

          {:noreply,
           socket
           |> assign(:contact_type, :whatsapp)
           |> assign(:identifier, number)
           |> assign(:cards, cards)
           |> assign(:show_list?, true)}
        else
          {:noreply, assign_reset(socket, :whatsapp)}
        end

      true ->
        {:noreply, assign_reset(socket, socket.assigns.contact_type)}
    end
  end

  defp assign_reset(socket, contact_type) do
    form_key = if contact_type == :whatsapp, do: "whatsapp_number", else: "email"

    socket
    |> assign(:identifier, nil)
    |> assign(:cards, [])
    |> assign(:show_list?, false)
    |> assign(:form, to_form(%{form_key => ""}, as: :cards_entry))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} locale={@locale}>
      <div class="space-y-6">
        <h1 class="text-xl font-semibold text-[#1a1d21]">{gettext("My cards")}</h1>

        <%= if @show_list? do %>
          <.list_view identifier={@identifier} cards={@cards} contact_type={@contact_type} />
        <% else %>
          <.entry_form form={@form} contact_type={@contact_type} />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp entry_form(assigns) do
    ~H"""
    <div>
      <%!-- Contact type toggle --%>
      <div class="flex gap-2 mb-4">
        <button
          type="button"
          id="lookup-type-email"
          phx-click="set_contact_type"
          phx-value-type="email"
          class={[
            "btn btn-sm",
            if(@contact_type == :email, do: "btn-primary", else: "btn-ghost border border-base-300")
          ]}
        >
          E-mail
        </button>
        <button
          type="button"
          id="lookup-type-whatsapp"
          phx-click="set_contact_type"
          phx-value-type="whatsapp"
          class={[
            "btn btn-sm",
            if(@contact_type == :whatsapp,
              do: "btn-primary",
              else: "btn-ghost border border-base-300"
            )
          ]}
        >
          WhatsApp
        </button>
      </div>

      <p class="text-[#6b7280] mb-4">
        <%= if @contact_type == :email do %>
          {gettext("Enter your email to see all your loyalty cards.")}
        <% else %>
          {gettext("Enter your WhatsApp number to see all your loyalty cards.")}
        <% end %>
      </p>

      <.form
        id="cards-entry-form"
        for={@form}
        phx-submit="lookup"
        class="space-y-4"
      >
        <%= if @contact_type == :email do %>
          <.input
            id="cards-entry-email"
            field={@form[:email]}
            type="email"
            label="E-mail"
            placeholder="seu@email.com"
          />
        <% else %>
          <.input
            id="cards-entry-whatsapp"
            field={@form[:whatsapp_number]}
            type="tel"
            label="WhatsApp"
            placeholder="+5511999999999"
          />
        <% end %>
        <button type="submit" id="cards-entry-submit" class="btn btn-primary w-full max-w-xs">
          {gettext("View cards")}
        </button>
      </.form>
    </div>
    """
  end

  defp list_view(assigns) do
    ~H"""
    <div>
      <p class="text-[#6b7280] mb-4">{@identifier}</p>
      <.link
        id="cards-change-contact-link"
        patch={~p"/cards"}
        class="text-sm text-[#1b4d3e] hover:underline mb-4 inline-block"
      >
        {if @contact_type == :email, do: gettext("Change email"), else: gettext("Change number")}
      </.link>

      <%= if @cards == [] do %>
        <p id="cards-empty-message" class="text-[#6b7280]">
          {gettext("No cards found.")}
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
                {card.stamps_current || 0} {gettext("of")} {card.stamps_required} {gettext("stamps")}
              </span>
            </div>
            <p id="card-reward" class="mt-2 text-sm text-[#40916c]">
              {card.loyalty_program.reward_description}
              <%= if (card.stamps_current || 0) >= card.stamps_required do %>
                — {gettext("ready to use!")}
              <% end %>
            </p>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("set_contact_type", %{"type" => type}, socket) do
    contact_type = if type == "whatsapp", do: :whatsapp, else: :email
    form_key = if contact_type == :whatsapp, do: "whatsapp_number", else: "email"

    {:noreply,
     socket
     |> assign(:contact_type, contact_type)
     |> assign(:form, to_form(%{form_key => ""}, as: :cards_entry))}
  end

  def handle_event("lookup", params, socket) do
    entry = params["cards_entry"] || %{}

    case socket.assigns.contact_type do
      :email -> lookup_by_email(socket, entry)
      :whatsapp -> lookup_by_whatsapp(socket, entry)
    end
  end

  defp assign_reset(socket, contact_type) do
    form_key = if contact_type == :whatsapp, do: "whatsapp_number", else: "email"

    socket
    |> assign(:identifier, nil)
    |> assign(:cards, [])
    |> assign(:show_list?, false)
    |> assign(:form, to_form(%{form_key => ""}, as: :cards_entry))
  end

  defp lookup_by_email(socket, entry) do
    email = (entry["email"] || "") |> String.trim()

    cond do
      email == "" ->
        {:noreply, put_flash(socket, :error, gettext("Please enter your email."))}

      not valid_email?(email) ->
        {:noreply, put_flash(socket, :error, gettext("Invalid email."))}

      true ->
        {:noreply, push_patch(socket, to: "/cards?email=" <> URI.encode_www_form(email))}
    end
  end

  defp lookup_by_whatsapp(socket, entry) do
    number = (entry["whatsapp_number"] || "") |> String.trim()

    cond do
      number == "" ->
        {:noreply, put_flash(socket, :error, gettext("Please enter your WhatsApp number."))}

      not valid_whatsapp?(number) ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Invalid number. Use the format +5511999999999.")
         )}

      true ->
        {:noreply, push_patch(socket, to: "/cards?whatsapp=" <> URI.encode_www_form(number))}
    end
  end

  defp valid_email?(email) do
    Regex.match?(~r/^[^\s]+@[^\s]+\.[^\s]+$/, email)
  end

  defp valid_whatsapp?(number) do
    Regex.match?(~r/^\+[1-9]\d{7,14}$/, number)
  end
end
