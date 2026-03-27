defmodule LoyaltyWeb.EstablishmentLive.Form do
  use LoyaltyWeb, :live_view

  alias Loyalty.Establishments
  alias Loyalty.Establishments.Establishment

  @impl true
  def mount(params, _session, socket) do
    socket = assign(socket, :return_to, return_to(params["return_to"]))

    socket =
      if socket.assigns.live_action == :new and
           Establishments.list_establishments(socket.assigns.current_scope) != [] do
        socket
        |> put_flash(:error, gettext("You already have an establishment."))
        |> push_navigate(to: ~p"/establishments")
      else
        socket
        |> apply_action(socket.assigns.live_action, params)
        |> allow_upload(:logo,
          accept: ~w(image/png image/jpeg image/gif image/webp),
          max_entries: 1,
          max_file_size: 5_000_000
        )
      end

    {:ok, socket}
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

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :logo, ref)}
  end

  def handle_event("save", %{"establishment" => establishment_params}, socket) do
    logo_url = consume_uploaded_logo(socket)

    params =
      Map.put(
        establishment_params,
        "logo_url",
        logo_url || socket.assigns.establishment.logo_url
      )

    save_establishment(socket, socket.assigns.live_action, params)
  end

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

      {:error, :establishment_limit_reached} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("You can only have one establishment. Contact support to change your plan.")
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp consume_uploaded_logo(socket) do
    uploads_dir = Path.join([:code.priv_dir(:loyalty), "static", "uploads", "logos"])
    File.mkdir_p!(uploads_dir)

    case consume_uploaded_entries(socket, :logo, fn %{path: tmp_path}, entry ->
           filename = "#{System.unique_integer([:positive])}-#{entry.client_name}"
           dest = Path.join(uploads_dir, filename)
           File.cp!(tmp_path, dest)
           {:ok, "/uploads/logos/#{filename}"}
         end) do
      [url] -> url
      [] -> nil
    end
  end

  defp upload_error_to_string(:too_large), do: gettext("File too large (max 5MB)")
  defp upload_error_to_string(:not_accepted), do: gettext("File type not allowed")
  defp upload_error_to_string(:too_many_files), do: gettext("Only one image allowed")
  defp upload_error_to_string(_), do: gettext("Upload error")

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp return_path(_scope, "index", _establishment), do: ~p"/establishments"
  defp return_path(_scope, "show", establishment), do: ~p"/establishments/#{establishment}"
end
