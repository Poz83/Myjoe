# My Joe – Smart Handover Prompt (Stage 0 Continuation)

You are taking over work on a project called **“My Joe Image Creator”** for a solo founder (Jamie).

Please read this entire prompt carefully before you reply.

---

## 1. Project Name & One-line Summary

**Project:** My Joe Image Creator (My Joe)  
**One-liner:** AI-powered, **KDP-safe colouring-book factory** that generates true **1-bit black & white line art** (no greys, no steampunk) for Kindle Direct Publishing and similar POD platforms.

---

## 2. Working Contract (Short Version)

- **Founder / user:** Jamie (solo non-expert dev), on **Windows 11**, primarily using **PowerShell**.
- **Local repo path:** `C:\myjoe\myjoe-app`  
- **Version control:** GitHub repo: `Poz83/Myjoe` (already created; assume standard `main` branch unless told otherwise).
- **Stack (locked in):**
  - **Frontend:** Next.js 14+ (App Router), TypeScript, Tailwind CSS, deployed on **Vercel**.
  - **Backend data layer:** **Supabase** (Postgres, Auth, Storage, RLS, Realtime).
  - **Billing:** **Stripe** for subscriptions + one-off **credit top-ups**.
  - **Worker:** Long-lived **Python** worker (“chef”) on a VM/container platform (e.g. Fly.io / Render / Railway), not serverless per request.
  - **AI roles (conceptual):**
    - Brain – LLM → JSON “page manifest”.
    - Stylist – small multimodal model for style hints.
    - Bulk Artist – lower-cost raster for batches.
    - Hero Artist – higher-quality raster (e.g. Flux 1.1 Pro via Replicate).
    - Upscaler – resolution upscaling model.
    - Image Judge – QC (no greys, line quality, coverage).
    - Finisher – deterministic vectorisation + binarisation (Potrace pipeline etc.).
    - Governor – credit/limits enforcement layer (DB + server actions).
    - “Joe Knows” – small LLM helper for KDP tips / constraints.
- **Economic model (locked assumptions):**
  - Credit-based pricing with **hard minimum 40% gross margin** on paid usage.
  - Worst-case plan = **Max**; all COGS guardrails are calculated against **Max plan revenue per credit**.
  - Credits used for:
    - 1 credit → raster generation (Bulk/Hero).
    - 2 credits → vectorisation.
    - 0.5 credits → fix/upscale.
- **Design rules:**
  - Output must be **true 1-bit B/W line art**, KDP-safe, no steampunk motifs.
  - Architecture must be **Palladium-grade**: secure by default, RLS everywhere, credit ledger append-only, proper idempotency.
- **File / tooling rules:**
  - Prefer **full-file updates** over “diffs”. When generating code or docs, output the full file content.
  - Use **PowerShell scripts** for file creation / boilerplate where possible; Jamie is happy to paste commands into PowerShell.
  - Explain jargon in **ELI10 style** as you go.
  - Keep “what to paste into PowerShell” **clearly separated** from explanation.

There is also a **Smart Handover Cheat Sheet** that defines trigger phrases (“Stage X complete”, “new chat”, etc.) and the structure you’re reading now.

---

## 3. Stages Overview & Current Stage

We are following staged implementation (high level):

- **Stage 0 – Economics & Contracts**  
  - COGS guardrails, credits model, Stripe model, core DB schema, RLS, job/ledger design.
- **Stage 1 – Repo & Tooling**  
  - Scripts, preflight checks, git hygiene, docs layout.
- **Stage 2 – Auth & Accounts**  
  - Supabase Auth, profiles, basic Next.js structure.
- **Stage 3 – Prompt & Model Strategy**  
  - Brain manifest, Stylist, initial model choices & prompts.
- **Stage 4 – App Structure & Studio Baseline**  
  - Projects/books, generation UI, basic dashboard.
- **Stage 5 – Vault & Worker Integration**  
  - Python worker, job queue, image storage, QC.
- **Stage 6 – Ledger & Governor**  
  - Credits enforcement, COGS measurement, plan gating.
- **Stage 7+ – Book Assembly, Exports, Polish**  
  - KDP interior assembly, cover tooling, UX polish.

**Status right now (important):**

- **Stage 0 – Economics & Contracts:** `IN PROGRESS`  
  - Most of the design/docs and schema are done and committed.
  - Supabase CLI installation + linking + schema push to staging are **not yet successfully completed**.
- **Stage 1 – Repo & Tooling:** `NOT STARTED` (only some ad-hoc scripts; not formalised).
- **Stage 2+:** `NOT STARTED`.

> **This new chat is responsible for: “Continue Stage 0 from where we left off.”**

Your main job is to **finish Stage 0 cleanly** and prepare a good starting point for Stage 1.

---

## 4. What Has Been Done So Far (By Stage)

### Stage 0 – Economics & Contracts (in progress)

So far we have:

### 4.1 COGS Guardrails & Margin Policy (Stage 0 / Section A)

Documents created under `docs/economics/`:

- `myjoe-cogs-guardrails.md` – defines:
  - Plans: Lite, Pro, Max with example prices & credits.
  - Worst-case **revenue per credit (RPC)** based on Max plan.
  - Per-operation COGS formulas:
    - `REVENUE = RPC * CREDITS`
    - `MAX_COGS = REVENUE * (1 - MARGIN_MIN)` with `MARGIN_MIN = 0.40`
    - `TARGET_COGS = MAX_COGS * (1 - BUFFER)` with default `BUFFER = 0.20`.
  - Derived budgets for:
    - Raster, vector, fix/upscale.
  - Suggested breakdown of budget across Brain, Artist, QC/Upscale.
  - Monitoring rules:
    - Yellow alert > 80% of MAX_COGS.
    - Red alert > 90% for several hours → kill-switch/fallback provider.
  - Trial cost envelope: keep average trial raster COGS ≤ ~$0.030, using Bulk model and low resolution.

- `myjoe-cogs-v1.csv` – spreadsheet-ready table of:
  - Plans, credits, revenue per credit.
  - Per-operation revenue, MAX_COGS, TARGET_COGS (with 20% buffer).

ADR created under `docs/adr/`:

- `ADR-001-margin-policy.md` – formally locks:
  - Use worst-case RPC (Max plan) for all COGS guardrails.
  - 40% minimum gross margin.
  - 20% default buffer.
  - Use Governor to deny jobs when `estimated_cogs > MAX_COGS` or insufficient credits.
  - Append-only credit ledger; no balance editing, only new movements.

---

### 4.2 System Blueprint / Architecture (Stage 0 / Section B)

Documents in `docs/architecture/` (names may vary slightly but concept is clear):

- A **System Blueprint** markdown file describing:
  - Next.js app on Vercel as UI + API shell.
  - Supabase for DB/Auth/Storage/RLS/Realtime.
  - Stripe for billing (subscriptions + top-ups).
  - Python worker on long-lived infrastructure for queue processing and AI calls.
  - AI providers:
    - OpenAI (Brain / Joe Knows),
    - Replicate (Hero Artist, e.g. Flux),
    - Recraft (Bulk Artist),
    - plus upscaler & QC models.
  - Image pipeline:
    1. Brain → manifest.
    2. Stylist → style hints.
    3. Bulk/Hero Artist → raster image(s).
    4. Optional Upscaler + Judge.
    5. Finisher → 1-bit line art (Potrace pipeline).
  - Storage “Vault” in Supabase Storage; metadata in `generations` table.
  - Job queue in Postgres via `jobs` table and `FOR UPDATE SKIP LOCKED` worker pattern.

---

### 4.3 Core Database Schema & RLS (Palladium v1, Stage 0 / Section C)

A **large migration** created under `supabase/migrations/` with a name like:

- `YYYYMMDDTHHMMSS_core_schema_palladium_v1.sql`

This defines:

#### Types

- `job_status` enum: `pending`, `in_progress`, `completed`, `failed`, `cancelled`.
- `ledger_reason` enum: `grant`, `burn`, `topup`, `refund`, `adjustment`.

#### Tables

- `profiles` – user metadata, trial flags; 1–1 with `auth.users(id)`.
- `plans` – plan catalogue (`lite`, `pro`, `max`) + monthly price/credits + feature flags.
- `subscriptions` – user ↔ plan mapping, Stripe IDs, period dates, status.
- `projects` – books/projects per user.
- `jobs` – job queue table:
  - `type` (`raster`, `fix_upscale`, `vector`).
  - `status` (enum).
  - `payload` JSON.
  - `priority`, `scheduled_at`.
  - `locked_by`, `locked_at`, `attempts`, `max_attempts`, `last_error`.
  - `client_request_id` (idempotency helper).
- `generations` – image outputs (Vault metadata):
  - `provider`, `model`, `width`, `height`, `dpi`, `bit_depth`, `storage_path`, `thumb_path`.
  - `cost_estimated_usd`, `cost_measured_usd`, `qc` JSON.
- `credit_ledger` – append-only credit ledger:
  - One row per credit movement.
  - Positive for `grant`, `topup`, `refund`, `adjustment`.
  - Negative for `burn`.
  - `operation_type` + `job_id` / `generation_id` for traceability.
  - Triggers to block `UPDATE`/`DELETE`.
- `cost_events` – per-job provider usage and cost, to match COGS guardrails.
- `provider_prices` – live model pricing table for Governor to compute `estimated_cogs`.
- `idempotency_keys` – dedupe enqueues per user/scope/key → `job_id`.
- `stripe_events` – store Stripe event IDs + payload to make webhooks idempotent.

#### Views & functions

- `vw_credit_balances` – per-user credit balance.
- `fn_credit_balance(user_id)` – returns numeric sum of ledger entries.
- `tgr_set_updated_at` – generic `updated_at` trigger for several tables.
- `tgr_block_ledger_ud` – blocks update/delete on `credit_ledger`.
- `app_private.sp_enqueue_and_burn_core(...)` (security definer, private schema).
- `public.sp_enqueue_and_burn(...)` – safe public wrapper used by server actions:
  - Locks user’s `profiles` row.
  - Checks credit balance.
  - Fails if insufficient credits.
  - Creates a `jobs` row.
  - Inserts a negative `credit_ledger` row as a `burn`.
  - Supports idempotency via `idempotency_keys`.

#### RLS (Row Level Security)

RLS enabled on all user-data tables, with policies such as:

- Users only see their own `projects`, `jobs`, `generations`, `credit_ledger`, `cost_events`, `idempotency_keys`.
- `plans` & `provider_prices` readable by authenticated users, writable only by `service_role`.
- `stripe_events` read/write only by `service_role`.
- `credit_ledger` insert-only via `service_role` (append-only, no direct client insert).
- `jobs` / `generations` writes restricted to `service_role` for safety.

A human-readable schema summary exists under:

- `docs/database/README-Schema-Palladium-v1.md` – explains schema & RLS in plain English.

---

### 4.4 Stripe Billing & Credits Model (Stage 0 / Section D)

Under `docs/billing/`:

- `myjoe-stripe-billing-model.md` – describes:
  - One Product + monthly Price per plan (Lite, Pro, Max).
  - Additional Products/Prices for credit top-ups.
  - Stripe as **money + tax brain**:
    - Subscriptions, invoices, and top-ups.
    - Webhooks for:
      - `customer.subscription.*`
      - `invoice.payment_succeeded` (subscriptions + top-ups).
  - Webhook handler pattern:
    - Verify HMAC signature.
    - Store each Stripe event in `stripe_events` (idempotent).
    - For subscription invoices:
      - Update `subscriptions`.
      - Add `grant` row to `credit_ledger` with `plans.monthly_credits`.
    - For top-up invoices:
      - Add `topup` row to `credit_ledger` with pack size.
  - Separation of concerns:
    - Stripe = cash ledger + tax.
    - Postgres = credits + usage ledger.

- `myjoe-credits-flow.md` – describes:
  - How credits are **created**:
    - Plan grants (`reason='grant'`).
    - Top-ups (`reason='topup'`).
    - Adjustments/refunds (`reason='adjustment'`/`'refund'`).
  - How credits are **burned**:
    - Only via `sp_enqueue_and_burn` when creating jobs (`reason='burn'`).
  - Balance as sum of `credit_ledger.delta_credits`.
  - Idempotency via `idempotency_keys` to avoid double burns.
  - Mental model: never edit balances, only append new ledger rows.

---

## 5. Files and Paths Touched (Key Ones)

Under `C:\myjoe\myjoe-app`:

- **Economics & guardrails:**
  - `docs/economics/myjoe-cogs-guardrails.md`
  - `docs/economics/myjoe-cogs-v1.csv`
- **Architecture & decisions:**
  - `docs/architecture/...` (system blueprint; may be named like `myjoe-system-blueprint-v0.1.md`).
  - `docs/adr/ADR-001-margin-policy.md`
- **Database schema:**
  - `supabase/migrations/YYYYMMDDTHHMMSS_core_schema_palladium_v1.sql`
  - `docs/database/README-Schema-Palladium-v1.md`
- **Billing & credits:**
  - `docs/billing/myjoe-stripe-billing-model.md`
  - `docs/billing/myjoe-credits-flow.md`

You should assume these files exist and reflect the state described above. If you need to change them, generate **full replacement contents**, not partial diffs.

---

## 6. Outstanding Issues / Risks / TODOs

### Must-fix before we say “Stage 0 complete”

1. **Supabase CLI is not installed cleanly yet.**
   - `npm install -g supabase` failed (Supabase no longer supports global npm install).
   - Need a supported install method on Windows 11 (e.g. **Scoop** or standalone binary).
   - Once installed, confirm:
     - `supabase --version` works in PowerShell.

2. **Project is not linked to staging Supabase project yet.**
   - Staging project ref: `tipcrankrakmnbrocvnl`.
   - Need to run (after CLI works):
     - `supabase login`
     - `supabase link --project-ref tipcrankrakmnbrocvnl`

3. **Palladium schema has not been pushed to staging yet.**
   - Need to run:
     - `supabase db push`
   - Then verify in Supabase dashboard that tables/functions/RLS exist as expected.

4. **No clear record yet of which Supabase/Vercel regions we’re using.**
   - For now, default assumption: **US-based region** for Supabase + Vercel (US-heavy audience, AI providers usually US-based).
   - We should explicitly note chosen regions in docs (e.g. `docs/architecture/...`), especially because Jamie is UK-based and will care about GDPR + cross-border data issues later.

### Nice-to-have / later

5. **Stripe Tax configuration & multi-currency** (later stage)
   - Docs assume Stripe Tax will be turned on eventually, but no concrete config has been defined yet.
   - For now, all internal economics are in **USD**; Stripe Prices will likely be USD-first, with GBP/EUR added later.

6. **Preflight & snapshot scripts** (Stage 1)
   - Not yet created:
     - `scripts/Preflight-MyJoe.ps1`
     - `scripts/Snapshot-BuildState.ps1`
   - These will help future changes be reproducible and safe, but they’re part of Stage 1.

---

## 7. Next Stage (for THIS chat): Objectives & Boundaries

This chat is **not** starting Stage 1 yet. Its main responsibility is:

> **Finish Stage 0 in a practical, usable state.**

Concretely, please:

1. **Help Jamie install the Supabase CLI on Windows 11 using a supported method**  
   - ELI10, step-by-step.
   - Prefer **Scoop** or official binary over deprecated npm global install.
   - Explain clearly:
     - What commands to run.
     - How to verify installation (`supabase --version`).

2. **Walk Jamie through linking the local repo to the staging project**  
   - Commands (they will paste into PowerShell):
     - `cd C:\myjoe\myjoe-app`
     - `supabase login`
     - `supabase link --project-ref tipcrankrakmnbrocvnl`

3. **Walk Jamie through pushing the Palladium schema to staging**  
   - Command:
     - `supabase db push`
   - ELI10 explanation of what this does.
   - What success looks like.
   - If errors appear, interpret them and adjust (e.g. migration syntax issues, connection problems).

4. **Ask Jamie to confirm what they see in Supabase UI**  
   - Guide them to Table Editor in Supabase dashboard.
   - Ask them to check for key tables: `profiles`, `plans`, `subscriptions`, `projects`, `jobs`, `generations`, `credit_ledger`, `cost_events`, `provider_prices`, `idempotency_keys`, `stripe_events`.
   - Use their feedback to confirm Stage 0’s **DB side** is solid.

5. **Optionally, add a tiny note to the docs** (if time/energy allows)
   - Update relevant doc(s) to explicitly state:
     - “All economics (COGS, margins) are modelled in **USD baseline**, even though Jamie is UK-based and users are primarily US/global.”
   - Keep changes small and use full-file replacements if you edit.

**Out of scope for this chat** (unless Stage 0 DB work is fully done and confirmed):

- Building Preflight/Commit scripts (Stage 1).
- Implementing Next.js routes or pages.
- Implementing Stripe webhooks.
- Implementing the Python worker.

Those belong to later stages after Stage 0 is closed.

---

## 8. Mode Guidance (Pro vs Extended)

For **this chat continuing Stage 0**:

- **Mode:** Extended / implementation-focused is fine.  
- You don’t need heavy research mode; you need **practical, step-by-step guidance** for:
  - Supabase CLI installation on Windows.
  - Linking and pushing the schema.
  - Confirming tables in the Supabase UI.

Where you reference external instructions (e.g. Supabase CLI install), keep citations light and summarise in your own words.

---

## 9. Instructions for this New Chat (What you should do first)

1. **Acknowledge this handover** with something short like:
   - “Got it, I understand the current state and I own Stage 0 continuation.”
2. **Summarise in your own words:**
   - What My Joe is.
   - What Stage 0 has already delivered (docs + schema).
   - What you will do next (CLI install → link → db push → verify).
3. Then **guide Jamie step-by-step**, in ELI10 style:
   - Explicit commands for PowerShell (with clear “paste this” blocks).
   - Explain what each step is doing.
   - Ask Jamie to paste back any error messages in full if something fails.

Remember: Jamie is comfortable pasting PowerShell commands but gets easily blocked by “it’s hanging / doing nothing” moments. Be **very explicit** about:

- What the prompt should look like (`PS ...>` vs `>>`).
- When it’s safe to press Enter.
- How to cancel a stuck command (Ctrl + C).

---

**End of Smart Handover Prompt.**
Paste content here and save
