defmodule LoyaltyWeb.LocaleController do
  use LoyaltyWeb, :controller

  @supported_locales ["en", "pt_BR"]

  def switch(conn, %{"locale" => locale}) do
    locale = normalize_locale(locale)
    referer = conn |> get_req_header("referer") |> List.first()

    conn
    |> put_session("locale", locale)
    |> redirect(external: referer || "/")
  end

  def switch(conn, _params) do
    redirect(conn, to: "/")
  end

  defp normalize_locale(locale) when locale in @supported_locales, do: locale
  defp normalize_locale("pt-BR"), do: "pt_BR"
  defp normalize_locale("pt"), do: "pt_BR"
  defp normalize_locale(_), do: "pt_BR"
end
