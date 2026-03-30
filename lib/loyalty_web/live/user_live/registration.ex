defmodule LoyaltyWeb.UserLive.Registration do
  use LoyaltyWeb, :live_view

  alias Loyalty.Accounts
  alias Loyalty.Accounts.User

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when user != nil do
    {:ok, redirect(socket, to: LoyaltyWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, session, socket) do
    changeset = Accounts.change_user_email(%User{}, %{}, validate_unique: false)
    est_code = Map.get(session, "establishment_referral_code")
    cust_code = Map.get(session, "customer_referral_code")

    socket =
      socket
      |> assign(:est_referral_code, est_code)
      |> assign(:cust_referral_code, cust_code)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.save_referral_codes(
            user,
            socket.assigns.est_referral_code,
            socket.assigns.cust_referral_code
          )

        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           gettext(
             "An email was sent to %{email}, please access it to confirm your account.",
             email: user.email
           )
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_email(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
