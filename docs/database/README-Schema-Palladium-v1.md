# My Joe – Database Schema (Palladium v1)

This document explains **what** the database is doing, not every SQL detail.

## Goals

- Each user only sees **their own** projects, jobs, generations, and credits (Row Level Security).
- Credits behave like a **bank statement** (append-only ledger).
- Job queue is **safe with multiple workers** using PostgreSQL `FOR UPDATE SKIP LOCKED`.
- Stripe webhooks and job enqueues are **idempotent** (retries don’t double-spend).

## Main tables (plain English)

- `profiles` – extra info per user (display name, trial flags). Key: one row per `auth.users.id`.
- `plans` – Lite / Pro / Max descriptions, allowances, and feature flags.
- `subscriptions` – which user is on which plan, with Stripe IDs and status.
- `projects` – “books/projects” grouped by user.
- `jobs` – background work items (e.g. raster, fix_upscale, vector). Used as a **queue**.
- `generations` – final image outputs in the Vault; includes size, DPI, bit depth, and Storage path.
- `credit_ledger` – append-only credit history; burns are negative, grants/topups positive.
- `cost_events` – measured provider usage and COGS per job.
- `provider_prices` – unit prices for each AI model used by the Governor.
- `idempotency_keys` – avoid double-enqueue for the same user/action.
- `stripe_events` – remember processed Stripe event IDs so replays don’t double-grant credits.

## Credit safety

- **Balance** = sum of all `credit_ledger.delta_credits` for a user.
- The core function `sp_enqueue_and_burn`:
  - Locks the user’s `profiles` row (one spender at a time).
  - Checks balance (via `fn_credit_balance`).
  - If enough credits: creates a `jobs` row and writes a **negative** ledger row.
  - Supports optional idempotency key so the same request can’t burn twice.

The ledger cannot be updated or deleted (append-only) – enforced by triggers.

## RLS model (who can see what)

- For user data tables (`projects`, `jobs`, `generations`, `credit_ledger`, `cost_events`, `idempotency_keys`):
  - SELECT only returns rows where `user_id = auth.uid()`.
- For shared config (`plans`, `provider_prices`):
  - Authenticated users can read; only the **service role** can change them.
- For Stripe/webhook internals (`stripe_events`, some writes to `subscriptions`, `credit_ledger`):
  - Only the **service role** can insert/update (via server actions or backend code).

## Job queue pattern

- Workers pick jobs with `status='pending'` using `FOR UPDATE SKIP LOCKED`.
- This ensures multiple workers don’t fight over the same job.
- `attempts` and `max_attempts` limit how many times a job retries.

A simple “reclaimer” job (added later) can requeue stuck `in_progress` jobs whose `locked_at` is too old.

— End —
