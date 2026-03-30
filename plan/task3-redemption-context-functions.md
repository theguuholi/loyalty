# Task 3: Add Redemption Context Functions to LoyaltyCards

## Why these functions exist

### `redeem_card/2`
Encapsulates the atomic business operation of redeeming a loyalty card. This function owns the
transaction logic: inserting a `Redemption` record (which is the permanent audit trail of the
reward being claimed) and simultaneously decrementing the card's stamp count. It also broadcasts
the update via PubSub so any subscribed LiveViews refresh in real time.

### `list_redemptions_for_card/1`
A display-only query that returns all redemptions for a given card, ordered newest-first. No
scope required since this is used purely for showing history — authorization is handled at the
LiveView/controller level before calling this function.

### `redemption_counts_for_establishment/1`
An aggregation query that answers "how many redemptions has each card had?" for an entire
establishment. Using `GROUP BY loyalty_card_id` + `COUNT` at the database level is efficient and
avoids loading all redemption rows into memory. The result is a plain map for easy lookup in
templates.

## Migration / schema changes
No new migrations needed. The `redemptions` table and `Redemption` schema already exist.

## Implementation steps
1. Add `Loyalty.LoyaltyCards.Redemption` to the alias block in `loyalty_cards.ex`
2. Implement `redeem_card/2` with:
   - Ownership assertion
   - `Repo.preload` to ensure `:loyalty_program` is loaded
   - `Repo.transaction` wrapping insert + update
   - `broadcast_loyalty_card` on success
3. Implement `list_redemptions_for_card/1` with a simple ordered query
4. Implement `redemption_counts_for_establishment/1` with GROUP BY + COUNT query returning a map
