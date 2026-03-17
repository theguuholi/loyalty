# MVP Backlog and Implementation Order

This document defines **what is still missing** to implement the MVP, **decisions** (router and auth), and the **recommended implementation order**. Use it together with [TDD](TDD.md), [SYSTEM_DESIGN](SYSTEM_DESIGN.md), [DESIGN](DESIGN.md), [SCREENS](SCREENS.md), and [TEST_PLAN](TEST_PLAN.md).

---

## 1. What is missing for implementation

| Area | Status | Notes |
|------|--------|--------|
| **Concept and product** | Done | CONCEPT.md, TDD.md. |
| **Architecture and flows** | Done | SYSTEM_DESIGN.md, prototype. |
| **Visual design** | Done | DESIGN.md (colors, layout). |
| **Screen specs** | Done | SCREENS.md (copy, fields, IDs). |
| **Dev premises** | Done | DEVELOPMENT.md (TDD, typespecs, precommit). |
| **Data layer** | To do | Migrations and schemas: establishments, loyalty_programs, customers, loyalty_cards (stamps optional). |
| **Contexts** | To do | Accounts (Establishment, auth), Loyalty (Customer, LoyaltyProgram, LoyaltyCard). |
| **Establishment auth** | To do | Separate from current User auth; routes under `/establishment/*`. |
| **Public LiveViews** | To do | Landing, Meus cartões (entry + list/empty). |
| **Establishment LiveViews** | To do | Login, Register, Dashboard, Program, Cards, Add stamp. |
| **Stripe** | To do | Checkout after register, webhooks (subscription, invoice). |
| **Tests** | To do | Context and LiveView tests per [TEST_PLAN](TEST_PLAN.md) (given/when/then, IDs). |

Optional but useful for implementation:

- **Stripe setup:** A short checklist (env vars, product/price IDs, webhook URL). Can live in TDD or a small `STRIPE_SETUP.md`.
- **Context API:** A one-page list of main public functions per context (e.g. `Accounts.get_establishment_by_email/1`, `Loyalty.add_stamp/1`) to align tests and callers. Can be derived from TDD and implemented as you go.

---

## 2. Router and auth decision

The app currently has **User** auth (phx.gen.auth) and routes like `/users/log-in`, `/users/register`. The MVP is about **Establishment** (shop owner) and **Customer** (no login; access by email).

**Decision for MVP:**

- **Keep** the existing User auth as-is (no need to remove it).
- **Add** a separate **Establishment** auth and scope:
  - New schema: `Establishment` (name, email, hashed_password, stripe fields).
  - New plugs and `live_session`: e.g. `:require_authenticated_establishment`, `:mount_current_establishment`.
  - All establishment routes under **`/establishment`**: login, register, dashboard, program, cards, add stamp.
- **Customer** does not log in; "Meus cartões" is public and only requires the customer to submit their email (see TDD and SCREENS).

So you will have two auth scopes: **User** (existing) and **Establishment** (new). The landing page links "Ver meus cartões" (public) and "Sou estabelecimento" (→ `/establishment/login`).

---

## 3. Implementation order

Follow this order so each step has the necessary foundation.

1. **Migrations and schemas**
   - `establishments` (name, email, hashed_password, stripe_customer_id, stripe_subscription_id, subscription_status, timestamps).
   - `loyalty_programs` (establishment_id, name, stamps_required, reward_description, timestamps).
   - `customers` (email unique, timestamps).
   - `loyalty_cards` (customer_id, establishment_id, stamps_current, stamps_required, timestamps; unique on [customer_id, establishment_id]).
   - Optional: `stamps` (loyalty_card_id, inserted_at).

2. **Context: Accounts**
   - Establishment CRUD, get by email, password hashing, session (register, login).
   - No Stripe yet; subscription_status can default to `"pending"` or `"inactive"`.

3. **Context: Loyalty**
   - LoyaltyProgram: get/create/update for an establishment.
   - Customer: get_or_create by email.
   - LoyaltyCard: create (when registering a client), list by customer, list by establishment, get by id; add_stamp (increment stamps_current).

4. **Establishment auth**
   - Plugs and live_session for establishment (similar to UserAuth but for Establishment).
   - Router: scope `/establishment`, pipe_through require_authenticated_establishment for dashboard/program/cards/add-stamp; public routes for login/register.

5. **Public LiveViews**
   - Landing (/) → CTA "Ver meus cartões" → /cards; link "Sou estabelecimento" → /establishment/login.
   - Meus cartões: entry (/cards) and result (list or empty) per SCREENS.md.

6. **Establishment LiveViews**
   - Login, Register (after submit → create establishment then redirect to Stripe Checkout when you integrate Stripe).
   - Dashboard, Program (edit loyalty_program), Cards (list + search + "Cadastrar cliente"), Add stamp (card detail + "+1 carimbo").

7. **Stripe**
   - Create product and price (BRL R$ 10/mês) in Stripe Dashboard.
   - After establishment register: create Checkout Session (subscription), redirect to Stripe; success/cancel URLs.
   - Webhook endpoint: verify signature; handle subscription and invoice events; update establishment subscription_status and stripe_subscription_id.
   - Optional: block dashboard actions if subscription is not active.

8. **Tests**
   - Context: Accounts and Loyalty (every public function, given/when/then, fixtures).
   - LiveView: at least landing, meus cartões (entry + list/empty), establishment login, dashboard, add stamp (critical path).
   - Run `mix precommit` and fix until all steps pass.

---

## 4. Checklist (from System Design, extended)

- [x] Concept, TDD, System Design, Design (colors/layout), Screens (spec), Development (premises)
- [ ] Migrations and schemas
- [ ] Contexts: Accounts, Loyalty
- [ ] Establishment auth and router
- [ ] Public LiveViews (landing, meus cartões)
- [ ] Establishment LiveViews (login, register, dashboard, program, cards, add stamp)
- [ ] Stripe (checkout + webhooks)
- [ ] Tests (context + LiveView); `mix precommit` passing

---

*Use this backlog to plan and track MVP implementation. Update the checklist as items are completed.*
