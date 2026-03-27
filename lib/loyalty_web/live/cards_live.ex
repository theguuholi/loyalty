defmodule LoyaltyWeb.CardsLive do
  @moduledoc """
  Public "Meus cartões" flow: customer enters email or WhatsApp and sees their loyalty cards.
  """
  use LoyaltyWeb, :live_view

  alias Loyalty.LoyaltyCards

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Meus cartões")
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
        {:noreply, put_flash(socket, :error, "Informe seu e-mail.")}

      not valid_email?(email) ->
        {:noreply, put_flash(socket, :error, "E-mail inválido.")}

      true ->
        {:noreply, push_patch(socket, to: "/cards?email=" <> URI.encode_www_form(email))}
    end
  end

  defp lookup_by_whatsapp(socket, entry) do
    number = (entry["whatsapp_number"] || "") |> String.trim()

    cond do
      number == "" ->
        {:noreply, put_flash(socket, :error, "Informe seu número de WhatsApp.")}

      not valid_whatsapp?(number) ->
        {:noreply, put_flash(socket, :error, "Número inválido. Use o formato +5511999999999.")}

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
