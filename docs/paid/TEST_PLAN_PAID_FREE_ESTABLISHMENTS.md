# Test Plan: Estabelecimento pagante e não pagante (free tier)

Test plan for the feature described in [CONCEPT_PAID_FREE_ESTABLISHMENTS.md](./CONCEPT_PAID_FREE_ESTABLISHMENTS.md). Covers automated tests (Context + LiveView), manual checks, and acceptance criteria. TDD cases are listed in [TDD_PAID_FREE_ESTABLISHMENTS.md](./TDD_PAID_FREE_ESTABLISHMENTS.md).

---

## 1. Scope

### In scope

- Limits: free = 1 establishment per user, 20 clients per free establishment; paid = 1000 clients per establishment.
- Creation flow: first establishment free (no Stripe redirect); second establishment (or when user already has free) goes to Stripe.
- Adding client: blocked when at limit (20 for free, 1000 for paid) or when subscription_status is not active (past_due, unpaid, canceled).
- Webhook: persist subscription_status (active, past_due, unpaid, canceled) from Stripe events.
- UI: plan indicator (free/paid), client count, CTA “Assinar” when limit reached or payment not active; payment warning banner for past_due/unpaid.
- Add stamp: allowed for existing cards even when past_due (only “add new client” blocked).

### Out of scope (for this plan)

- Stripe Customer Portal link (optional; can be added later).
- E-mail notification on invoice.payment_failed (optional).
- Grace period logic (assume: only active allows new clients).

---

## 2. Test levels

| Level | Description | Owner |
|-------|-------------|--------|
| **Unit / Context** | Establishments and Loyalty functions: count, can_add_client?, user_has_free_establishment?, create_loyalty_card with limits and payment checks. | Automated (ExUnit) |
| **Integration** | Webhook: POST /webhooks/stripe with subscription.updated / subscription.deleted; assert DB subscription_status. | Automated (ExUnit) |
| **LiveView** | Mount and handle_event for New, Show, Cards index, Add stamp: redirects, messages, banners, form submit. | Automated (Phoenix.LiveViewTest) |
| **Manual / E2E** | Full flow: create account → create first establishment (free) → add 20 clients → see limit → migrate to paid (Stripe test mode); create second establishment (Stripe); simulate past_due (Stripe dashboard or test clock). | Manual / E2E later |

---

## 3. Test cases summary

### 3.1 Context: Establishments

| ID | Scenario | Expected result | Ref (TDD) |
|----|----------|-----------------|-----------|
| E1 | count_loyalty_cards with 0, 5, 20 cards | Returns 0, 5, 20 | §1.1 |
| E2 | can_add_client? free with 19 / 20 cards | true, false | §1.2 |
| E3 | can_add_client? paid (active) with 999 / 1000 cards | true, false | §1.2 |
| E4 | can_add_client? paid with past_due / unpaid / canceled | false | §1.2 |
| E5 | user_has_free_establishment? with 0, 1 free, 1 paid, mixed | As per concept | §1.3 |
| E6 | create_establishment first time | Establishment with subscription_status nil/"free" | §1.4 |
| E7 | active_for_billing? for active, past_due, nil, free | true only for active | §1.5 |

### 3.2 Context: Loyalty

| ID | Scenario | Expected result | Ref (TDD) |
|----|----------|-----------------|-----------|
| L1 | create_loyalty_card free 19 → 20th | {:ok, card} | §2.1 |
| L2 | create_loyalty_card free 20 → 21st | {:error, :client_limit_reached} (or changeset error) | §2.1 |
| L3 | create_loyalty_card paid (active) 999 → 1000th | {:ok, card} | §2.1 |
| L4 | create_loyalty_card paid (active) 1000 → 1001st | {:error, :client_limit_reached} | §2.1 |
| L5 | create_loyalty_card paid (past_due / unpaid) | {:error, :payment_not_active} or equivalent | §2.1 |
| L6 | create_loyalty_card same customer again | {:ok, existing_card} (idempotent) | §2.1 |

### 3.3 Webhook

| ID | Scenario | Expected result | Ref (TDD) |
|----|----------|-----------------|-----------|
| W1 | customer.subscription.updated status active / past_due / unpaid | subscription_status updated in DB | §3 |
| W2 | customer.subscription.deleted | subscription_status = canceled | §3 |
| W3 | Invalid signature | 401, no DB change | Existing |

### 3.4 LiveView: New establishment

| ID | Scenario | Expected result | Ref (TDD) |
|----|----------|-----------------|-----------|
| V1 | User has 0 establishments, submits form | Create free establishment, redirect to show (no Stripe) | §4 |
| V2 | User has 1 free establishment, submits form | Create establishment, redirect to Stripe (option B) | §4 |
| V3 | User has 1 paid establishment, submits form | Create establishment, redirect to Stripe | §4 |

### 3.5 LiveView: Cards index (add client)

| ID | Scenario | Expected result | Ref (TDD) |
|----|----------|-----------------|-----------|
| V4 | Free, 20 cards, submit new email | Error message + CTA Assinar, no new card | §5 |
| V5 | Free, 19 cards, submit valid email | Card created, visible in list | §5 |
| V6 | Paid (active), 1000 cards, submit new email | Limit message, no new card | §5 |
| V7 | Paid (past_due), visit cards page | Banner “Pagamento pendente”, add client blocked or error on submit | §5 |
| V8 | Paid (active), 50 cards, submit valid email | Card created | §5 |

### 3.6 LiveView: Show establishment

| ID | Scenario | Expected result | Ref (TDD) |
|----|----------|-----------------|-----------|
| V9 | Free establishment | Plan indicator (free), client count X/20 | §7 |
| V10 | Free at 20 clients | CTA “Assinar” visible | §7 |
| V11 | Paid (past_due) | Banner payment pending | §7 |
| V12 | Paid (active) | Plan indicator (paid), no payment banner | §7 |

### 3.7 LiveView: Add stamp

| ID | Scenario | Expected result | Ref (TDD) |
|----|----------|-----------------|-----------|
| V13 | Paid (past_due), add stamp to existing card | Stamp added | §6 |
| V14 | Free, 20 cards, add stamp to existing card | Stamp added | §6 |

---

## 4. Test data and fixtures

- **Users:** use AccountsFixtures / user_fixture; optionally user with password for LiveView auth.
- **Establishments:** establishment_fixture with subscription_status: nil | "free" | "active" | "past_due" | "unpaid" | "canceled"; optionally stripe_subscription_id for paid.
- **Loyalty cards:** loyalty_card_fixture linked to establishment; for “20 cards” or “1000 cards” use Enum.map or helper (e.g. many_cards_fixture(establishment_id, count)).
- **Stripe webhook:** sign payload with STRIPE_WEBHOOK_SECRET; send customer.subscription.updated with body containing data.object.status.

---

## 5. DOM IDs and selectors (for automation)

| Purpose | Selector / ID | Used in |
|---------|----------------|---------|
| New establishment form | `#establishment-form` or `#new-establishment-form` | new_test.exs |
| Cards add-client form | `#cards-add-client-form` | cards_index_test.exs |
| Limit reached message | `#cards-limit-reached` or `[data-role=limit-reached]` | cards_index_test.exs |
| CTA Assinar | `#establishment-subscribe-cta` or link "Assinar" | show_test.exs, cards_index_test.exs |
| Plan indicator free | `[data-plan=free]` or `#establishment-plan-free` | show_test.exs |
| Payment pending banner | `#payment-pending-banner` or `[data-role=payment-pending]` | show_test.exs, cards_index_test.exs |
| Add stamp button | Existing selector in add_stamp_show_test | add_stamp_show_test.exs |

Keep these consistent with LiveView templates and TDD doc.

---

## 6. Execution order (automated)

1. Context tests: Establishments (count, can_add_client?, user_has_free_establishment?, create behavior, active_for_billing?).
2. Context tests: Loyalty (create_loyalty_card with limits and payment status).
3. Webhook tests: StripeWebhookController subscription.updated / deleted.
4. LiveView tests: New (redirect free vs Stripe).
5. LiveView tests: Cards index (limit and payment messages, form submit).
6. LiveView tests: Show (banner, plan indicator, CTA).
7. LiveView tests: Add stamp (existing card when past_due).

Run: `mix test test/my_rewards/establishments_test.exs test/my_rewards/loyalty_test.exs test/my_rewards_web/controllers/stripe_webhook_controller_test.exs test/my_rewards_web/live/establishment_live/` (adjust paths to actual test files).

---

## 7. Manual / acceptance checklist

- [ ] Create first establishment: no redirect to Stripe; establishment appears with “free” or no subscription; can add up to 20 clients.
- [ ] Add 21st client on free: error message and “Assinar” CTA; no new card.
- [ ] Click “Assinar” on free establishment: redirect to Stripe Checkout; after payment (test card), establishment shows as paid and can add more clients (up to 1000).
- [ ] Create second establishment (user already has one free): redirect to Stripe (option B); after payment, new establishment is paid.
- [ ] Simulate past_due (Stripe test clock or dashboard): establishment shows payment banner; cannot add new client; can add stamp to existing card.
- [ ] Webhook subscription.deleted: establishment subscription_status becomes canceled; treated as free (limit 20 for new clients).

---

## 8. Coverage and precommit

- All new Context and LiveView code must be covered; no new code in `.test_coverage_ignore.exs` without justification.
- `mix precommit` must pass (format, credo, sobelow, dialyzer, tests, coverage threshold).

---

## 9. References

- [CONCEPT_PAID_FREE_ESTABLISHMENTS.md](./CONCEPT_PAID_FREE_ESTABLISHMENTS.md) — business rules and gaps.
- [TDD_PAID_FREE_ESTABLISHMENTS.md](./TDD_PAID_FREE_ESTABLISHMENTS.md) — TDD test list (given/when/then).
- [SYSTEM_DESIGN_PAID_FREE_ESTABLISHMENTS.md](./SYSTEM_DESIGN_PAID_FREE_ESTABLISHMENTS.md) — architecture and flows.
- [DEVELOPMENT.md](./mvp/DEVELOPMENT.md) — TDD and test conventions (given/when/then, has_element?, etc.).
