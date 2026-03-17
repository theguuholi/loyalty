# System Design: Estabelecimento pagante e não pagante (free tier)

High-level architecture and design for the feature described in [CONCEPT_PAID_FREE_ESTABLISHMENTS.md](./CONCEPT_PAID_FREE_ESTABLISHMENTS.md). Complements [TDD_PAID_FREE_ESTABLISHMENTS.md](./TDD_PAID_FREE_ESTABLISHMENTS.md) and [TEST_PLAN_PAID_FREE_ESTABLISHMENTS.md](./TEST_PLAN_PAID_FREE_ESTABLISHMENTS.md).

---

## 1. Goals and constraints

- **Goal:** Introduce free tier (1 establishment, 20 clients) and paid tier (R$ 10/month recurring, 1000 clients); enforce limits and payment status before allowing new clients.
- **Constraints:** Reuse existing Stripe Checkout and webhook; minimal schema change (subscription_status already exists); no new infrastructure.

---

## 2. Architecture overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Browser (User)                                  │
└─────────────────────────────────────────────────────────────────────────┘
    │
    │ HTTP / LiveView
    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        MyRewardsWeb (Phoenix)                             │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────┐  │
│  │ EstablishmentLive│  │ StripeWebhook    │  │ PageController (e.g.  │  │
│  │ New / Show /     │  │ Controller       │  │ cards, home)          │  │
│  │ CardsIndex /     │  │ POST /webhooks/  │  │                       │  │
│  │ AddStampShow     │  │ stripe           │  │                       │  │
│  └────────┬─────────┘  └────────┬─────────┘  └───────────────────────┘  │
│           │                     │                                         │
└───────────┼─────────────────────┼───────────────────────────────────────┘
            │                     │
            ▼                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Contexts (Business logic)                          │
│  ┌────────────────────────────┐  ┌────────────────────────────────────┐ │
│  │ Establishments             │  │ Loyalty                             │ │
│  │ - count_loyalty_cards/1     │  │ - create_loyalty_card/2             │ │
│  │ - can_add_client?/1         │  │   (checks limit + payment status    │ │
│  │ - user_has_free_establishment?/1│   via Establishments)              │ │
│  │ - create_establishment/2    │  │ - add_stamp/1                       │ │
│  │ - update_subscription_attrs/2│  │ - list_loyalty_cards_by_establishment│ │
│  │ - get_establishment_by_      │  └────────────────────────────────────┘ │
│  │   stripe_subscription_id/1  │                                          │
│  └────────────────────────────┘  ┌────────────────────────────────────┐ │
│                                   │ Stripe (module)                      │ │
│                                   │ - create_checkout_session/3           │ │
│                                   │ - verify_webhook_signature/2          │ │
│                                   └────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Repo (Ecto) + PostgreSQL                          │
│  establishments (id, name, user_id, stripe_*, subscription_status)      │
│  loyalty_cards (id, establishment_id, customer_id, stamps_*)              │
│  loyalty_programs, customers, users, users_tokens                          │
└─────────────────────────────────────────────────────────────────────────┘

            ▲
            │ Webhooks (POST)
┌───────────┴───────────┐
│ Stripe (external)     │  checkout.session.completed, customer.subscription.*
└──────────────────────┘
```

---

## 3. Data model

### 3.1 Existing tables (relevant fields)

- **establishments**
  - `id`, `name`, `user_id`
  - `stripe_customer_id`, `stripe_subscription_id`, `subscription_status` (string, nullable)
- **loyalty_cards**
  - `id`, `establishment_id`, `customer_id`, `stamps_current`, `stamps_required`

No new tables. Use `subscription_status` to derive:
- **Free:** `subscription_status` in `[nil, "free"]` and no `stripe_subscription_id` (or subscription canceled).
- **Paid (active):** `subscription_status == "active"`.
- **Paid (not active):** `subscription_status` in `["past_due", "unpaid", "canceled", "canceled_at_period_end"]`; treat as “cannot add new client” and, for canceled, as free (limit 20).

### 3.2 Constants (in code)

| Constant | Value | Module |
|----------|--------|--------|
| Free client limit | 20 | Establishments (e.g. `@free_client_limit 20`) |
| Paid client limit | 1000 | Establishments (e.g. `@paid_client_limit 1000`) |
| Status “active for billing” | `"active"` | Establishments (e.g. `active_for_billing?(status)`) |

---

## 4. Component design

### 4.1 Establishments context

| Function | Purpose | Returns / side effect |
|----------|---------|----------------------|
| `count_loyalty_cards(establishment_id)` | Count loyalty_cards for establishment | non_neg_integer() |
| `can_add_client?(establishment)` | Can we add a new loyalty card? (limit + payment status) | boolean() |
| `user_has_free_establishment?(user)` | Does user have at least one establishment with free status (nil/"free")? | boolean() |
| `active_for_billing?(subscription_status)` | Is status "active"? | boolean() |
| `create_establishment(user, attrs)` | Create establishment; no Stripe call (LiveView decides redirect) | {:ok, establishment} \| {:error, changeset} |
| `update_subscription_attrs(id, attrs)` | Already exists; used by webhook | {:ok, establishment} \| {:error, changeset} |
| `get_establishment_by_stripe_subscription_id(sub_id)` | Already exists; used by webhook | establishment \| nil |

**Limit logic inside `can_add_client?/1`:**
- If establishment is free (subscription_status nil or "free"): return `count_loyalty_cards(establishment.id) < 20`.
- If establishment is paid: return `active_for_billing?(establishment.subscription_status) and count_loyalty_cards(establishment.id) < 1000`.
- If subscription_status is canceled (or deleted): treat as free (limit 20).

### 4.2 Loyalty context

| Function | Change | Purpose |
|----------|--------|---------|
| `create_loyalty_card(establishment, customer_email)` | Add guard | Before insert: call `Establishments.can_add_client?(establishment)`. If false, return `{:error, :client_limit_reached}` or `{:error, :payment_not_active}` (depending on whether limit or payment status). Load establishment if only id is passed. |

**Error semantics:**
- `{:error, :client_limit_reached}` — at 20 (free) or 1000 (paid), or over.
- `{:error, :payment_not_active}` — subscription_status not active (past_due, unpaid, canceled). UI can show “Regularize pagamento” or “Assinar”.

### 4.3 Stripe module

No API change. Existing:
- `create_checkout_session(establishment_id, success_url, cancel_url)` — used for “new paid establishment” and “migrate free → paid”.
- `verify_webhook_signature(raw_body, signature)` — used by webhook.

### 4.4 Stripe webhook controller

| Event | Current behavior | Change |
|-------|-------------------|--------|
| `checkout.session.completed` | Set stripe_subscription_id, subscription_status = "active" | Keep. |
| `customer.subscription.updated` | Update establishment by stripe_subscription_id with sub["status"] | Persist full status: active, past_due, unpaid, canceled, canceled_at_period_end. |
| `customer.subscription.deleted` | Set subscription_status = "canceled" | Keep. |
| `invoice.payment_failed` | No DB change | Keep (optional: send email later). |

Raw body must remain available (RawBodyPlug) for signature verification.

### 4.5 LiveView: EstablishmentLive.New

| Scenario | Current behavior | New behavior |
|----------|-------------------|--------------|
| User has 0 establishments | Create establishment → redirect to Stripe | Create establishment with subscription_status nil (or "free") → redirect to show (no Stripe). |
| User has ≥1 free establishment | (N/A) | Create establishment → redirect to Stripe (option B); establishment created in DB, then redirect to checkout with this establishment_id as client_reference_id. |
| User has only paid establishments | Create establishment → redirect to Stripe | Unchanged. |

Flow:
1. **Before** create: `existing_count = length(Establishments.list_establishments_by_user(user))`.
2. On submit: `Establishments.create_establishment(user, params)`.
3. If success: if `existing_count == 0` → first establishment → free (no Stripe), `push_navigate` to show. Else → `Stripe.create_checkout_session(establishment.id, success_url, cancel_url)` → `redirect(socket, external: url)`.

The decision uses how many establishments the user had **before** this create. `user_has_free_establishment?/1` remains useful elsewhere (e.g. UI when user already has a free establishment).

Wait: after create, the new establishment is “free” (subscription_status nil). So “user has free” after creating one is true. So we need: “if user had 0 establishments before this create” → free, no Stripe. “If user had ≥1 establishment before this create” → go to Stripe. So the condition is: before create, `list_establishments_by_user(user)` length == 0 → first establishment → free, redirect to show. Else → redirect to Stripe. So no need for `user_has_free_establishment?` in this flow; we only need “is this the first establishment?” (count before create). Document this in system design.

### 4.6 LiveView: EstablishmentLive.Show

- Assign: `plan_type`: `:free` or `:paid` (derived from subscription_status).
- Assign: `client_count` and `client_limit` (20 or 1000) for display “X/20” or “X/1000”.
- Assign: `payment_pending`: true if subscription_status in ["past_due", "unpaid"] (show banner).
- If free and client_count == 20: show CTA “Assinar” (link or button that goes to Checkout with this establishment_id).
- If paid and payment_pending: show banner “Pagamento pendente” (and optional link to Stripe Portal later).

### 4.7 LiveView: EstablishmentLive.CardsIndex

- On mount: load establishment; compute can_add_client (Establishments.can_add_client?(establishment)); assign for UI (disable form or show message when false).
- On “add client” submit: call Loyalty.create_loyalty_card(establishment, email). On {:error, :client_limit_reached} or {:error, :payment_not_active}, put_flash and/or assign error message; show CTA “Assinar” when limit reached (free) or “Regularize pagamento” when payment not active.
- Display client count and limit (e.g. “18/20” or “50/1000”).

### 4.8 LiveView: AddStampShow

- No change to add_stamp logic: allow adding stamp to existing card even when establishment is past_due (per concept: only block “add new client”). If in the future we block all actions when unpaid, add a check here.

---

## 5. Flows (sequence)

### 5.1 Create first establishment (free)

1. User (authenticated) → GET /establishments/new.
2. User submits form (name) → LiveView handle_event "save".
3. Establishments.create_establishment(user, params) → {:ok, establishment} (subscription_status nil).
4. LiveView: list_establishments_by_user(user) was 0 before create → push_navigate to ~p"/establishments/#{establishment.id}".
5. No call to Stripe.

### 5.2 Create second establishment (option B: go to Stripe)

1. User already has one establishment (free). Submits new establishment form.
2. Establishments.create_establishment(user, params) → {:ok, establishment}.
3. LiveView: count establishments for user >= 1 (so not first) → create_checkout_session(establishment.id, success_url, cancel_url) → redirect(external: checkout_url).
4. User pays on Stripe; Stripe sends checkout.session.completed; webhook sets stripe_subscription_id and subscription_status = "active".
5. User lands on success_url (show page); establishment is now paid.

### 5.3 Add client (free, at limit)

1. User on cards index; establishment free with 20 cards.
2. User submits email for new client.
3. Loyalty.create_loyalty_card(establishment, email) → Establishments.can_add_client?(establishment) = false → returns {:error, :client_limit_reached}.
4. LiveView: put_flash error, assign message “Limite de 20 clientes no plano gratuito. Assine por R$ 10/mês para cadastrar mais.” and show CTA “Assinar” (navigate to checkout with establishment_id or show page with CTA).

### 5.4 Add client (paid, past_due)

1. Establishment has subscription_status "past_due".
2. User submits new client.
3. can_add_client? returns false (payment not active) → create_loyalty_card returns {:error, :payment_not_active}.
4. LiveView shows message “Pagamento pendente. Atualize sua forma de pagamento para continuar cadastrando novos clientes.” and optional banner.

### 5.5 Webhook: subscription.updated (past_due)

1. Stripe POST /webhooks/stripe with customer.subscription.updated, data.object.status = "past_due".
2. Controller verifies signature, parses event, calls handle_event.
3. update_establishment_status_by_subscription_id(sub_id, "past_due") → Establishments.update_subscription_attrs(establishment.id, %{subscription_status: "past_due"}).
4. Next request: can_add_client? for that establishment returns false.

---

## 6. Boundaries and errors

| Boundary | Error / edge | Handling |
|----------|--------------|----------|
| Loyalty.create_loyalty_card | :client_limit_reached | LiveView: flash + message + CTA Assinar (if free) or “Limite atingido” (if paid). |
| Loyalty.create_loyalty_card | :payment_not_active | LiveView: flash + message “Regularize pagamento” + optional banner. |
| Establishments.create_establishment | Validation errors | Existing: assign form with errors. |
| Webhook | Invalid signature | 401, no DB change. |
| Webhook | Unknown event type | 200, no DB change. |

---

## 7. Configuration and env

- Stripe: `STRIPE_SECRET_KEY`, `STRIPE_PRICE_ID`, `STRIPE_WEBHOOK_SECRET` (existing).
- No new env vars for limits (constants in code).

---

## 8. Security and idempotency

- Webhook: always verify Stripe-Signature; use raw body.
- create_loyalty_card: establishment must belong to current user when called from LiveView (already enforced by loading establishment by user scope).
- No new endpoints; existing auth and scope rules apply.

---

## 9. References

- [CONCEPT_PAID_FREE_ESTABLISHMENTS.md](./CONCEPT_PAID_FREE_ESTABLISHMENTS.md)
- [TDD_PAID_FREE_ESTABLISHMENTS.md](./TDD_PAID_FREE_ESTABLISHMENTS.md)
- [TEST_PLAN_PAID_FREE_ESTABLISHMENTS.md](./TEST_PLAN_PAID_FREE_ESTABLISHMENTS.md)
- [DEVELOPMENT.md](./mvp/DEVELOPMENT.md)
