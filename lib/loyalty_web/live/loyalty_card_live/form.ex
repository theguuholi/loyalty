defmodule LoyaltyWeb.LoyaltyCardLive.Form do
  use LoyaltyWeb, :live_view

  alias Loyalty.{
    Customers,
    Establishments,
    LoyaltyCards,
    LoyaltyCards.LoyaltyCard,
    LoyaltyPrograms
  }

  @impl true
  def mount(params, _session, socket) do
    {:ok, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope

    loyalty_card =
      scope
      |> LoyaltyCards.get_loyalty_card!(id)
      |> Loyalty.Repo.preload(:customer)

    customer = loyalty_card.customer

    client_label =
      cond do
        is_binary(customer.email) -> customer.email
        is_binary(customer.whatsapp_number) -> customer.whatsapp_number
        true -> "—"
      end

    socket
    |> assign(:page_title, gettext("Edit card"))
    |> assign(:form_subtitle, gettext("Update this client's stamp progress."))
    |> assign(:client_label, client_label)
    |> assign(:loyalty_card, loyalty_card)
    |> assign(
      :form,
      to_form(LoyaltyCards.change_loyalty_card(socket.assigns.current_scope, loyalty_card))
    )
  end

  defp apply_action(socket, :new, _params) do
    scope = socket.assigns.current_scope
    establishment = Establishments.get_establishment!(scope, scope.establishment.id)

    if Establishments.check_new_loyalty_card_allowed(establishment) != :ok do
      socket
      |> put_flash(
        :error,
        gettext(
          "You cannot register new clients right now (plan limit or billing). Open your establishment dashboard to subscribe."
        )
      )
      |> push_navigate(to: ~p"/establishments/#{establishment.id}/loyalty_cards")
    else
      loyalty_card = %LoyaltyCard{establishment_id: scope.establishment.id}

      socket
      |> assign(:page_title, gettext("Register client"))
      |> assign(:form_subtitle, gettext("Register a new client to start their loyalty card."))
      |> assign(:client_label, nil)
      |> assign(:loyalty_card, loyalty_card)
      |> assign(:form, to_form(new_card_input_changeset(%{}), as: :loyalty_card))
    end
  end

  @impl true
  def handle_event("validate", %{"loyalty_card" => loyalty_card_params}, socket) do
    form =
      if socket.assigns.live_action == :new do
        changeset =
          new_card_input_changeset(loyalty_card_params) |> Map.put(:action, :validate)

        to_form(changeset, as: :loyalty_card)
      else
        changeset =
          LoyaltyCards.change_loyalty_card(
            socket.assigns.current_scope,
            socket.assigns.loyalty_card,
            loyalty_card_params
          )

        to_form(changeset, action: :validate)
      end

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("save", %{"loyalty_card" => loyalty_card_params}, socket) do
    save_loyalty_card(socket, socket.assigns.live_action, loyalty_card_params)
  end

  defp save_loyalty_card(socket, :edit, loyalty_card_params) do
    case LoyaltyCards.update_loyalty_card(
           socket.assigns.current_scope,
           socket.assigns.loyalty_card,
           loyalty_card_params
         ) do
      {:ok, _loyalty_card} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Loyalty card updated successfully"))
         |> push_navigate(
           to: ~p"/establishments/#{socket.assigns.current_scope.establishment.id}/loyalty_cards"
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_loyalty_card(socket, :new, loyalty_card_params) do
    changeset =
      new_card_input_changeset(loyalty_card_params) |> Map.put(:action, :validate)

    if changeset.valid? do
      case prepare_new_card_attrs(socket, loyalty_card_params) do
        {:ok, attrs} ->
          case LoyaltyCards.create_loyalty_card(socket.assigns.current_scope, attrs) do
            {:ok, _loyalty_card} ->
              {:noreply,
               socket
               |> put_flash(:info, gettext("Loyalty card created successfully"))
               |> push_navigate(
                 to:
                   ~p"/establishments/#{socket.assigns.current_scope.establishment.id}/loyalty_cards"
               )}

            {:error, :client_limit_reached} ->
              {:noreply,
               put_flash(
                 socket,
                 :error,
                 gettext(
                   "Client limit reached for your plan. Subscribe on the establishment page to add more clients."
                 )
               )}

            {:error, :subscription_inactive} ->
              {:noreply,
               put_flash(
                 socket,
                 :error,
                 gettext(
                   "Billing is not active. Fix your subscription on the establishment page before adding clients."
                 )
               )}

            {:error, %Ecto.Changeset{} = inner_changeset} ->
              {:noreply, assign(socket, form: to_form(inner_changeset, as: :loyalty_card))}
          end

        {:error, :contact_required} ->
          error_changeset =
            new_card_input_changeset(loyalty_card_params)
            |> Ecto.Changeset.add_error(:email, gettext("Email or WhatsApp number is required."))
            |> Map.put(:action, :validate)

          {:noreply, assign(socket, form: to_form(error_changeset, as: :loyalty_card))}

        {:error, %Ecto.Changeset{} = inner_changeset} ->
          {:noreply, assign(socket, form: to_form(inner_changeset, as: :loyalty_card))}
      end
    else
      {:noreply, assign(socket, form: to_form(changeset, as: :loyalty_card))}
    end
  end

  defp prepare_new_card_attrs(socket, params) when is_map(params) do
    email = params["email"] || ""
    whatsapp = params["whatsapp_number"] || ""

    with {:ok, customer} <- Customers.get_or_create_customer_by_contact(email, whatsapp) do
      program = program_for_scope(socket.assigns.current_scope)

      {:ok,
       %{
         "customer_id" => customer.id,
         "loyalty_program_id" => program.id,
         "stamps_current" => params["stamps_current"] || params[:stamps_current] || 0,
         "stamps_required" => params["stamps_required"] || params[:stamps_required] || 10
       }}
    end
  end

  defp new_card_input_changeset(params) do
    {%{}, %{email: :string, whatsapp_number: :string, stamps_current: :integer, stamps_required: :integer}}
    |> Ecto.Changeset.cast(params, [:email, :whatsapp_number, :stamps_current, :stamps_required])
    |> validate_contact_present()
  end

  defp validate_contact_present(changeset) do
    email = Ecto.Changeset.get_field(changeset, :email)
    whatsapp = Ecto.Changeset.get_field(changeset, :whatsapp_number)

    if (is_nil(email) or String.trim(email) == "") and
         (is_nil(whatsapp) or String.trim(whatsapp) == "") do
      Ecto.Changeset.add_error(changeset, :email, gettext("Email or WhatsApp number is required."))
    else
      changeset
    end
  end

  defp program_for_scope(scope) do
    case LoyaltyPrograms.list_loyalty_programs(scope) do
      [program | _] ->
        program

      [] ->
        {:ok, program} =
          LoyaltyPrograms.create_loyalty_program(scope, %{
            name: "Default program",
            stamps_required: 10,
            reward_description: "Reward"
          })

        program
    end
  end
end
