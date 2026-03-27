# UI Overhaul + Establishment Logo Upload

## Context

User feedback from real users (via WhatsApp): the interface looks ugly, untrustworthy ("gives the impression of a dangerous app"), and lacks visual appeal. Users specifically requested:
1. More trustworthy, eye-catching design
2. Animated card display with the company logo
3. Ability to upload a company logo/image

The app currently uses a golden/orange daisyUI theme, flat white card boxes with a plain progress bar, and has zero image upload infrastructure. The goal is to make the app look like a premium, trustworthy loyalty platform (fintech aesthetic: deep forest green + gold).

---

## Changes Overview

### 1. Color Palette — `assets/css/app.css`

Replace the light theme's golden/orange primary with deep forest green + gold accent:

```css
/* light theme — replace existing primary/secondary/accent values */
--color-primary: oklch(35% 0.1 155);           /* deep forest green */
--color-primary-content: oklch(97% 0.01 155);
--color-secondary: oklch(72% 0.17 82);          /* warm gold */
--color-secondary-content: oklch(20% 0.05 82);
--color-accent: oklch(68% 0.18 50);             /* amber */
--color-accent-content: oklch(15% 0.04 50);

/* dark theme */
--color-primary: oklch(55% 0.12 155);
--color-primary-content: oklch(97% 0.01 155);
```

Add card entrance animation keyframes at end of file:

```css
@keyframes card-enter {
  from { opacity: 0; transform: translateY(16px); }
  to   { opacity: 1; transform: translateY(0); }
}
.loyalty-card-animate {
  animation: card-enter 0.4s ease-out both;
}
.loyalty-card-animate:nth-child(1) { animation-delay: 0ms; }
.loyalty-card-animate:nth-child(2) { animation-delay: 80ms; }
.loyalty-card-animate:nth-child(3) { animation-delay: 160ms; }
.loyalty-card-animate:nth-child(4) { animation-delay: 240ms; }
.loyalty-card-animate:nth-child(5) { animation-delay: 320ms; }
@media (prefers-reduced-motion: reduce) { .loyalty-card-animate { animation: none; } }
```

### 2. Data Layer — add `logo_url` to establishments

**New migration** (`priv/repo/migrations/<ts>_add_logo_url_to_establishments.exs`):
```elixir
alter table(:establishments) do
  add :logo_url, :string
end
```

**`lib/loyalty/establishments/establishment.ex`**: add `field :logo_url, :string` to schema, add `:logo_url` to `cast/2`.

**`lib/loyalty_web.ex` line 20**: add `uploads` to static paths:
```elixir
def static_paths, do: ~w(assets fonts images uploads favicon.ico robots.txt)
```

**Create directory**: `priv/static/uploads/logos/.gitkeep`

### 3. Establishment Logo Upload — `lib/loyalty_web/live/establishment_live/form.ex`

In `mount/3`, after form setup, add:
```elixir
socket = allow_upload(socket, :logo,
  accept: ~w(image/png image/jpeg image/gif image/webp),
  max_entries: 1,
  max_file_size: 5_000_000
)
```

In `handle_event("save", params, socket)`, before calling save functions, consume the upload:
```elixir
logo_url = consume_uploaded_logo(socket)
params = Map.put(params["establishment"] || %{}, "logo_url", logo_url || socket.assigns.establishment.logo_url)
```

Add cancel upload event handler:
```elixir
def handle_event("cancel_upload", %{"ref" => ref}, socket) do
  {:noreply, cancel_upload(socket, :logo, ref)}
end
```

Add private helpers:
```elixir
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

defp upload_error_to_string(:too_large), do: "Arquivo muito grande (máx 5MB)"
defp upload_error_to_string(:not_accepted), do: "Tipo de arquivo não permitido"
defp upload_error_to_string(:too_many_files), do: "Apenas uma imagem permitida"
defp upload_error_to_string(_), do: "Erro no upload"
```

In the form template, add after the name input:
```heex
<%!-- Logo upload section --%>
<div>
  <label class="block text-sm font-medium text-gray-700 mb-1">Logo da empresa</label>
  <%= if @establishment.logo_url do %>
    <img src={@establishment.logo_url} class="w-16 h-16 rounded-lg object-cover mb-2" />
  <% end %>
  <.live_file_input upload={@uploads.logo} class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-semibold file:bg-green-50 file:text-green-700 hover:file:bg-green-100" />
  <%= for entry <- @uploads.logo.entries do %>
    <div class="mt-2 flex items-center gap-3">
      <.live_img_preview entry={entry} class="w-12 h-12 rounded-lg object-cover" />
      <div class="flex-1">
        <p class="text-sm text-gray-600">{entry.client_name}</p>
        <div class="h-1.5 bg-gray-200 rounded-full mt-1">
          <div class="h-full bg-green-600 rounded-full transition-all" style={"width: #{entry.progress}%"}></div>
        </div>
      </div>
      <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref} class="text-gray-400 hover:text-red-500">
        <.icon name="hero-x-mark" class="w-4 h-4" />
      </button>
    </div>
    <%= for err <- upload_errors(@uploads.logo, entry) do %>
      <p class="text-sm text-red-500 mt-1">{upload_error_to_string(err)}</p>
    <% end %>
  <% end %>
</div>
```

### 4. Premium Card Component — `lib/loyalty_web/live/cards_live.ex`

Replace the flat white card `<div>` with a premium card design:

```heex
<div :for={{id, card} <- @streams.cards} id={id} class="loyalty-card-animate">
  <div class="relative rounded-2xl overflow-hidden shadow-xl"
       style="background: linear-gradient(135deg, #1b4d3e 0%, #1e5c4a 50%, #0f3329 100%); aspect-ratio: 1.586;">
    <%!-- Background pattern --%>
    <div class="absolute inset-0 opacity-5"
         style="background-image: radial-gradient(circle at 20% 80%, white 1px, transparent 1px), radial-gradient(circle at 80% 20%, white 1px, transparent 1px); background-size: 30px 30px;">
    </div>
    <%!-- Logo + establishment name --%>
    <div class="absolute top-4 left-4 right-4 flex items-center gap-3">
      <%= if card.establishment.logo_url do %>
        <img src={card.establishment.logo_url} class="w-10 h-10 rounded-lg object-cover ring-2 ring-white/20" />
      <% else %>
        <div class="w-10 h-10 rounded-lg bg-white/10 flex items-center justify-center">
          <.icon name="hero-building-storefront" class="w-5 h-5 text-white/70" />
        </div>
      <% end %>
      <p class="text-white font-semibold text-base leading-tight">{card.establishment.name}</p>
    </div>
    <%!-- Stamp circles --%>
    <div class="absolute bottom-10 left-4 right-4">
      <%= if card.stamps_required <= 12 do %>
        <div class="flex flex-wrap gap-2">
          <%= for i <- 1..card.stamps_required do %>
            <div class={[
              "w-7 h-7 rounded-full border-2 flex items-center justify-center transition-all",
              if(i <= (card.stamps_current || 0),
                do: "bg-[#d4af37] border-[#d4af37] shadow-[0_0_8px_rgba(212,175,55,0.6)]",
                else: "bg-transparent border-white/30")
            ]}>
              <%= if i <= (card.stamps_current || 0) do %>
                <.icon name="hero-star-solid" class="w-3.5 h-3.5 text-white" />
              <% end %>
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="flex items-center gap-2">
          <div class="flex-1 h-2 rounded-full bg-white/20 overflow-hidden">
            <div class="h-full rounded-full bg-[#d4af37] transition-all"
                 style={"width: #{min(100, div((card.stamps_current || 0) * 100, max(1, card.stamps_required)))}%"}>
            </div>
          </div>
          <span class="text-white/80 text-sm font-medium whitespace-nowrap">
            {card.stamps_current || 0}/{card.stamps_required}
          </span>
        </div>
      <% end %>
    </div>
    <%!-- Reward description --%>
    <div class="absolute bottom-3 left-4 right-4 flex items-center justify-between">
      <p class="text-white/70 text-xs truncate">{card.loyalty_program.reward_description}</p>
      <%= if (card.stamps_current || 0) >= card.stamps_required do %>
        <span class="text-xs font-semibold text-[#d4af37] whitespace-nowrap ml-2">✓ Pronto!</span>
      <% end %>
    </div>
  </div>
</div>
```

### 5. Logo on Dashboard — `lib/loyalty_web/live/establishment_live/show.ex`

Before the `<.header>` in `render/1`, add:
```heex
<%= if @establishment.logo_url do %>
  <div class="mb-6 flex items-center gap-4">
    <img src={@establishment.logo_url} class="w-16 h-16 rounded-xl object-cover shadow-md ring-2 ring-gray-100" />
    <div>
      <p class="text-xs text-gray-500 uppercase tracking-wide font-medium">Sua marca</p>
      <p class="text-sm text-gray-700">Logo cadastrado</p>
    </div>
  </div>
<% end %>
```

---

## Execution Order

1. Migration → schema → static_paths → create uploads dir
2. `assets/css/app.css` color palette + animations
3. `establishment_live/form.ex` upload logic + template
4. `cards_live.ex` premium card component
5. `establishment_live/show.ex` logo display
6. `mix precommit` — fix any issues
7. `mix ecto.migrate`

## Verification

1. Start server with `mix phx.server`
2. Register/login, go to establishment settings — should show logo upload field
3. Upload a PNG logo, save — verify it shows in the dashboard and on the customer card page
4. Open `/cards` (public page), look up a card — should show premium card design with animation on load
5. Check both light and dark themes via the theme toggle
