defmodule LoyaltyWeb.EstablishmentLive.Show do
  use LoyaltyWeb, :live_view

  alias Loyalty.{Accounts.Scope, Billing, Establishments, LoyaltyPrograms}
  alias Loyalty.Billing.Stripe
  alias Loyalty.Establishments.Establishment

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Establishments.subscribe_establishments(socket.assigns.current_scope)
    end

    establishment = Establishments.get_establishment!(socket.assigns.current_scope, id)
    scope = Scope.put_establishment(socket.assigns.current_scope, establishment)

    loyalty_program =
      case LoyaltyPrograms.list_loyalty_programs(scope) do
        [p | _] -> p
        [] -> nil
      end

    socket =
      socket
      |> assign(:page_title, establishment.name)
      |> assign(:establishment, establishment)
      |> assign(:loyalty_program, loyalty_program)
      |> assign_billing(establishment)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      case params["checkout"] do
        "success" ->
          id = socket.assigns.establishment.id
          establishment = Establishments.get_establishment!(socket.assigns.current_scope, id)

          socket
          |> assign(:establishment, establishment)
          |> assign_billing(establishment)
          |> put_flash(:info, gettext("Thank you! Your subscription should be active shortly."))

        "cancel" ->
          put_flash(socket, :info, gettext("Checkout was canceled."))

        _ ->
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("start_stripe_checkout", _params, socket) do
    est = socket.assigns.establishment
    base = LoyaltyWeb.Endpoint.url()
    success = base <> "/establishments/#{est.id}?checkout=success"
    cancel = base <> "/establishments/#{est.id}?checkout=cancel"

    case Stripe.create_subscription_checkout_session(est, success, cancel) do
      {:ok, url} ->
        {:noreply, redirect(socket, external: url)}

      {:error, :stripe_not_configured} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Stripe is not configured. Set STRIPE_SECRET_KEY and STRIPE_PRICE_ID.")
         )}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, gettext("Could not start checkout. Try again later."))}
    end
  end

  @impl true
  def handle_info(
        {:updated, %Establishment{id: id} = establishment},
        %{assigns: %{establishment: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> assign(:establishment, establishment)
     |> assign_billing(establishment)}
  end

  def handle_info(
        {:deleted, %Establishment{id: id}},
        %{assigns: %{establishment: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, gettext("The current establishment was deleted."))
     |> push_navigate(to: ~p"/establishments")}
  end

  def handle_info({type, %Establishment{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end

  defp assign_billing(socket, %Establishment{} = establishment) do
    count = Establishments.count_loyalty_cards(establishment.id)
    can_add? = Establishments.check_new_loyalty_card_allowed(establishment) == :ok

    {plan_label, limit} =
      cond do
        Billing.paid_subscription_allows_new_clients?(establishment) ->
          {gettext("Paid plan"), Billing.paid_client_limit()}

        Billing.on_free_plan?(establishment) ->
          {gettext("Free plan"), Billing.free_client_limit()}

        true ->
          {gettext("Subscription inactive"), nil}
      end

    payment_issue? = establishment.subscription_status in ["past_due", "unpaid"]
    show_subscribe_cta? = not Billing.paid_subscription_allows_new_clients?(establishment)
    on_free_plan? = Billing.on_free_plan?(establishment)
    free_limit = Billing.free_client_limit()

    show_free_plan_near_limit_hint? =
      on_free_plan? && show_subscribe_cta? && limit == free_limit &&
        count >= free_limit - 2

    socket
    |> assign(:client_count, count)
    |> assign(:client_limit, limit)
    |> assign(:plan_label, plan_label)
    |> assign(:can_add_new_client?, can_add?)
    |> assign(:payment_issue?, payment_issue?)
    |> assign(:show_subscribe_cta?, show_subscribe_cta?)
    |> assign(:on_free_plan?, on_free_plan?)
    |> assign(:show_free_plan_near_limit_hint?, show_free_plan_near_limit_hint?)
  end
end
