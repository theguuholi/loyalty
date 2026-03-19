defmodule LoyaltyWeb.LoyaltyProgramLive.Form do
  use LoyaltyWeb, :live_view

  alias Loyalty.LoyaltyPrograms
  alias Loyalty.LoyaltyPrograms.LoyaltyProgram

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} locale={@locale}>
      <.header>
        {@page_title}
        <:subtitle>{gettext("Manage program name, stamps required and reward.")}</:subtitle>
        <:actions>
          <.button navigate={return_path(@current_scope, @return_to, @loyalty_program)}>
            <.icon name="hero-arrow-left" /> {gettext("Back")}
          </.button>
        </:actions>
      </.header>

      <.form for={@form} id="loyalty_program-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label={gettext("Name")} />
        <.input field={@form[:stamps_required]} type="number" label={gettext("Stamps required")} />
        <.input field={@form[:reward_description]} type="text" label={gettext("Reward description")} />
        <footer class="flex flex-wrap gap-3 pt-4">
          <.button phx-disable-with={gettext("Saving...")} variant="primary">
            {gettext("Save")}
          </.button>
          <.link
            navigate={return_path(@current_scope, @return_to, @loyalty_program)}
            class="btn btn-primary btn-soft"
          >
            {gettext("Back to list")}
          </.link>
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
    loyalty_program = LoyaltyPrograms.get_loyalty_program!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, gettext("Edit program"))
    |> assign(:loyalty_program, loyalty_program)
    |> assign(
      :form,
      to_form(
        LoyaltyPrograms.change_loyalty_program(socket.assigns.current_scope, loyalty_program)
      )
    )
  end

  defp apply_action(socket, :new, _params) do
    loyalty_program = %LoyaltyProgram{
      establishment_id: socket.assigns.current_scope.establishment.id
    }

    socket
    |> assign(:page_title, gettext("New program"))
    |> assign(:loyalty_program, loyalty_program)
    |> assign(
      :form,
      to_form(
        LoyaltyPrograms.change_loyalty_program(socket.assigns.current_scope, loyalty_program)
      )
    )
  end

  @impl true
  def handle_event("validate", %{"loyalty_program" => loyalty_program_params}, socket) do
    changeset =
      LoyaltyPrograms.change_loyalty_program(
        socket.assigns.current_scope,
        socket.assigns.loyalty_program,
        loyalty_program_params
      )

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"loyalty_program" => loyalty_program_params}, socket) do
    save_loyalty_program(socket, socket.assigns.live_action, loyalty_program_params)
  end

  defp save_loyalty_program(socket, :edit, loyalty_program_params) do
    case LoyaltyPrograms.update_loyalty_program(
           socket.assigns.current_scope,
           socket.assigns.loyalty_program,
           loyalty_program_params
         ) do
      {:ok, loyalty_program} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Program updated successfully."))
         |> push_navigate(
           to:
             return_path(socket.assigns.current_scope, socket.assigns.return_to, loyalty_program)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_loyalty_program(socket, :new, loyalty_program_params) do
    case LoyaltyPrograms.create_loyalty_program(
           socket.assigns.current_scope,
           loyalty_program_params
         ) do
      {:ok, loyalty_program} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Program created successfully."))
         |> push_navigate(
           to:
             return_path(socket.assigns.current_scope, socket.assigns.return_to, loyalty_program)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(scope, "index", _loyalty_program),
    do: ~p"/establishments/#{scope.establishment.id}/loyalty_programs"

  defp return_path(scope, "show", loyalty_program),
    do: ~p"/establishments/#{scope.establishment.id}/loyalty_programs/#{loyalty_program}"
end
