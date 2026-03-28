defmodule LoyaltyWeb.AdminLive do
  use LoyaltyWeb, :live_view

  alias Loyalty.Establishments

  @valid_filters ~w(all active unpaid)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, gettext("Admin"))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filter =
      case params["filter"] do
        f when f in @valid_filters -> String.to_existing_atom(f)
        _ -> :all
      end

    rows = Establishments.list_all_establishments_with_owner_emails(filter)

    {:noreply, socket |> assign(:filter, filter) |> assign(:rows, rows)}
  end

  defp status_badge(assigns) do
    {label, classes} =
      case assigns.status do
        "active" -> {gettext("Active"), "text-green-700 bg-green-50 ring-green-600/20"}
        "past_due" -> {gettext("Past due"), "text-yellow-700 bg-yellow-50 ring-yellow-600/20"}
        "unpaid" -> {gettext("Unpaid"), "text-red-700 bg-red-50 ring-red-600/20"}
        "canceled" -> {gettext("Canceled"), "text-zinc-600 bg-zinc-50 ring-zinc-500/20"}
        _ -> {gettext("Free"), "text-zinc-500 bg-zinc-50 ring-zinc-500/20"}
      end

    assigns = assign(assigns, label: label, classes: classes)

    ~H"""
    <span class={[
      "inline-flex items-center rounded-md px-2 py-1 text-xs font-medium ring-1 ring-inset",
      @classes
    ]}>
      {@label}
    </span>
    """
  end
end
