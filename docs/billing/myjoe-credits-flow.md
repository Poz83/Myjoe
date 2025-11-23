# My Joe – Credits Flow (v1)

This file explains, step-by-step, how **credits are created, stored, and spent** in My Joe.

---

## 1. Where credits live

Credits are **not** managed by Stripe directly. They live in your Postgres database:

- Table: `public.credit_ledger`
- Each row is **one movement** of credits (like a bank statement line).

Key fields:

- `user_id` – which user this row belongs to.
- `reason` – why this row exists:
  - `grant` – monthly plan allowance.
  - `topup` – paid top-up pack.
  - `burn` – credits spent on an operation.
  - `refund` – credits returned after a failure (optional).
  - `adjustment` – manual correction (admin only).
- `delta_credits` – the number of credits added or removed:
  - Positive for grants/topups/refunds/adjustments.
  - Negative for burns.
- `operation_type` – for burns, what we spent on (`raster`, `vector`, `fix_upscale`, etc.).
- `job_id` / `generation_id` – link to the job/output, if relevant.
- `created_at` – when this movement happened.

The ledger is **append-only**:

- UPDATE and DELETE on `credit_ledger` are blocked by triggers.
- Once a row is written, it is part of the permanent credit history.

The **current balance** is:

```sql
select coalesce(sum(delta_credits),0)
from credit_ledger
where user_id = <user>;

