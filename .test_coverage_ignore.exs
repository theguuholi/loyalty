# CoreComponents: large generated UI helpers; excluded from threshold like many Phoenix apps.
[
  Loyalty.Application,
  LoyaltyWeb.CoreComponents,
  LoyaltyWeb.Layouts,
  Loyalty.Repo,
  LoyaltyWeb.Telemetry,
  Mix.Tasks.Coverage.Index,
  LoyaltyWeb.ErrorHTML,
  LoyaltyWeb.LocaleController,
  LoyaltyWeb.Plugs.Locale,
  LoyaltyWeb.LoyaltyProgramLive.Show,
  LoyaltyWeb.PageHTML,
  # External Twilio integration: network-error branch not testable without a real transport layer
  Loyalty.WhatsApp
]
