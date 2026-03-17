# Development premises — MyRewards

This document defines the **mandatory premises** for all development in this project. It must be followed for **every feature** you implement.

**Language:** All code, module docs, function docs, and commit messages must be **in English**. Keep documentation simple so any developer can read and understand it.

---

## 1. Test-Driven Development (TDD)

- **Always** use **Test-Driven Development**.
- Work order:
  1. **Red:** Write the failing test (desired behaviour).
  2. **Green:** Implement the minimum to make the test pass.
  3. **Refactor:** Improve the code while keeping tests green.
- No new behaviour is done without tests covering it (Context and LiveView, as applicable).

---

## 2. Typespecs on all functions

- **Every public function** must have a `@spec` (typespec).
- Use `@doc` for public functions; keep docs **short and clear** so any developer can understand quickly.
- Prefer standard types (`String.t()`, `integer()`, `[%MyStruct{}]`, etc.). Use custom types when it improves readability.

Example:

```elixir
@doc """
  Finds a customer by email. Returns the customer or `nil` if not found.
"""
@spec get_customer_by_email(String.t()) :: MyRewards.Loyalty.Customer.t() | nil
def get_customer_by_email(email) when is_binary(email) do
  # ...
end
```

- Dialyzer (run in `mix precommit`) will check types; fix any type errors before merging.

---

## 3. Documentation: simple and readable

- **All public modules** must have a short `@moduledoc` describing the module’s purpose in one or two sentences.
- **All public functions** should have a brief `@doc` that explains:
  - **What** the function does (one line is enough when obvious).
  - **Arguments** and **return value** when not obvious; avoid long paragraphs.
- Write for **humans**: avoid jargon when a simple word works. Any developer should understand without digging.

Good:

```elixir
@doc """
  Adds one stamp to the given loyalty card. Returns the updated card or an error.
"""
@spec add_stamp(LoyaltyCard.t()) :: {:ok, LoyaltyCard.t()} | {:error, Ecto.Changeset.t()}
def add_stamp(card), do: # ...
```

Avoid: long essays, redundant “This function does X” when the name already says it, or unclear terms.

---

## 4. Clean code: easy for humans to understand

- Code must follow **clean code** principles, with **readability** as the main goal: a human should understand intent quickly.
- Prefer:
  - **Short functions** that do one thing.
  - **Clear names** for modules, functions, and variables (no cryptic abbreviations).
  - **Few arguments**; use structs or keyword lists when there are many options.
  - **No deep nesting**; use early returns or extract functions.
- Avoid:
  - Magic numbers or strings; use named constants or module attributes.
  - Comments that restate what the code does; make the code self-explanatory and use docs for “why” when needed.
- When in doubt, choose the option that is **easier to read** for the next developer.

---

## 5. `mix precommit` — Everything must pass

Before considering any change done, you **must** run:

```bash
mix precommit
```

The alias runs (in order):

| Step | Command | What it checks |
|------|---------|----------------|
| 1 | `compile --warnings-as-errors` | Compiles with no warnings. |
| 2 | `deps.unlock --check-unused` | Lockfile has no unused deps. |
| 3 | `format --check-formatted` | Code is formatted with `mix format`. |
| 4 | `credo --strict` | Style and good practices (strict). |
| 5 | `sobelow --skip -i Config.CSP --config` | Security (e.g. SQL injection, XSS). |
| 6 | `dialyzer` | Types and contracts (typespecs). |
| 7 | `test --cover` | All tests and coverage. |
| 8 | `coverage.index` | Coverage index (99.5% threshold). |

- **Nothing** is merged or considered done if `mix precommit` fails.
- Fix **all** failing steps (compile, format, credo, sobelow, dialyzer, tests, coverage) before finishing.

---

## 6. Test structure and conventions

### 6.1 Naming: Given / When / Then

Each test name should describe **context**, **action**, and **expected outcome**:

```elixir
test "given <context> when <action> then <expected outcome>", %{...} do
  # ...
end
```

Examples:

- `"given a visitor when they visit the courses page then they see the page title"`
- `"given published courses when visitor loads the page then they see all published courses"`
- `"given an authenticated establishment when they add a stamp then the card progress updates"`

### 6.2 LiveView: `describe` per callback and helpers

- Group tests by callback (e.g. `mount/3`, `handle_event/3`).
- **Always** use `Phoenix.LiveViewTest` helpers: `live/2`, `has_element?/3`, `refute has_element?/3`, `render_click/2`, `render_submit/2`, `render_change/2`, `element/3`, etc.
- **Do not** rely on raw HTML; prefer `has_element?(view, "selector", text)` or `element(view, selector)`.

Example LiveView structure:

```elixir
describe "mount/3" do
  test "given a visitor when they visit the courses page then they see the page title", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/courses")

    assert has_element?(view, "h1", "Explore Our Courses")
    assert has_element?(view, "p", "Discover transformative learning experiences")
  end

  test "given published courses when visitor loads the page then they see all published courses",
       %{conn: conn} do
    _published1 = course_fixture(%{title: "Elixir Mastery", published: true})
    _published2 = course_fixture(%{title: "Phoenix Framework", published: true})
    _unpublished = course_fixture(%{title: "Secret Course", published: false})

    {:ok, view, _html} = live(conn, ~p"/courses")

    assert has_element?(view, "h3", "Elixir Mastery")
    assert has_element?(view, "h3", "Phoenix Framework")
    refute has_element?(view, "h3", "Secret Course")
  end
end

describe "handle_event \"add_stamp\"" do
  test "given a loyalty card when establishment clicks add stamp then stamps_current increments", %{
    conn: conn
  } do
    # setup: authenticated establishment, existing card
    {:ok, view, _html} = live(conn, ~p"/establishment/cards/123")
    assert has_element?(view, "[data-progress]", "7 / 10")

    render_click(view, "add-stamp")

    assert has_element?(view, "[data-progress]", "8 / 10")
  end
end
```

### 6.3 Context: tests per public function

- Every public Context function with meaningful effect or return **must** have tests.
- Use **fixtures** (e.g. `course_fixture`, `establishment_fixture`, `loyalty_card_fixture`) to build data; avoid creating records by hand when a helper exists.
- Cover success, validation (changesets), and edge cases (e.g. not found, no permission).

Example:

```elixir
describe "get_customer_by_email/1" do
  test "given an existing email when get_customer_by_email then returns the customer", %{} do
    customer = customer_fixture(%{email: "user@example.com"})

    assert Loyalty.get_customer_by_email("user@example.com") == customer
  end

  test "given a non existing email when get_customer_by_email then returns nil", %{} do
    assert Loyalty.get_customer_by_email("missing@example.com") == nil
  end
end
```

### 6.4 UI and Context elements

- **Every relevant element** added in pages (LiveView) and Context must be **covered by tests**:
  - New fields, buttons, links, lists, forms → LiveView tests that check presence and behaviour (click, submit, change).
  - New Context functions (queries, commands) → Context tests with given/when/then and fixtures.
- Prefer **IDs and `data-*`** on critical elements (forms, buttons, lists) for stable selectors (see AGENTS.md).

---

## 7. Feature checklist

When implementing **any feature**, follow this order and ensure:

1. [ ] **TDD:** Tests written first (or in parallel); then implementation.
2. [ ] **Typespecs:** Every public function has a `@spec`.
3. [ ] **Docs:** Module and public functions have simple, clear `@moduledoc` / `@doc` in English.
4. [ ] **Clean code:** Short functions, clear names, minimal nesting; readable for humans.
5. [ ] **Context:** Public functions tested with given/when/then and fixtures.
6. [ ] **LiveView:** Callbacks (mount, handle_event, etc.) tested with `live`, `has_element?`, `render_click` / `render_submit` / `render_change`.
7. [ ] **Elements:** IDs or `data-*` on forms and main actions; asserts use those selectors.
8. [ ] **Precommit:** `mix precommit` run and **all** steps passing.
9. [ ] **Coverage:** No new code lowering coverage below the threshold (99.5%); add to `.test_coverage_ignore.exs` only when strictly necessary.

---

## 8. Project references

- **AGENTS.md** — Project rules (Phoenix, Ecto, LiveView, Tailwind, etc.).
- **docs/CONCEPT.md** — Problem and product premises.
- **docs/TDD.md** — Technical Design Document (business rules, data model).
- **docs/SYSTEM_DESIGN.md** — Architecture and flows.
- **docs/DESIGN.md** — Colors and layout (palette, spacing, components).
- **docs/SCREENS.md** — Screen-by-screen spec (copy, form fields, DOM IDs for tests).
- **docs/TEST_PLAN.md** — Test plan for the whole feature (Context + LiveView cases, IDs, order).
- **docs/MVP_BACKLOG.md** — What’s missing, router/auth decision, implementation order.
- **docs/design/prototype/** — Mobile-first UI reference for screens.

---

## 9. Using this doc as a prompt for features

When asking for a new feature, you can say:

> Implement [feature X] following **docs/DEVELOPMENT.md**: TDD required, `mix precommit` must pass, typespecs and simple docs in English on all public functions, clean code for readability. Tests in given/when/then style for Context and LiveView, using `has_element?`, `render_click`, etc. Every new context and page element must be covered by tests.

That keeps every implementation aligned with these premises and the precommit.
