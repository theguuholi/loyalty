defmodule LoyaltyWeb.EstablishmentLive.Form do
  use LoyaltyWeb, :live_view

  alias Loyalty.Establishments
  alias Loyalty.Establishments.Establishment

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} locale={@locale}>
      <.header>
        {@page_title}
        <:subtitle>{gettext("Manage establishment name.")}</:subtitle>
        <:actions>
          <.button navigate={return_path(@current_scope, @return_to, @establishment)}>
            <.icon name="hero-arrow-left" /> {gettext("Back")}
          </.button>
        </:actions>
      </.header>

      <.form for={@form} id="establishment-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label={gettext("Name")} />
        <footer class="flex flex-wrap gap-3 pt-4">
          <.button phx-disable-with={gettext("Saving...")} variant="primary">
            {gettext("Save")}
          </.button>
          <.link
            navigate={return_path(@current_scope, @return_to, @establishment)}
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
    establishment = Establishments.get_establishment!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, gettext("Edit establishment"))
    |> assign(:establishment, establishment)
    |> assign(
      :form,
      to_form(Establishments.change_establishment(socket.assigns.current_scope, establishment))
    )
  end

  defp apply_action(socket, :new, _params) do
    establishment = %Establishment{user_id: socket.assigns.current_scope.user.id}

    socket
    |> assign(:page_title, gettext("New establishment"))
    |> assign(:establishment, establishment)
    |> assign(
      :form,
      to_form(Establishments.change_establishment(socket.assigns.current_scope, establishment))
    )
  end

  @impl true
  def handle_event("validate", %{"establishment" => establishment_params}, socket) do
    changeset =
      Establishments.change_establishment(
        socket.assigns.current_scope,
        socket.assigns.establishment,
        establishment_params
      )

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"establishment" => establishment_params}, socket) do
    save_establishment(socket, socket.assigns.live_action, establishment_params)
  end

  defp save_establishment(socket, :edit, establishment_params) do
    case Establishments.update_establishment(
           socket.assigns.current_scope,
           socket.assigns.establishment,
           establishment_params
         ) do
      {:ok, establishment} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Establishment updated successfully."))
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, establishment)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_establishment(socket, :new, establishment_params) do
    case Establishments.create_establishment(socket.assigns.current_scope, establishment_params) do
      {:ok, establishment} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Establishment created successfully."))
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, establishment)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(_scope, "index", _establishment), do: ~p"/establishments"
  defp return_path(_scope, "show", establishment), do: ~p"/establishments/#{establishment}"
end
