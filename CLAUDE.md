# Loyalty — Claude Guidelines

This is a Phoenix v1.8 web application with LiveView, Ecto, and `phx.gen.auth`.

> **LiveView-specific conventions** (file split, for loops, mobile-first, SEO, streams, PubSub, etc.)
> are documented in [`lib/loyalty_web/live/CLAUDE.md`](lib/loyalty_web/live/CLAUDE.md).

---

## Workflow

- **Always** write implementation plans to the `plan/` folder before touching code. Every plan must be a file in `plan/` — never write plans inline or in other locations. Each plan must explain **why** every migration and context module exists — what problem it solves, what data it owns, or what responsibility it carries.
- **Always** run `mix precommit` before every commit and **fix every issue it reports**. A failing `mix precommit` means the work is not done — do not commit until it passes clean.
- For HTTP requests, use the included `:req` (`Req`) library. **Never** use `:httpoison`, `:tesla`, or `:httpc`.
- Read task docs before running unfamiliar mix tasks: `mix help task_name`
- Debug test failures with `mix test test/my_test.exs` or `mix test --failed` for previously failed tests
- **Never** use `mix deps.clean --all` unless there is a concrete reason

### Test coverage — protected files

**Never** modify these two files under any circumstances:

- `mix.exs` — `summary: [threshold: 97]` line inside `test_coverage:`. This is the minimum coverage gate; lowering it is not acceptable.
- `.test_coverage_ignore.exs` — lists modules excluded from coverage. Do not add modules here to paper over missing tests; write the tests instead.

---

## Elixir

- Lists **do not support index-based access** via `list[i]`. Use `Enum.at/2`, pattern matching, or `List` functions instead.
- Block expressions (`if`, `case`, `cond`) **must** have their result bound at the call site — you cannot rebind inside the block:

  ```elixir
  # WRONG — socket is rebound inside the if, result is lost
  if connected?(socket) do
    socket = assign(socket, :val, val)
  end

  # CORRECT — bind the result of the if expression
  socket =
    if connected?(socket) do
      assign(socket, :val, val)
    end
  ```

- **Never** nest multiple modules in the same file — causes cyclic dependencies and compilation errors
- **Never** use map access syntax (`changeset[:field]`) on structs — structs do not implement `Access` by default. Use `my_struct.field` or `Ecto.Changeset.get_field/2` for changesets
- **Never** use `String.to_atom/1` on user input — memory leak risk
- Predicate function names must **not** start with `is_` and must end in `?`. Reserve `is_thing` style for guards only
- Use `Task.async_stream(collection, callback, timeout: :infinity)` for concurrent enumeration with back-pressure
- Use `Time`, `Date`, `DateTime`, and `Calendar` from the standard library for date/time work. Only add `date_time_parser` for parsing. **Never** add other date/time deps
- Elixir has `if/else` but **no `else if` or `elsif`**. Use `cond` or `case` for multiple branches

---

## Ecto

- **Always use changesets** for data validation and mutation — never validate params manually with `if/case` logic or raw map checks. Changesets are the single source of truth for what is valid.
- **Always preload associations** in context queries when they will be accessed in templates
- `Ecto.Schema` fields use `:string` even for text columns: `field :name, :string`
- `Ecto.Changeset.validate_number/2` does **not** support `:allow_nil` — omit it, validations already skip nil values by default
- Use `Ecto.Changeset.get_field(changeset, :field)` to read changeset values — never `changeset[:field]`
- Fields set programmatically (e.g. `user_id`) must **not** appear in `cast/3` — set them explicitly on the struct
- `import Ecto.Query` in `seeds.exs` and any module that builds raw queries

---

## Phoenix Router

- Router `scope` blocks carry an optional alias that prefixes all routes inside — **never** add a manual `alias` for route modules inside a scope
- `Phoenix.View` is no longer included with Phoenix — do not use it

### Authentication (`phx.gen.auth`)

`phx.gen.auth` creates these plugs and `live_session` blocks — always place routes in the correct one:

| Plug / live_session | Purpose |
|---|---|
| `:fetch_current_scope_for_user` | Included in the default browser pipeline. Assigns `@current_scope` to every request. |
| `:require_authenticated_user` | Redirects to login if not authenticated. |
| `live_session :require_authenticated_user` | LiveViews that require login. |
| `live_session :current_user` | LiveViews that work with or without login. |
| `:redirect_if_user_is_authenticated` | For registration/login pages that should redirect away when already logged in. |

**Always say which scope/pipeline/live_session a new route goes in, and why.**

`phx.gen.auth` assigns `current_scope`, **not** `current_user`. Always:
- Pass `current_scope` as the first argument to context functions
- Use `@current_scope.user` in templates — **never** `@current_user`
- Filter queries with `current_scope.user`

**Never** duplicate `live_session` names — each name can only appear once in the router.

#### Routes requiring authentication

```elixir
scope "/", LoyaltyWeb do
  pipe_through [:browser, :require_authenticated_user]

  live_session :require_authenticated_user,
    on_mount: [{LoyaltyWeb.UserAuth, :require_authenticated}] do
    live "/users/settings", UserLive.Settings, :edit
    live "/", MyAuthLive, :index
  end
end
```

#### Routes that work with or without authentication

```elixir
scope "/", LoyaltyWeb do
  pipe_through [:browser]

  live_session :current_user,
    on_mount: [{LoyaltyWeb.UserAuth, :mount_current_scope}] do
    live "/", PublicLive
  end
end
```

---

## Phoenix HTML & HEEx

- Templates always use `~H` or `.html.heex` files. **Never** use `~E`
- **Never** call `<.flash_group>` outside of `layouts.ex` — Phoenix v1.8 moved it to the `Layouts` module
- **Always** use `<.icon name="hero-x-mark">` for icons — **never** use `Heroicons` modules directly
- **Always** use the `<.input>` component from `core_components.ex` for form inputs. If you override `class`, no defaults are inherited — your classes must fully style the input
- Use `<.link navigate={href}>` and `<.link patch={href}>` — **never** `live_redirect` or `live_patch`
- **Never** write inline `<script>` tags in HEEx — write JS in `assets/js/` and import via `app.js`
- Use `phx-hook="MyHook"` + `phx-update="ignore"` together whenever a JS hook manages its own DOM

### Interpolation rules

| Situation | Correct syntax |
|---|---|
| Value inside tag body | `{@assign}` |
| Value inside tag attribute | `{@assign}` |
| Block construct in tag body (`if`, `for`, `case`) | `<%= ... %>` |
| Tag attribute | **never** `<%= %>` |

```heex
<%!-- CORRECT --%>
<div id={@id}>
  {@title}
  <%= if @show do %>
    {@body}
  <% end %>
</div>

<%!-- WRONG — program will crash --%>
<div id="<%= @id %>">
  {if @show do}
  {end}
</div>
```

### For loops — always use `:for` on the HTML tag

**Never** use `<%= for ... do %>` block expressions or `Enum.each` to generate markup.

```heex
<%!-- CORRECT --%>
<ul>
  <li :for={item <- @items} id={item.id}>{item.name}</li>
</ul>

<%!-- WRONG --%>
<ul>
  <%= for item <- @items do %>
    <li>{item.name}</li>
  <% end %>
</ul>
```

### Conditional classes

Always use the list syntax for conditional classes:

```heex
<a class={[
  "px-2 text-white",
  @active && "font-bold",
  if(@error, do: "border-red-500", else: "border-base-300"),
]}>
```

### Literal curly braces in templates

Annotate the parent tag with `phx-no-curly-interpolation` when outputting `{` or `}` as text (e.g. code snippets):

```heex
<code phx-no-curly-interpolation>
  let obj = {key: "val"}
</code>
```

### HEEx comments

Always use `<%!-- comment --%>` for template comments, not `<!-- -->`.

---

## Forms

Always use `to_form/2` assigned in the LiveView and the `<.input>` component in the template:

```elixir
# In the LiveView
assign(socket, form: to_form(changeset))
```

```heex
<%!-- In the template --%>
<.form for={@form} id="my-form" phx-change="validate" phx-submit="save">
  <.input field={@form[:name]} type="text" />
</.form>
```

- **Never** pass the changeset directly to `<.form>` — always go through `to_form/2`
- **Never** use `<.form let={f}>` — always `<.form for={@form}>`
- **Never** access `@changeset` in the template
- Always give forms a unique DOM `id`

#### Form from raw params

```elixir
def handle_event("submitted", %{"user" => params}, socket) do
  {:noreply, assign(socket, form: to_form(params, as: :user))}
end
```

---

## JS & CSS

- Use **Tailwind CSS** for all styling. No `@apply` in raw CSS.
- Tailwind v4 uses this import syntax in `app.css` — **always maintain it**:

  ```css
  @import "tailwindcss" source(none);
  @source "../css";
  @source "../js";
  @source "../../lib/loyalty_web";
  ```

- Only `app.js` and `app.css` bundles are supported out of the box — import vendor deps into those files, never reference external `src` or `href` in layouts
- **Never** use daisyUI — write your own Tailwind components for a unique design
- **Never** write inline `<script>` tags in templates

---

## UI/UX

- Produce world-class UI: focus on usability, aesthetics, and modern design principles
- Implement subtle micro-interactions: hover effects, smooth transitions, loading states
- Clean typography, spacing, and layout balance for a refined, premium look
