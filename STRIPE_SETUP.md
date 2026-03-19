# Stripe billing setup

This app charges **per establishment** with a monthly subscription. The **free tier** allows up to 20 loyalty cards (clients) per establishment; the **paid tier** allows up to 1000. The **first** establishment per user is free; creating a **second** establishment requires an active subscription.

## Environment variables

Set these in development (e.g. `.env` or `config/dev.exs`) and in production (e.g. runtime env or secrets):

| Variable | Description |
|----------|-------------|
| `STRIPE_SECRET_KEY` | Stripe secret key (e.g. `sk_test_...` or `sk_live_...`) |
| `STRIPE_WEBHOOK_SECRET` | Signing secret for the webhook endpoint (e.g. `whsec_...`) |
| `STRIPE_PRICE_ID` | ID of the **recurring monthly** Price (e.g. `price_...`) |

Without `STRIPE_SECRET_KEY` and `STRIPE_PRICE_ID`, the “Subscribe” button will show an error. Without `STRIPE_WEBHOOK_SECRET`, webhook requests will be rejected (503).

## Creating the product and price in Stripe

1. In [Stripe Dashboard](https://dashboard.stripe.com/) go to **Products** and create a product (e.g. “Monthly plan per establishment”).
2. Add a **recurring** price (e.g. monthly in BRL or your currency).
3. Copy the **Price ID** (e.g. `price_xxxxxxxx`) into `STRIPE_PRICE_ID`.

## Webhook endpoint

The app receives Stripe events at:

- **URL:** `POST /webhooks/stripe`
- **Full URL (production):** `https://your-domain.com/webhooks/stripe`

### Configuring the webhook in Stripe

1. In Stripe Dashboard go to **Developers → Webhooks** and add an endpoint with the URL above.
2. Subscribe to at least:
   - `checkout.session.completed`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
3. Copy the **Signing secret** (`whsec_...`) into `STRIPE_WEBHOOK_SECRET`.

### Local development with Stripe CLI

To test webhooks locally:

1. Install [Stripe CLI](https://stripe.com/docs/stripe-cli).
2. Run: `stripe listen --forward-to localhost:4000/webhooks/stripe`
3. Use the printed signing secret (e.g. `whsec_...`) as `STRIPE_WEBHOOK_SECRET` in your dev config.

## Flow (overview)

```text
User clicks “Subscribe” on establishment
    → App creates Stripe Checkout Session (subscription mode)
    → User is redirected to Stripe to pay
    → After success, Stripe sends checkout.session.completed
    → Webhook receives event, verifies signature, updates establishment
        (stripe_customer_id, stripe_subscription_id, subscription_status = "active")
    → User is redirected back to establishment page; new clients can be added up to the paid limit
```

Subscription status is kept in sync via `customer.subscription.updated` and `customer.subscription.deleted`; `past_due` / `unpaid` / `canceled` block new client registration but allow stamping existing cards.
