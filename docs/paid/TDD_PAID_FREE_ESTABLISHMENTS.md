# TDD: Estabelecimento pagante e não pagante (free tier)

Test-Driven Development plan for the feature described in [CONCEPT_PAID_FREE_ESTABLISHMENTS.md](./CONCEPT_PAID_FREE_ESTABLISHMENTS.md). Tests are written **first** (Red), then implementation (Green), then refactor. Naming follows **given / when / then**.

---

## Constants (use in code and tests)

| Constant | Value | Usage |
|----------|--------|--------|
| `Establishments.free_client_limit/0` | 20 | Max loyalty cards for a free establishment. |
| `Establishments.paid_client_limit/0` | 1000 | Max loyalty cards for a paid establishment. |
| “Active for billing” status | `"active"` | Only this `subscription_status` allows adding new clients for a paid establishment. |

---

## 1. Context: Establishments

### 1.1 Count loyalty cards by establishment

| # | Test name (given / when / then) | Notes |
|---|----------------------------------|--------|
| 1 | given an establishment with 5 loyalty cards when count_loyalty_cards(establishment_id) then returns 5 | Count by establishment_id. |
| 2 | given an establishment with no cards when count_loyalty_cards(establishment_id) then returns 0 | |
| 3 | given a nil or unknown id when count_loyalty_cards(id) then returns 0 or raises as decided | Define contract. |

### 1.2 Can add client? (limit check)

| # | Test name | Notes |
|---|-----------|--------|
| 4 | given a free establishment with 19 cards when can_add_client?(establishment) then returns true | |
| 5 | given a free establishment with 20 cards when can_add_client?(establishment) then returns false | |
| 6 | given a paid establishment (subscription_status active) with 999 cards when can_add_client?(establishment) then returns true | |
| 7 | given a paid establishment (active) with 1000 cards when can_add_client?(establishment) then returns false | |
| 8 | given a paid establishment with subscription_status past_due when can_add_client?(establishment) then returns false | Do not allow new clients when payment failed. |
| 9 | given a paid establishment with subscription_status unpaid when can_add_client?(establishment) then returns false | |
| 10 | given a paid establishment with subscription_status canceled when can_add_client?(establishment) then returns false (and treat as free limit 20) | Canceled = non-paying; still respect 20 limit for “free” behavior. |
| 11 | given a free establishment with 20 cards when can_add_client?(establishment) then returns false | Same as #5, explicit. |

### 1.3 User already has a free establishment?

| # | Test name | Notes |
|---|-----------|--------|
| 12 | given a user with no establishments when user_has_free_establishment?(user) then returns false | |
| 13 | given a user with one establishment (subscription_status nil) when user_has_free_establishment?(user) then returns true | nil or "free" = free. |
| 14 | given a user with one establishment (subscription_status "free") when user_has_free_establishment?(user) then returns true | |
| 15 | given a user with one establishment (subscription_status "active") when user_has_free_establishment?(user) then returns false | Only one establishment but it is paid. |
| 16 | given a user with two establishments (one nil, one active) when user_has_free_establishment?(user) then returns true | Has at least one free. |
| 17 | given a user with two establishments (both active) when user_has_free_establishment?(user) then returns false | No free. |

### 1.4 Create establishment (first = free, second = redirect to Stripe)

| # | Test name | Notes |
|---|-----------|--------|
| 18 | given a user with no establishments when create_establishment(user, %{name: "Café"}) then inserts establishment with subscription_status nil or "free" and returns {:ok, establishment} | First establishment is free; no Stripe redirect in context (handled in LiveView). |
| 19 | given a user with one free establishment when create_establishment(user, %{name: "Padaria"}) then inserts establishment and returns {:ok, establishment} | Second establishment is still “created” in DB; redirect to Stripe is LiveView responsibility (option B from concept). If option A: context may expose a function like can_create_free_establishment?(user) and LiveView blocks. |

### 1.5 Subscription status helpers (optional but useful)

| # | Test name | Notes |
|---|-----------|--------|
| 20 | given subscription_status "active" when active_for_billing?(status) then returns true | |
| 21 | given subscription_status "past_due" when active_for_billing?(status) then returns false | |
| 22 | given subscription_status nil when active_for_billing?(status) then returns false | Free. |
| 23 | given subscription_status "free" when active_for_billing?(status) then returns false | |

---

## 2. Context: Loyalty

### 2.1 create_loyalty_card with limits

| # | Test name | Notes |
|---|-----------|--------|
| 24 | given a free establishment with 19 cards and valid email when create_loyalty_card(establishment, email) then returns {:ok, card} | Under limit. |
| 25 | given a free establishment with 20 cards when create_loyalty_card(establishment, "new@example.com") then returns {:error, :client_limit_reached} or {:error, %Ecto.Changeset{}} with error tag | Do not insert 21st card. |
| 26 | given a paid establishment (active) with 1000 cards when create_loyalty_card(establishment, "new@example.com") then returns {:error, :client_limit_reached} (or equivalent) | Paid limit. |
| 27 | given a paid establishment (active) with 999 cards when create_loyalty_card(establishment, "new@example.com") then returns {:ok, card} | |
| 28 | given a paid establishment (subscription_status past_due) when create_loyalty_card(establishment, "new@example.com") then returns {:error, :payment_not_active} or :client_limit_reached equivalent | Do not allow new clients when payment not active. |
| 29 | given a paid establishment (subscription_status unpaid) when create_loyalty_card(establishment, "new@example.com") then returns {:error, :payment_not_active} | |
| 30 | given same establishment and existing customer email when create_loyalty_card(establishment, email) then returns {:ok, existing_card} (idempotent) | Already in concept: get or create card. |
| 31 | given a paid establishment (active) with 100 cards when create_loyalty_card(establishment, "new@example.com") then returns {:ok, card} | Happy path paid. |

---

## 3. Webhook: Stripe subscription status

| # | Test name | Notes |
|---|-----------|--------|
| 32 | given valid signature and event customer.subscription.updated with status past_due when POST /webhooks/stripe then establishment subscription_status is updated to past_due | |
| 33 | given valid signature and event customer.subscription.updated with status unpaid when POST /webhooks/stripe then establishment subscription_status is updated to unpaid | |
| 34 | given valid signature and event customer.subscription.updated with status active when POST /webhooks/stripe then establishment subscription_status is updated to active | |
| 35 | given valid signature and event customer.subscription.deleted when POST /webhooks/stripe then establishment subscription_status is updated to canceled | Already may exist; ensure status value is persisted. |

---

## 4. LiveView: Establishment new (create flow)

| # | Test name | Notes |
|---|-----------|--------|
| 36 | given authenticated user with no establishments when they submit form with name then establishment is created with subscription_status nil (or "free") and they are redirected to show (no Stripe redirect) | First establishment = free, no redirect. |
| 37 | given authenticated user with one free establishment when they submit form with name then establishment is created and they are redirected to Stripe (external redirect) | Option B: second establishment goes to Stripe. |
| 38 | given authenticated user with one paid establishment when they submit form with name then establishment is created and they are redirected to Stripe | No free slot; must pay for new one. |

(If **option A** for second establishment: replace 37 with: given user with one free establishment when they visit /establishments/new then they see message "No plano gratuito você pode ter apenas 1 estabelecimento" and CTA Assinar; form submit may be disabled or show same message.)

---

## 5. LiveView: Cards index (add client)

| # | Test name | Notes |
|---|-----------|--------|
| 39 | given free establishment with 20 cards when user submits add-client form with new email then they see error message (limit reached) and CTA "Assinar" | Use stable ID for form and message, e.g. #cards-add-client-form, #cards-limit-reached. |
| 40 | given free establishment with 19 cards when user submits add-client form with valid email then card is created and they see it in the list | |
| 41 | given paid establishment (active) with 1000 cards when user submits add-client form then they see limit message (no new client) | |
| 42 | given paid establishment (past_due) when user visits cards page then they see banner "Pagamento pendente" and add-client form submit is disabled or returns limit error | |
| 43 | given paid establishment (active) with 50 cards when user submits add-client form with valid email then card is created | Happy path. |

---

## 6. LiveView: Add stamp (stamp allowed for existing cards when past_due?)

| # | Test name | Notes |
|---|-----------|--------|
| 44 | given paid establishment (past_due) and existing loyalty card when user clicks add stamp then stamp is added (allow stamp for existing clients) | Per concept suggestion: block only new clients. |
| 45 | given free establishment with 20 cards when user adds stamp to existing card then stamp is added | No block for stamping. |

---

## 7. LiveView: Show establishment (banner / CTA)

| # | Test name | Notes |
|---|-----------|--------|
| 46 | given free establishment when user visits show page then they see plan indicator (e.g. "Plano gratuito" or "15/20 clientes") | |
| 47 | given free establishment at 20 clients when user visits show page then they see CTA "Assinar por R$ 10/mês" | |
| 48 | given paid establishment (past_due) when user visits show page then they see banner "Pagamento pendente" or "Problema no pagamento" | |
| 49 | given paid establishment (active) when user visits show page then they see plan indicator (e.g. "Plano pago" or "X/1000 clientes") and no payment warning | |

---

## 8. Order of implementation (TDD)

1. **Establishments context:** count_loyalty_cards, can_add_client?, user_has_free_establishment?, active_for_billing? (if used). Then create_establishment behavior (first free) and any helper for “second goes to Stripe”.
2. **Loyalty context:** in create_loyalty_card, add limit and payment checks; return {:error, :client_limit_reached} or {:error, :payment_not_active}.
3. **Webhook:** extend StripeWebhookController to persist subscription status (past_due, unpaid, canceled) from customer.subscription.updated / deleted.
4. **LiveView New:** change flow so first establishment does not redirect to Stripe; second (or when user already has free) redirects to Stripe.
5. **LiveView Cards index:** handle limit and payment errors in UI; show CTA Assinar when limit reached (free) or payment not active (paid).
6. **LiveView Show:** show plan indicator and payment banner (past_due/unpaid).
7. **Add stamp:** ensure add_stamp is allowed for existing cards when establishment is past_due (no extra block).

---

## 9. Fixtures and test data

- **establishment_fixture(attrs):** allow `subscription_status: "active" | "free" | nil | "past_due" | "unpaid" | "canceled"`.
- **loyalty_card_fixture(attrs):** link to establishment; use to build 20 or 1000 cards for limit tests (or use loop in test).
- **User with N establishments:** use Establishments.create_establishment or fixture in setup; set subscription_status per scenario.

---

## 10. IDs and selectors (for LiveView tests)

| Element | Selector / ID | Use in |
|---------|----------------|--------|
| Add client form | `#cards-add-client-form` or equivalent | cards_index |
| Limit reached message | `#cards-limit-reached` or `[data-role=limit-reached]` | cards_index |
| CTA Assinar | `#establishment-subscribe-cta` or link text "Assinar" | show, cards_index |
| Plan indicator (free) | `[data-plan=free]` or `#establishment-plan-free` | show |
| Payment warning banner | `#payment-pending-banner` or `[data-role=payment-pending]` | show, cards_index |

Define exact IDs in SCREENS or in this doc and keep them stable for tests.
