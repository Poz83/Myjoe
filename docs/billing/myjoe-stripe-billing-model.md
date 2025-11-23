# My Joe – Stripe Billing Model (v1)

This file explains how **Stripe** fits into My Joe’s billing, in plain language. Stripe handles **money**; My Joe’s database handles **credits and usage**.

---

## 1. Goals

- Users pay for **plans** (Lite / Pro / Max) on a **monthly subscription**.
- Plans grant a **bundle of credits** each month (e.g. 115 / 375 / 800).
- Users can also buy **one-off credit top-ups**.
- Stripe is the source of truth for **payments**; Postgres (Supabase) is the source of truth for **credits and usage**.

We use Stripe’s standard objects:

- **Product** – “What are you selling?” (e.g. “My Joe – Pro Plan”).
- **Price** – “How much and how often?” (e.g. £29.99/month).
- **Customer** – represents one My Joe user in Stripe.
- **Subscription** – link between a Customer and a recurring Price.
- **PaymentIntent / Invoice** – Stripe’s way of tracking payments.
- **Webhook** – Stripe sends us events when something important happens (invoice paid, subscription updated, etc.).

---

## 2. Stripe objects for My Joe

### 2.1 Subscription plans

We model each plan as:

- **One Stripe Product** per plan.
- **One Stripe Price** per plan (monthly, recurring).

Example (IDs are placeholders; we will fill real ones from Stripe later):

| Plan ID | DB `plans.id` | Stripe Product (example)    | Stripe Price (example)          | Notes                     |
|--------:|----------------|-----------------------------|----------------------------------|---------------------------|
| lite    | lite           | prod_lite_xxxxx             | price_lite_monthly_xxxxx         | ~115 credits / month      |
| pro     | pro            | prod_pro_xxxxx              | price_pro_monthly_xxxxx          | ~375 credits / month      |
| max     | max            | prod_max_xxxxx              | price_max_monthly_xxxxx          | ~800 credits / month      |

Stripe docs: see the **Products & Prices** guide for creating products and setting up recurring prices. We follow the standard “one product per plan, one price per plan” pattern (monthly).  

Later we can store the real Stripe IDs either:

- As extra columns in `plans` (e.g. `stripe_product_id`, `stripe_price_id`), or  
- In app config / environment variables.

For now, this doc is the “contract” we keep up to date manually.

### 2.2 Credit top-ups

Top-ups are **one-time purchases**:

- **One Product**: e.g. “My Joe – Credit Top-up (100 credits)”.
- **One Price**: e.g. £X for 100 credits, one-time (no recurrence).

We may add more sizes later (100, 250, 500, etc.), each as a separate Price (or Product+Price pair). The important bit:

- When Stripe tells us (via webhook) that a **top-up invoice is paid**, we add a **positive** entry in `credit_ledger` with `reason='topup'` and `delta_credits = N`.

---

## 3. Hybrid model: Stripe money, My Joe credits

We deliberately **do not** try to make Stripe “understand” our screenshot/credits rules. Instead:

- Stripe knows:
  - How much each plan costs per month.
  - How much each top-up pack costs.
  - When an invoice is paid or fails.
  - When a subscription is created / updated / canceled.

- My Joe knows:
  - How many credits to grant per plan per billing period.
  - How many credits a top-up is worth.
  - How many credits each operation consumes (raster, vector, fix/upscale).
  - How many credits a user currently has (sum of the ledger).

This separation is a **design choice** to keep My Joe flexible even if pricing changes.

---

## 4. Webhooks: how Stripe talks to My Joe

Stripe sends HTTPS POST requests to a special webhook endpoint on our Next.js app when something important happens.

Key ideas:

- We must **verify the webhook signature** using Stripe’s signing secret before trusting the payload.
- We must make webhook handling **idempotent** (safe on retry) so that if Stripe re-sends an event, we do not double-process it.

My Joe uses a table `stripe_events` with:

- `id` (Stripe event ID) as primary key,
- `type` (event type),
- `payload` (JSON),
- `received_at` timestamp.

The webhook handler will:

1. Verify the signature.
2. Check if the event ID already exists in `stripe_events`.
   - If it exists: do **nothing** (it’s a replay); return HTTP 200.
   - If it doesn’t: insert a row into `stripe_events` and then process it.

This follows Stripe’s guidance on idempotent webhook handling: store event IDs and process each event **at most once**.

---

## 5. Events we care about

We mainly care about:

1. **Subscription lifecycle**
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted` / `canceled`
   - `customer.subscription.trial_will_end` (optional, for reminders)

   For these, we update `public.subscriptions`:

   - Link `user_id` ↔ `stripe_customer_id` ↔ `stripe_subscription_id`.
   - Set `plan_id` to `lite`/`pro`/`max` based on which Price/Plan is used.
   - Update `status` to reflect Stripe’s subscription status.

2. **Invoices paid (for subscriptions)**
   - `invoice.payment_succeeded` where the invoice includes a **subscription** item for one of our plan Prices.

   For these, we:

   - Ensure `subscriptions` is up to date (status = `active` / `trialing` / etc.).
   - **Grant monthly credits** by inserting a positive row in `credit_ledger` with:
     - `reason = 'grant'`
     - `delta_credits = plans.monthly_credits` for that plan
     - `notes` like “monthly plan allowance (Stripe invoice XXX)”.

   If the invoice is the **first** one for a new subscription, we treat it as “initial plan credits”. If it is a renewal, we treat it as “monthly renewal credits”.

3. **Invoices paid (for top-ups)**
   - `invoice.payment_succeeded` where the invoice items refer to our **top-up Product(s)**.

   For these, we:

   - Determine how many credits this top-up grants (e.g. 100, 250).
   - Insert a positive row in `credit_ledger` with:
     - `reason = 'topup'`
     - `delta_credits = topup_credits`
     - `notes` like “top-up pack (Stripe invoice XXX)”.

Because we store the Stripe event IDs in `stripe_events`, re-sent `invoice.payment_succeeded` events do **not** cause extra grants.

---

## 6. Plan gating vs credits

My Joe uses both **plan gating** and **credits gating**:

- Plan gating (feature access):
  - Lite: raster generation only; no vector, limited or no fix/upscale.
  - Pro: raster + fix/upscale.
  - Max: raster + fix/upscale + vector.

- Credits gating (usage):
  - Every operation consumes credits according to the pricing table.
  - If your balance is too low, the backend function `sp_enqueue_and_burn` will raise an `insufficient_credits` error and **no job** will be created.

The server code will:

1. Check the user’s plan (via `subscriptions` and `plans.features`).  
2. Check credits (via `fn_credit_balance`).  
3. If plan & credits are OK:
   - Call `sp_enqueue_and_burn` to atomically burn credits and enqueue a `jobs` row.

This ensures:

- Users on Lite cannot use Pro/Max-only features, even if they have credits.
- Users on any plan cannot spend credits they don’t have.

---

## 7. Currency and regions

Initial assumption:

- One primary currency (e.g. GBP or USD).
- Stripe subscription Prices and top-up Prices are all in that currency.

Later, we can:

- Add more Prices for other currencies (e.g. USD, EUR) under the same Products.
- Use **Stripe Tax** to handle VAT/GST in different regions.
- Keep our internal credit maths in a single “base currency-equivalent” model.

The Postgres ledger stores amounts in **credits** (unitless) and COGS in **USD** to match provider pricing. Stripe handles actual local currency and taxes.

---

## 8. Operational notes

- **Source of truth for money**: Stripe (transactions, refunds, disputes).
- **Source of truth for credits**: `credit_ledger` in Postgres.
- **Source of truth for plan**: `subscriptions` + `plans` in Postgres, kept in sync from Stripe webhooks.

If we discover a mismatch (e.g. user over/under credited), we use `credit_ledger.reason='adjustment'` to correct the balance with an explicit note.

— End —
