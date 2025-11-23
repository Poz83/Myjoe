# My Joe – System Blueprint (v0.1)

**Purpose.** Establish a production-grade, solo-founder-friendly architecture using Next.js (Vercel), Supabase (Auth/DB/Storage/RLS/Realtime), Stripe (billing + credits), and a long-lived Python worker for AI pipelines via API providers. This blueprint fixes the baseline queueing approach for v1 and defines a clean migration path.

---

## 1) Tenets & non-negotiables

- Reliability first, then scale. Expect tens → low hundreds of users initially; optimize for simplicity and debuggability.
- Strict cost control. Governor must enforce per-operation COGS ceilings with a 40% margin floor.
- 1-bit outputs. Finisher pipeline guarantees true 1-bit B/W line art; no greys, no steampunk motifs.
- Separation of concerns. UI on Vercel, state in Supabase, compute in Python worker, payments in Stripe.
- Staging-first. All migrations and feature tests land on staging before production.

---

## 2) High-level architecture (Mermaid)

```mermaid
flowchart LR
  subgraph Client["User Browser (Next.js App)"]
    UI[App Router UI\nServer Actions]
  end

  subgraph Vercel["Vercel – Next.js"]
    SA[Server Actions\n(SSR/RSC)]
    WH[Stripe Webhook Route\n(idempotent)]
  end

  subgraph Supabase["Supabase (Prod/Staging)"]
    AUTH[Auth (Email/Google)]
    DB[(Postgres + RLS)]
    STOR[Storage (Vault)]
    RT[Realtime]
  end

  subgraph Stripe["Stripe"]
    Sub[Subscriptions & Prices]
    Pay[Checkout/Portal]
    Ev[Events/Webhooks]
  end

  subgraph Worker["Python Worker (Fly/Render/Railway)"]
    W[Job Runner\n(lease+heartbeat)]
    Log[Telemetry/Logs]
  end

  subgraph Providers["AI Providers"]
    OAI[OpenAI (Brain/Joe Knows)]
    Rep[Replicate (Flux Hero)]
    Rec[Recraft (Bulk)]
    Up[Upscaler]
    QC[Image Judge]
    Fin[Finisher (Potrace pipeline)]
  end

  UI -->|Auth| AUTH
  SA -->|Supabase Service Role (server-side only)| DB
  SA -->|Signed URLs| STOR
  SA -->|Create Jobs + burn credits| DB
  RT --> UI

  UI -->|Billing actions| Pay
  Ev --> WH
  WH --> DB

  W -->|Lease next job| DB
  W -->|Upload assets| STOR
  W -->|Update job state| DB
  W --> Log

  W --> OAI
  W --> Rep
  W --> Rec
  W --> Up
  W --> QC
  W --> Fin

```

---

## 3) Core flows

### 3.1 Auth
1. User signs up/signs in (Email+Password or Google OAuth) via Supabase Auth.
2. Next.js reads session server-side; RLS enforces per-user isolation in DB/Storage.
3. Trial flags and plan entitlements are loaded via server action.

### 3.2 Job submission (Studio → Generation)
1. User configures a run (audience, style, batch size, prompts).
2. Server Action:
   - Calls Brain to shape prompt → JSON manifest (bounded tokens).
   - Computes credit quote and estimated COGS using provider pricing table.
   - Governor transaction: validate plan, credits, and cost ceiling; atomically burn credits; insert `jobs` rows.
3. Realtime notifies the UI that the batch is enqueued.

### 3.3 Worker processing
1. Worker polls `jobs` with lease: `SELECT ... WHERE status='pending' AND scheduled_at<=now() ORDER BY priority, created_at FOR UPDATE SKIP LOCKED LIMIT N;`
2. Sets `locked_by`, `locked_at`, `status='in_progress'`, `attempts=attempts+1`.
3. Executes pipeline per job:
   - Raster (Bulk/Hero) → optional Fix/Upscale → Judge → Finisher (when requested in later phases).
4. Uploads assets to Supabase Storage; writes metadata to `generations`.
5. Updates job → `completed` | `failed` (and stores measured COGS, errors).
6. UI updates via Realtime.

### 3.4 Billing & credits
- Checkout/Portal actions redirect to Stripe; webhook posts update plan and credits to an append-only ledger.
- Monthly plan grants and top-ups accumulate to balance; the Governor reads from computed balance (materialized view or function).

---

## 4) Queueing strategy (v1 baseline)

Baseline (v1): **Postgres jobs table + lease/heartbeat** inside Supabase.  
Why: minimum moving parts, easy to inspect with SQL, full control under RLS, no extra infra. Good up to thousands of jobs/day with modest concurrency.

Key columns (see ADR-002 for details):  
- `id uuid pk`, `user_id uuid`, `type text`, `payload jsonb`, `status text check in ('pending','in_progress','completed','failed','cancelled')`,
- `priority int default 100`, `scheduled_at timestamptz default now()`,
- `locked_by text`, `locked_at timestamptz`, `attempts int default 0`, `last_error text`,
- `started_at`, `completed_at`, `created_at`, `updated_at`.  
Indexes: `(status, scheduled_at, priority)`, `(locked_by)`, `(user_id, created_at desc)`.

Lease/heartbeat  
- Worker takes a lease (sets `locked_by`, `locked_at`), updates status to `in_progress`, and heartbeats every ~15–30s.
- If `in_progress` with `locked_at` older than lease_ttl (e.g., 5 minutes), a reclaimer resets it to `pending` (attempts++), unless `attempts` reached `max_attempts`.

Retries & DLQ  
- Max attempts recommended: 3 (exponential backoff: 1m / 5m / 30m).
- After max attempts, mark `failed` and link to a DLQ table or leave as failed with `last_error`.

Migration path (later): **Supabase Queues (`pgmq`)**  
- When concurrency or throughput requires, swap the claim/retry logic to `pgmq` with minimal change in worker code (adapter pattern).
- Keep the same payload shape across both paths.

---

## 5) RLS, roles, and server actions

- RLS on: `projects`, `generations`, `jobs`, `credit_ledger`.
- Server-side privileged ops (credits burn, job enqueue) go through server actions using the Supabase service-role key (never shipped to the client).
- User reads use session-scoped Supabase client respecting RLS.
- Admin tools use a dedicated admin role and SECURITY DEFINER functions (carefully audited).

---

## 6) Environments & secrets

- Vercel (Next.js):
  - Prod project → talks to Supabase prod, Stripe live.
  - Staging project (or preview env) → Supabase staging, Stripe test.
  - `NEXT_PUBLIC_*` only for non-sensitive client config; all keys (Supabase service role, Stripe webhook secret, provider API keys) are server-only.

- Worker (Fly/Render/Railway):
  - Environment variables for provider API keys and Supabase service role.
  - Health endpoint + logs; deploy one staging worker tied to staging DB.

- Supabase CLI migrations:
  - Write SQL in repo; apply to staging first → test → apply to prod.

---

## 7) Observability (minimal)

- Logs: Next.js route logs, Worker structured logs, DB audit tables (`cost_events`, `job_events`).
- Error tracking: Sentry (or similar) in Next.js + Worker (PII-minimized).
- Health checks: a /health route in the worker; a small dashboard page showing queue depth, failed jobs, and COGS drift vs target.

---

## 8) Non-goals (v0.1)

- Multi-region deployments.
- Self-hosted GPUs.
- Heavy distributed queue infra.

These are explicitly deferred until the product proves sustained load.

— End of blueprint —
