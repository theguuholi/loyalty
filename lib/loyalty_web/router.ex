defmodule LoyaltyWeb.Router do
  use LoyaltyWeb, :router

  import LoyaltyWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug LoyaltyWeb.Plugs.Locale
    plug :fetch_live_flash
    plug :put_root_layout, html: {LoyaltyWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug :fetch_establishment_from_scope
  end

  # No Plug.Parsers: raw body must stay untouched for Stripe-Signature verification.
  pipeline :stripe_webhook do
    plug :accepts, ["json"]
    plug LoyaltyWeb.Plugs.RawBody
  end

  scope "/", LoyaltyWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/locale", LocaleController, :switch
  end

  scope "/webhooks", LoyaltyWeb do
    pipe_through :stripe_webhook

    post "/stripe", StripeWebhookController, :create
  end

  # Other scopes may use custom stacks.
  # scope "/api", LoyaltyWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:loyalty, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LoyaltyWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", LoyaltyWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [
        {LoyaltyWeb.UserAuth, :require_authenticated},
        {LoyaltyWeb.UserAuth, :assign_establishment_to_scope}
      ] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email

      live "/establishments", EstablishmentLive.Index, :index
      live "/establishments/new", EstablishmentLive.Form, :new
      live "/establishments/:id", EstablishmentLive.Show, :show
      live "/establishments/:id/edit", EstablishmentLive.Form, :edit

      scope "/establishments/:establishment_id" do
        live "/loyalty_programs", LoyaltyProgramLive.Index, :index
        live "/loyalty_programs/new", LoyaltyProgramLive.Form, :new
        live "/loyalty_programs/:id", LoyaltyProgramLive.Show, :show
        live "/loyalty_programs/:id/edit", LoyaltyProgramLive.Form, :edit

        live "/loyalty_cards", LoyaltyCardLive.Index, :index
        live "/loyalty_cards/new", LoyaltyCardLive.Form, :new
        live "/loyalty_cards/:id/edit", LoyaltyCardLive.Form, :edit
      end
    end

    post "/users/update-password", UserSessionController, :update_password

    live_session :require_admin,
      on_mount: [
        {LoyaltyWeb.UserAuth, :require_authenticated},
        {LoyaltyWeb.UserAuth, :require_admin}
      ] do
      live "/admin", AdminLive, :index
    end
  end

  scope "/", LoyaltyWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{LoyaltyWeb.UserAuth, :mount_current_scope}] do
      live "/cards", CardsLive, :index
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
