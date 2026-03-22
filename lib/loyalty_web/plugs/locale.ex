defmodule LoyaltyWeb.Plugs.Locale do
  @moduledoc """
  Sets the request locale from session or Accept-Language header.
  Puts the locale in conn.assigns.locale and sets Gettext locale for the process.
  """
  import Plug.Conn

  @default_locale "pt_BR"

  def init(opts), do: opts

  def call(conn, _opts) do
    {locale, conn} =
      case get_session(conn, "locale") do
        nil ->
          detected =
            conn
            |> get_req_header("accept-language")
            |> List.first()
            |> parse_accept_language()
            |> normalize()

          {detected, put_session(conn, "locale", detected)}

        stored ->
          {normalize(stored), conn}
      end

    Gettext.put_locale(LoyaltyWeb.Gettext, locale)

    assign(conn, :locale, locale)
  end

  defp parse_accept_language(nil), do: @default_locale
  defp parse_accept_language(""), do: @default_locale

  defp parse_accept_language(header) do
    header
    |> String.split(",")
    |> Enum.map(&String.split(&1, ";"))
    |> Enum.map(fn [lang | _] -> lang |> String.trim() |> String.downcase() end)
    |> Enum.find_value(@default_locale, fn lang ->
      cond do
        String.starts_with?(lang, "pt") -> "pt_BR"
        String.starts_with?(lang, "en") -> "en"
        true -> nil
      end
    end)
  end

  defp normalize(nil), do: @default_locale
  defp normalize(""), do: @default_locale
  defp normalize("pt-BR"), do: "pt_BR"
  defp normalize("pt_br"), do: "pt_BR"
  defp normalize("pt"), do: "pt_BR"
  defp normalize("en"), do: "en"
  defp normalize("en-US"), do: "en"
  defp normalize(_), do: @default_locale
end
