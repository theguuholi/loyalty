defmodule LoyaltyWeb.LoyaltyCardLive.Form do
  use LoyaltyWeb, :live_view

  alias Loyalty.{Customers, LoyaltyCards, LoyaltyCards.LoyaltyCard, LoyaltyPrograms}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage loyalty_card records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="loyalty_card-form" phx-change="validate" phx-submit="save">
        <%= if @live_action == :new do %>
          <.input field={@form[:email]} type="email" label="Customer email" required />
        <% end %>
        <.input field={@form[:stamps_current]} type="number" label="Stamps current" />
        <.input field={@form[:stamps_required]} type="number" label="Stamps required" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Loyalty card</.button>
          <.button navigate={return_path(@current_scope, @return_to, @loyalty_card)}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    loyalty_card = LoyaltyCards.get_loyalty_card!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Loyalty card")
    |> assign(:loyalty_card, loyalty_card)
    |> assign(
      :form,
      to_form(LoyaltyCards.change_loyalty_card(socket.assigns.current_scope, loyalty_card))
    )
  end

  defp apply_action(socket, :new, _params) do
    loyalty_card = %LoyaltyCard{establishment_id: socket.assigns.current_scope.establishment.id}
    attrs = %{"email" => "", "stamps_current" => "0", "stamps_required" => "10"}

    socket
    |> assign(:page_title, "New Loyalty card")
    |> assign(:loyalty_card, loyalty_card)
    |> assign(:form, to_form(attrs, as: :loyalty_card))
  end

  @impl true
  def handle_event("validate", %{"loyalty_card" => loyalty_card_params}, socket) do
    form =
      if socket.assigns.live_action == :new do
        to_form(loyalty_card_params, as: :loyalty_card, action: :validate)
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

  def handle_event("save", %{"loyalty_card" => loyalty_card_params}, socket) do
    save_loyalty_card(socket, socket.assigns.live_action, loyalty_card_params)
  end

  defp save_loyalty_card(socket, :edit, loyalty_card_params) do
    case LoyaltyCards.update_loyalty_card(
           socket.assigns.current_scope,
           socket.assigns.loyalty_card,
           loyalty_card_params
         ) do
      {:ok, loyalty_card} ->
        {:noreply,
         socket
         |> put_flash(:info, "Loyalty card updated successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, loyalty_card)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_loyalty_card(socket, :new, loyalty_card_params) do
    case prepare_new_card_attrs(socket, loyalty_card_params) do
      {:ok, attrs} ->
        case LoyaltyCards.create_loyalty_card(socket.assigns.current_scope, attrs) do
          {:ok, loyalty_card} ->
            {:noreply,
             socket
             |> put_flash(:info, "Loyalty card created successfully")
             |> push_navigate(
               to:
                 return_path(socket.assigns.current_scope, socket.assigns.return_to, loyalty_card)
             )}

          {:error, %Ecto.Changeset{}} ->
            {:noreply, assign(socket, form: to_form(loyalty_card_params, as: :loyalty_card))}
        end

      {:error, :email_required} ->
        {:noreply,
         socket
         |> put_flash(:error, "Customer email is required.")
         |> assign(:form, to_form(loyalty_card_params, as: :loyalty_card))}
    end
  end

  defp prepare_new_card_attrs(socket, params) when is_map(params) do
    scope = socket.assigns.current_scope
    email = (params["email"] || params[:email] || "") |> String.trim()

    if email == "" do
      {:error, :email_required}
    else
      {:ok, customer} = Customers.get_or_create_customer_by_email(email)
      program = program_for_scope(scope)

      attrs = %{
        "customer_id" => customer.id,
        "loyalty_program_id" => program.id,
        "stamps_current" => params["stamps_current"] || params[:stamps_current] || 0,
        "stamps_required" => params["stamps_required"] || params[:stamps_required] || 10
      }

      {:ok, attrs}
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

  defp return_path(scope, "index", _loyalty_card),
    do: ~p"/establishments/#{scope.establishment.id}/loyalty_cards"

  defp return_path(scope, "show", loyalty_card),
    do: ~p"/establishments/#{scope.establishment.id}/loyalty_cards/#{loyalty_card}"
end
