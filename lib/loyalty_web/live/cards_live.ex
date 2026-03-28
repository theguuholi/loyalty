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
     |> assign(:form, to_form(entry_changeset(:email, %{}), as: :cards_entry))}
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
    socket
    |> assign(:identifier, nil)
    |> assign(:cards, [])
    |> assign(:show_list?, false)
    |> assign(:form, to_form(entry_changeset(contact_type, %{}), as: :cards_entry))
  end

  @impl true
  def handle_event("set_contact_type", %{"type" => type}, socket) do
    contact_type = if type == "whatsapp", do: :whatsapp, else: :email

    {:noreply,
     socket
     |> assign(:contact_type, contact_type)
     |> assign(:form, to_form(entry_changeset(contact_type, %{}), as: :cards_entry))}
  end

  @impl true
  def handle_event("lookup", params, socket) do
    entry = params["cards_entry"] || %{}
    contact_type = socket.assigns.contact_type
    changeset = entry_changeset(contact_type, entry)
    changeset = Map.put(changeset, :action, :validate)

    if changeset.valid? do
      case contact_type do
        :email ->
          email = Ecto.Changeset.get_field(changeset, :email)
          {:noreply, push_patch(socket, to: "/cards?email=" <> URI.encode_www_form(email))}

        :whatsapp ->
          number = Ecto.Changeset.get_field(changeset, :whatsapp_number)
          {:noreply, push_patch(socket, to: "/cards?whatsapp=" <> URI.encode_www_form(number))}
      end
    else
      {:noreply, assign(socket, form: to_form(changeset, as: :cards_entry))}
    end
  end

  defp entry_changeset(:email, params) do
    {%{}, %{email: :string}}
    |> Ecto.Changeset.cast(params, [:email])
    |> Ecto.Changeset.validate_required([:email], message: gettext("Please enter your email."))
    |> Ecto.Changeset.validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/,
      message: gettext("Invalid email.")
    )
  end

  defp entry_changeset(:whatsapp, params) do
    {%{}, %{whatsapp_number: :string}}
    |> Ecto.Changeset.cast(params, [:whatsapp_number])
    |> Ecto.Changeset.validate_required([:whatsapp_number],
      message: gettext("Please enter your WhatsApp number.")
    )
    |> Ecto.Changeset.validate_format(:whatsapp_number, ~r/^\+[1-9]\d{7,14}$/,
      message: gettext("Invalid number. Use the format +5511999999999.")
    )
  end
end
