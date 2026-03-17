# Test Plan: MyRewards MVP (User → Establishments → Loyalty)

This document defines the **test plan** for the whole feature: user account, establishments (one user has many), loyalty programs, loyalty cards, and stamps. It follows [DEVELOPMENT.md](DEVELOPMENT.md) (given/when/then, LiveView helpers, coverage) and aligns with [TDD.md](TDD.md) and [SYSTEM_DESIGN.md](SYSTEM_DESIGN.md).

**References:** [SCREENS.md](SCREENS.md) (copy, form fields, DOM IDs), [MVP_BACKLOG.md](MVP_BACKLOG.md) (implementation order).

---

## 1. Scope and test layers

| Layer | What is tested | Tools |
|-------|----------------|--------|
| **Context** | Public functions of `Accounts`, `Establishments` (or equivalent), `Loyalty` | ExUnit, fixtures, `Repo` |
| **LiveView** | Mount, `handle_params`, `handle_event`, forms, redirects | `Phoenix.LiveViewTest`: `live`, `has_element?`, `render_click`, `render_submit`, `render_change` |
| **Auth / Plugs** | Session, redirect when unauthenticated, scope (user only sees own establishments) | `ConnCase`, `LiveViewTest`, login helpers |

Every new context function and every new page element (form, button, list, link) must have a test. Use **stable selectors**: DOM IDs and `data-*` attributes as in [SCREENS.md](SCREENS.md).

---

## 2. Fixtures and test data

Create or extend fixtures so tests can build data without duplicating setup:

| Fixture | Purpose |
|---------|---------|
| `user_fixture/1` | User (account) with email/password for authenticated flows. |
| `establishment_fixture/2` (user, attrs) | Establishment belonging to a user; optional subscription_status. |
| `loyalty_program_fixture/2` (establishment, attrs) | Loyalty program for an establishment (stamps_required, reward_description). |
| `customer_fixture/1` | Customer identified by email. |
| `loyalty_card_fixture/2` (customer, establishment, attrs) | Loyalty card for (customer, establishment) with optional stamps_current. |

**Log-in helper:** Reuse or add `log_in_user(conn, user)` (and corresponding `setup` with `%{conn: conn, user: user}`) so LiveView tests for authenticated routes can start from a logged-in session.

---

## 3. Context tests

### 3.1 Accounts (User)

| Test (given / when / then) | Function / behaviour |
|----------------------------|----------------------|
| given valid attrs when `register_user/1` then returns `{:ok, %User{}}` and user exists in DB | `Accounts.register_user/1` |
| given invalid attrs (e.g. bad email) when `register_user/1` then returns `{:error, changeset}` | Validation |
| given existing email when `register_user/1` then returns `{:error, changeset}` (unique) | Uniqueness |
| given existing user when `get_user_by_email/1` then returns that user | `Accounts.get_user_by_email/1` |
| given unknown email when `get_user_by_email/1` then returns `nil` | Not found |
| given correct credentials when `get_user_by_email_and_password/2` then returns user | `Accounts.get_user_by_email_and_password/2` |
| given wrong password when `get_user_by_email_and_password/2` then returns `nil` | Auth failure |

(Existing `Accounts` tests may already cover these; ensure they follow given/when/then naming.)

### 3.2 Establishments (user has many)

| Test (given / when / then) | Function / behaviour |
|----------------------------|----------------------|
| given a user when `list_establishments_by_user/1` then returns only that user's establishments | Scoping by user |
| given a user and valid attrs when `create_establishment/2` then returns `{:ok, establishment}` with `user_id` set | `create_establishment(user, attrs)` |
| given a user and invalid attrs when `create_establishment/2` then returns `{:error, changeset}` | Validation |
| given an establishment belonging to user when `get_establishment!/2` (user, id) then returns establishment | `get_establishment!(user, id)` |
| given establishment belonging to another user when `get_establishment!/2` then raises or returns error | No cross-user access |
| given a user when `list_establishments_by_user/1` then establishments are ordered (e.g. by name or inserted_at) | Ordering |

### 3.3 Loyalty (Customer, LoyaltyProgram, LoyaltyCard, Stamp)

| Test (given / when / then) | Function / behaviour |
|----------------------------|----------------------|
| given an email when `get_or_create_customer_by_email/1` and customer exists then returns that customer | Get existing |
| given an email when `get_or_create_customer_by_email/1` and customer does not exist then creates and returns customer | Create new |
| given establishment and customer when `create_loyalty_card/2` (or 3) then returns `{:ok, card}` and card has establishment_id, customer_id | `create_loyalty_card` |
| given same (customer, establishment) when `create_loyalty_card` again then returns `{:error, changeset}` (unique) | One card per (customer, establishment) |
| given a loyalty card when `add_stamp/1` then `stamps_current` increments by 1 | `Loyalty.add_stamp/1` |
| given a loyalty card when `add_stamp/1` then returns `{:ok, updated_card}` | Return value |
| given customer email when `list_loyalty_cards_by_customer_email/1` then returns all cards for that customer (any establishment) | List for "Meus cartões" |
| given establishment when `list_loyalty_cards_by_establishment/1` then returns only cards for that establishment | List for establishment panel |
| given establishment when `get_loyalty_program!/1` then returns program for that establishment | LoyaltyProgram 1:1 |
| given establishment and attrs when `create_or_update_loyalty_program/2` then creates or updates program | Program create/update |

---

## 4. LiveView tests — Public (client)

### 4.1 Landing (`GET /`)

| Test (given / when / then) | Selectors / IDs |
|-----------------------------|------------------|
| given a visitor when they visit `/` then they see the landing title and CTA "Ver meus cartões" | `#landing-cta-cards` |
| given a visitor when they visit `/` then they see link "Sou estabelecimento" (or similar) | `#landing-link-establishment` |
| given a visitor when they click "Ver meus cartões" then they are navigated to `/cards` | `#landing-cta-cards` → assert path |

### 4.2 Meus cartões — Entry (`GET /cards`)

| Test (given / when / then) | Selectors / IDs |
|-----------------------------|------------------|
| given a visitor when they visit `/cards` then they see the email entry form | `#cards-entry-form`, `#cards-entry-email`, `#cards-entry-submit` |
| given valid email when they submit the form then they are redirected to `/cards?email=...` and see list or empty state | `render_submit`, then assert path and presence of list or empty message |
| given invalid email when they submit then they see validation error and stay on entry | `render_submit`, refute redirect, assert error |

### 4.3 Meus cartões — List (`GET /cards?email=...`)

| Test (given / when / then) | Selectors / IDs |
|-----------------------------|------------------|
| given a customer with loyalty cards when they open `/cards?email=...` then they see each card with establishment name, progress, reward | `#cards-list`, `#card-item-{id}` or `#card-establishment`, `#card-progress`, `#card-reward` |
| given an email with no cards when they open `/cards?email=...` then they see empty state message | `#cards-empty-message` |
| given list view when they click "Trocar e-mail" then they go back to entry (or clear email) | `#cards-change-email-link` |

---

## 5. LiveView tests — User (account) auth

### 5.1 Registration (`/users/register`)

| Test (given / when / then) | Selectors / IDs |
|-----------------------------|------------------|
| given a visitor when they visit `/users/register` then they see registration form (email, password) | Form IDs per phx.gen.auth or SCREENS |
| given valid attrs when they submit then user is created and they are redirected (e.g. to login or dashboard) | `render_submit` → assert redirect |
| given invalid attrs when they submit then they see errors and stay on form | `render_submit` → assert no redirect, has errors |

### 5.2 Login (`/users/log-in`)

| Test (given / when / then) | Selectors / IDs |
|-----------------------------|------------------|
| given a visitor when they visit `/users/log-in` then they see login form | Form present |
| given valid credentials when they submit then they are logged in and redirected (e.g. to establishments) | `render_submit` → assert redirect to signed_in_path |
| given invalid credentials when they submit then they see error and stay on login | `render_submit` → assert no redirect |

### 5.3 Logout and protected routes

| Test (given / when / then) | Behaviour |
|-----------------------------|-----------|
| given an unauthenticated user when they visit `/establishments` then they are redirected to login | `live(conn, ~p"/establishments")` → redirect to login |
| given an authenticated user when they click "Sair" (or logout) then session is cleared and they are redirected to public page | Logout link → assert redirect |

---

## 6. LiveView tests — Establishments (authenticated user)

### 6.1 List establishments (`GET /establishments`)

| Test (given / when / then) | Selectors / IDs |
|-----------------------------|------------------|
| given a logged-in user with establishments when they visit `/establishments` then they see all their establishments | List of establishments, no others |
| given a logged-in user with no establishments when they visit `/establishments` then they see empty state and link/button to create | Empty state + "Criar estabelecimento" (or similar) |
| given a logged-in user when they click an establishment then they navigate to `/establishments/:id` | Click row/link → assert path |

### 6.2 Create establishment (`GET /establishments/new`)

| Test (given / when / then) | Selectors / IDs |
|-----------------------------|------------------|
| given a logged-in user when they visit `/establishments/new` then they see form (e.g. name) | Form with name field |
| given valid name when they submit then establishment is created and they are redirected (e.g. to Stripe or to establishment show) | `render_submit` → assert redirect and DB has new establishment for user |
| given invalid attrs when they submit then they see errors and stay on form | `render_submit` → assert errors |

### 6.3 Establishment show (`GET /establishments/:id`)

| Test (given / when / then) | Selectors / IDs |
|-----------------------------|------------------|
| given a logged-in user and their establishment when they visit `/establishments/:id` then they see establishment name and links (program, cards) | `#dashboard-edit-program-link`, `#dashboard-cards-link`, etc. (see SCREENS) |
| given a logged-in user and another user's establishment when they visit `/establishments/:id` then they get 404 or redirect (no access) | Forbidden / not found |

### 6.4 Program edit (`GET /establishments/:id/program/edit` or `/program`)

| Test (given / when / then) | Selectors / IDs |
|-----------------------------|------------------|
| given establishment with program when they visit program edit then they see form with stamps_required and reward_description | `#program-form`, `#program-stamps-required`, `#program-reward-description`, `#program-submit` |
| given valid attrs when they submit then program is updated and they see success (flash or redirect) | `render_submit` → assert update |
| given invalid attrs (e.g. stamps_required 0) when they submit then they see validation error | `render_submit` → assert errors |

### 6.5 Cards index (`GET /establishments/:id/cards`)

| Test (given / when / then) | Selectors / IDs |
|-----------------------------|------------------|
| given establishment with loyalty cards when they visit cards index then they see list of cards (email, progress) | `#establishment-cards-list`, `#establishment-card-item-{id}` |
| given establishment with no cards when they visit then they see empty state and way to register client | `#establishment-register-client-btn` or empty message |
| given search input when they type email and submit search then list filters or shows matching card | `#establishment-cards-search` |
| given they click "+ Carimbo" for a card then they navigate to add-stamp for that card | `#establishment-add-stamp-link-{id}` → path `/establishments/:id/cards/:card_id` |

### 6.6 Add stamp (`GET /establishments/:id/cards/:card_id` or add-stamp show)

| Test (given / when / then) | Selectors / IDs |
|-----------------------------|------------------|
| given a loyalty card when they visit add-stamp page then they see card progress and "+ 1 carimbo" button | `#add-stamp-card`, `#add-stamp-progress`, `#add-stamp-button` |
| given a loyalty card when they click "+ 1 carimbo" then `stamps_current` increments and UI updates (and optional flash) | `render_click(view, "#add-stamp-button")` → assert progress text or data updated |
| given a card at max stamps when they add one more then they see "complete" message (optional) | Assert "Cartão completo" or similar |

---

## 7. LiveView tests — Register client (establishment)

| Test (given / when / then) | Behaviour |
|-----------------------------|-----------|
| given establishment when they submit "Cadastrar cliente" with email then customer is created or found and loyalty_card is created for that establishment | Form submit → assert card in list |
| given existing customer (same email) when they register client for this establishment then new loyalty_card is created (same customer, this establishment) | No duplicate card for same (customer, establishment) |

---

## 8. Auth and scope (integration-style)

| Test (given / when / then) | Behaviour |
|-----------------------------|-----------|
| given user A and establishment of user B when user A requests `/establishments/:id` (B's id) then 404 or redirect | No cross-user access to establishments |
| given user A when listing establishments then only A's establishments are shown | `list_establishments_by_user` or LiveView list only shows current user's |

---

## 9. DOM IDs and selectors summary

Use these in templates so tests can rely on stable selectors. Align with [SCREENS.md](SCREENS.md); adjust route prefixes to `/users` and `/establishments` as per [SYSTEM_DESIGN.md](SYSTEM_DESIGN.md).

| Area | IDs / selectors |
|------|------------------|
| Landing | `#landing-cta-cards`, `#landing-link-establishment` |
| Meus cartões entry | `#cards-entry-form`, `#cards-entry-email`, `#cards-entry-submit` |
| Meus cartões list | `#cards-list`, `#card-item-{id}` or `#card-establishment`, `#card-progress`, `#card-reward`, `#cards-empty-message`, `#cards-change-email-link` |
| User register / login | Use phx.gen.auth defaults or add explicit IDs for form and submit. |
| Establishments list | List container, link per establishment, "Criar estabelecimento" button. |
| Establishment show | `#dashboard-edit-program-link`, `#dashboard-cards-link`, `#dashboard-add-stamp-link`, `#dashboard-logout-link` |
| Program form | `#program-form`, `#program-name`, `#program-stamps-required`, `#program-reward-description`, `#program-submit` |
| Cards index | `#establishment-cards-search`, `#establishment-cards-list`, `#establishment-card-item-{id}`, `#establishment-add-stamp-link-{id}`, `#establishment-register-client-btn` |
| Add stamp | `#add-stamp-card`, `#add-stamp-progress`, `#add-stamp-button`, `#add-stamp-back-link` |

---

## 10. Implementation order (TDD)

1. **Fixtures and login helper** — `user_fixture`, `establishment_fixture`, etc.; `log_in_user(conn, user)`.
2. **Context: Accounts** — Already present; ensure coverage and given/when/then.
3. **Context: Establishments** — `list_establishments_by_user`, `create_establishment`, `get_establishment!` (scoped to user).
4. **Context: Loyalty** — Customer get_or_create, LoyaltyProgram, LoyaltyCard create/list, `add_stamp`, list by email and by establishment.
5. **LiveView: Public** — Landing, Meus cartões (entry + list). Use IDs from SCREENS.
6. **LiveView: User auth** — Register, login, logout; redirect when unauthenticated.
7. **LiveView: Establishments** — List, new, show (with scope check), program edit, cards index, add stamp, register client.
8. **Precommit** — Run `mix precommit`; fix compile, format, Credo, Sobelow, Dialyzer, tests, coverage.

---

## 11. Checklist before considering feature “done”

- [ ] All Context public functions have at least one test (given/when/then).
- [ ] All LiveView routes have mount (and relevant handle_params) tests.
- [ ] All forms and main actions (submit, click) have tests (render_submit, render_click).
- [ ] Assertions use `has_element?`, `element`, or similar; no brittle raw HTML.
- [ ] IDs / data-* from this plan and SCREENS are present in templates.
- [ ] Unauthenticated access to protected routes redirects to login.
- [ ] User can only see and act on their own establishments.
- [ ] `mix precommit` passes (compile, format, credo, sobelow, dialyzer, test, coverage).

---

*Test plan derived from [TDD.md](TDD.md), [SYSTEM_DESIGN.md](SYSTEM_DESIGN.md), [SCREENS.md](SCREENS.md), and [DEVELOPMENT.md](DEVELOPMENT.md).*
