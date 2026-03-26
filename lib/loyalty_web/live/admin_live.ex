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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} locale={@locale}>
      <.header>
        {gettext("Admin Dashboard")}
        <:subtitle>{gettext("All registered establishments")}</:subtitle>
      </.header>

      <div class="flex gap-2 my-4">
        <.link
          patch={~p"/admin"}
          class={[
            "px-3 py-1 rounded-md text-sm font-medium border transition-colors",
            if(@filter == :all,
              do: "bg-zinc-900 text-white border-zinc-900",
              else: "border-zinc-300 text-zinc-600 hover:border-zinc-500"
            )
          ]}
        >
          {gettext("All")}
        </.link>
        <.link
          patch={~p"/admin?filter=active"}
          class={[
            "px-3 py-1 rounded-md text-sm font-medium border transition-colors",
            if(@filter == :active,
              do: "bg-green-600 text-white border-green-600",
              else: "border-zinc-300 text-zinc-600 hover:border-zinc-500"
            )
          ]}
        >
          {gettext("Active")}
        </.link>
        <.link
          patch={~p"/admin?filter=unpaid"}
          class={[
            "px-3 py-1 rounded-md text-sm font-medium border transition-colors",
            if(@filter == :unpaid,
              do: "bg-red-600 text-white border-red-600",
              else: "border-zinc-300 text-zinc-600 hover:border-zinc-500"
            )
          ]}
        >
          {gettext("Unpaid / Free")}
        </.link>
      </div>

      <.table id="admin-table" rows={@rows}>
        <:col :let={row} label={gettext("Email")}>{row.user_email}</:col>
        <:col :let={row} label={gettext("Establishment")}>{row.name}</:col>
        <:col :let={row} label={gettext("Plan")}>
          <.status_badge status={row.subscription_status} />
        </:col>
        <:col :let={row} label={gettext("Cards")}>{row.card_count}</:col>
        <:col :let={row} label={gettext("Registered")}>
          {Calendar.strftime(row.inserted_at, "%d/%m/%Y")}
        </:col>
      </.table>

      <p :if={@rows == []} class="text-center mt-8 text-zinc-500">
        {gettext("No establishments found.")}
      </p>
    </Layouts.app>
    """
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
