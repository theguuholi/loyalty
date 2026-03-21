defmodule LoyaltyWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use LoyaltyWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :locale, :string, default: "en", doc: "current locale for the language switcher"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="w-full min-w-0 border-b border-base-300 bg-base-100 px-4 py-3 sm:px-6 lg:px-8">
      <div class="mx-auto flex w-full max-w-7xl min-w-0 flex-row flex-wrap items-center justify-between gap-x-3 gap-y-2">
        <div class="min-w-0 shrink-0">
          <a href="/" class="inline-flex w-fit items-center gap-2">
            <span class="text-sm font-semibold">Loyalty</span>
          </a>
        </div>
        <div class="flex min-w-0 flex-1 flex-row flex-wrap items-center justify-end gap-x-3 gap-y-2 sm:gap-x-4">
          <.locale_switcher locale={@locale} />
          <.theme_toggle />
          <ul class="m-0 flex min-w-0 list-none flex-row flex-wrap items-center gap-x-3 gap-y-2 p-0 sm:gap-x-4">
            <%= if @current_scope do %>
              <li class="min-w-0">
                <div class="dropdown dropdown-end">
                  <div
                    tabindex="0"
                    role="button"
                    class={[
                      "btn btn-ghost btn-sm h-auto min-h-9 min-w-0 max-w-[min(100vw-10rem,14rem)] justify-between gap-2 sm:max-w-xs",
                      "border border-base-300 bg-base-100 font-normal normal-case"
                    ]}
                    aria-haspopup="menu"
                    aria-label={gettext("Account menu")}
                  >
                    <span class="truncate text-left text-sm" title={@current_scope.user.email}>
                      {@current_scope.user.email}
                    </span>
                    <.icon name="hero-arrow-small-down" class="size-4 shrink-0 opacity-60" />
                  </div>
                  <ul
                    tabindex="0"
                    class="dropdown-content menu menu-sm z-[100] mt-1 w-56 rounded-box border border-base-300 bg-base-100 p-2 shadow-md"
                  >
                    <li>
                      <.link href={~p"/establishments"}>
                        {gettext("Establishments")}
                      </.link>
                    </li>
                    <li>
                      <.link href={~p"/users/settings"}>{gettext("Settings")}</.link>
                    </li>
                    <li>
                      <.link href={~p"/users/log-out"} method="delete">{gettext("Log out")}</.link>
                    </li>
                  </ul>
                </div>
              </li>
            <% else %>
              <li>
                <.link href={~p"/users/register"} class="btn btn-primary">
                  {gettext("Register")}
                </.link>
              </li>
              <li>
                <.link href={~p"/users/log-in"}>{gettext("Log in")}</.link>
              </li>
            <% end %>
          </ul>
        </div>
      </div>
    </header>

    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-7xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Language switcher: EN | PT links that set session locale and reload.
  """
  attr :locale, :string, required: true

  def locale_switcher(assigns) do
    ~H"""
    <span class="flex items-center gap-1 text-sm">
      <a
        href={~p"/locale?locale=en"}
        class={["px-2 py-1 rounded", @locale == "en" && "font-semibold bg-base-300"]}
      >
        EN
      </a>
      <span aria-hidden="true">|</span>
      <a
        href={~p"/locale?locale=pt_BR"}
        class={["px-2 py-1 rounded", @locale == "pt_BR" && "font-semibold bg-base-300"]}
      >
        PT
      </a>
    </span>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
