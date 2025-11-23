# My Joe – Master Instructions & Stage 1 Handover

This single file replaces the older separate docs for new ChatGPT chats:

- `myjoe-version-super-instructions.md`
- `myjoe-system-blueprint-v0.1.md`
- `myjoe-handover-cheatsheet.md`
- The separate “Smart Handover Prompt” docs

For a new chat, you will upload:

- This file: `myjoe-master-instructions-and-handover.md`
- Your latest code snapshot ZIP: e.g. `myjoe.zip`

Then you will paste the “First message template” from section 2.

---

## 1. Project overview

**Project name:** My Joe (My Joe Image Creator)

**One-liner:** A web app that helps non-artists generate **true 1-bit**, black-and-white, KDP-safe colouring pages and interiors with AI — no greys, no steampunk motifs, and with strict cost controls so margins stay **≥ 40%** on paid usage.

**Key constraints:**

- Outputs must be **1-bit line art**: only black and white pixels (no grey, no shading).
- Outputs must be **KDP-safe**:
  - Content-appropriate for Amazon KDP.
  - High enough resolution and print-safe.
- **No steampunk** motifs (no gears, cogs, chains, pipes etc.).
- Business must maintain **≥ 40% gross margin** on paid usage.
  - Don’t suggest architectures that obviously blow up compute costs.

---

## 2. New Chat Setup (what the user should do)

When starting a **brand-new ChatGPT chat** for My Joe, do this:

### 2.1 Files to upload

Upload these files before sending the first message:

1. `myjoe-master-instructions-and-handover.md` (this file)
2. Your latest code snapshot ZIP, e.g.:
   - `myjoe.zip` or `myjoe-code-snapshot-YYYYMMDD-HHMM.zip`

That’s it. You do **not** need to upload the older individual docs anymore.

### 2.2 First message template

After uploading the two files above, paste this as your **very first message**:

---START MESSAGE---
You are working inside my **My Joe** project (Next.js 14 App Router + Supabase + Python worker + Stripe).

I have uploaded:

- `myjoe-master-instructions-and-handover.md`
- The latest code snapshot ZIP for the repo

Please do the following before you start any deep work:

1. Read `myjoe-master-instructions-and-handover.md` fully so you understand:
   - What My Joe is,
   - The stack and environment,
   - How I want you to work (PowerShell-first, full file contents, ELI10-style),
   - The current stage (Stage 1 – Core user experience & admin API),
   - The Stage 0 recap and Stage 1 priorities.
2. Inspect the code snapshot ZIP enough to understand the repo layout and any key files.

After you have read/inspected those:

1. Reply with **“Ready mate”**.
2. Then give me a short bullet summary of:
   - What My Joe is (in your own words),
   - Which stage you are currently on (**Stage 1 – Core user experience & admin API**),
   - What you plan to do first in this chat.

After that initial summary, continue in this chat as follows:

- Work strictly in **Stage 1 – Core user experience & admin API** unless I explicitly say a stage is complete and request a Smart Handover.
- Start by implementing the Joe View admin API endpoints, following the contracts and priorities in `myjoe-master-instructions-and-handover.md`.
- Your **first concrete task** in this chat should be:
  - Implement the `GET /api/admin/users` endpoint as a Next.js 14 App Router route handler using TypeScript.
  - Use **PowerShell scripts as the default/first option** for creating or updating files under `C:\myjoe\myjoe-app`, unless that would clearly compromise safety or correctness.
  - When you need to modify a file, always show the **full final file contents**, not a diff.
  - Keep explanations ELI10-style: briefly explain any new jargon as you introduce it.
---END MESSAGE---

---

## 3. Environment & workflow

### 3.1 Local environment

- OS: Windows 11
- Shell: **PowerShell**
- Repo root: `C:\myjoe\myjoe-app`

### 3.2 Tech stack (locked in)

- **Frontend:** Next.js 14 (App Router) + TypeScript + Tailwind CSS
- **Backend:** Supabase (Postgres, Auth, Storage, RLS, Realtime)
- **Worker:** Python worker for AI pipelines + job queue
- **Billing:** Stripe (subscriptions + credit packs), Resend later for email

### 3.3 GitHub & CI

- Repo: `https://github.com/Poz83/Myjoe`
- Default branch: `main` (protected: requires PR + 1 approval)
- Preferred flow:
  - Create feature branch (`feat/...`)
  - Commit changes
  - Open PR → let CI run
  - Merge via **squash**

- CI:
  - `.github/workflows/ci.yml` runs on every push/PR to `main`
  - Long term: require CI to pass before merging

---

## 4. How I want the assistant to work (rules of engagement)

These rules apply in **every chat** for this project:

1. **ELI10 explanations**
   - Explain coding and infra jargon briefly as if to a smart 10–12 year old.
   - Don’t oversimplify important details, but avoid walls of jargon.

2. **PowerShell-first**
   - Any task that can reasonably be done with PowerShell **should default to PowerShell**:
     - Creating files, updating files, scaffolding Next.js routes, Supabase CLI commands, Git commands.
   - Only skip PowerShell if it would:
     - Clearly reduce safety,
     - Or be much more complex than the manual alternative.
   - When giving commands, use clear headings like:
     - `### PowerShell – run this in C:\myjoe\myjoe-app`

3. **Full file contents, not diffs**
   - When changing a file (e.g. `app/api/.../route.ts`, `supabase/migrations/...`):
     - Show the **entire final file**.
     - Assume I will copy-paste your version over the existing file.

4. **Safe assumptions and questions**
   - Be direct and honest about uncertainties.
   - Don’t guess secrets (API keys, env vars, URLs); mark them as `TBD` and tell me what I need to create.

5. **Business & product constraints**
   - Respect:
     - 1-bit, black-and-white outputs,
     - KDP safety,
     - No steampunk motifs,
     - ≥ 40% gross margin.
   - If a design choice obviously threatens margins or print safety, flag it and suggest safer alternatives.

---

## 5. Stage model

We work in stages to keep things focused:

- **Stage 0 – Database & Admin Infrastructure (“Joe View foundation”)**
  - Supabase linking, core schema, admin schema & views for Joe View.
- **Stage 1 – Core user experience & admin API** (CURRENT)
  - Next.js basic flows (auth, dashboard) and admin API endpoints wired to the admin schema.
- **Stage 2 – Worker & generation pipeline**
  - Python worker, job queue, AI generation and 1-bit finishing.
- **Stage 3 – Billing & business logic**
  - Stripe subscriptions, top-ups, margins, guards.
- **Stage 4+ – Reporting & polish**
  - Joe View enhancements, analytics, quality-of-life.

### Current stage

- **Stage 0 is complete.**
- **We are now in Stage 1 – Core user experience & admin API.**

---

## 6. Stage 0 recap (what’s already done)

This is a compressed summary so Stage 1 work doesn’t re-do Stage 0.

### 6.1 Admin schema migration

A Supabase migration was created and fixed:

- File: `supabase/migrations/20251123112137_joe_view_admin_schema.sql`

It defines:

- Schema: `admin`
- Tables:
  - `admin.user_notes`
  - `admin.user_tags`
  - `admin.admin_roles`
- Views:
  - `admin.vw_user_overview`
  - `admin.vw_user_activity`
  - `admin.vw_daily_usage_per_user`

Key points:

- `admin.vw_user_overview`:
  - One row per user with:
    - `user_id`, `email`, `display_name`
    - `plan_id`, `plan_name`, `subscription_status`
    - `credit_balance` via `public.fn_credit_balance(user_id)`
    - `project_count`, `job_count`, `generation_count`
    - `last_active_at` (`coalesce(last_sign_in_at, created_at)`)

- `admin.vw_user_activity`:
  - Timeline of user events:
    - Credit ledger entries,
    - Subscription updates,
    - Jobs.
  - Uses a synthetic `occurred_at` field (from `created_at` / `updated_at` of sources).

- `admin.vw_daily_usage_per_user`:
  - Per-user, per-day sum of **credits spent** (positive number) using `credit_ledger.delta_credits`.

### 6.2 Admin roles and notes

- `admin.admin_roles`:
  - `user_id` → `auth.users.id`
  - `role` in `('owner', 'support', 'read_only')`
  - Used to gate admin endpoints (Joe View).

- `admin.user_notes` / `admin.user_tags`:
  - Private metadata for admins:
    - Notes (free text, by admin, with timestamps),
    - Tags (short labels applied to users).

### 6.3 Migrations applied

- `supabase db push` has been run.
- `supabase migration list` shows the admin migration applied both locally and remotely.
- In Supabase Studio (Table Editor, schema `admin`):
  - Tables: `admin_roles`, `user_notes`, `user_tags`.
  - Views: `vw_user_overview`, `vw_user_activity`, `vw_daily_usage_per_user`.
  - “View data” runs without SQL errors.

---

## 7. Stage 1 priorities (what the assistant should do now)

Stage 1 is about **Core UX & admin API**, but we start with the **admin API layer** first, using the Stage 0 admin schema.

### 7.1 Overall Stage 1 goals

- Implement admin API endpoints (Joe View) on top of the `admin` schema.
- Enforce admin access via `admin.admin_roles`.
- Wire a minimal internal admin UI (Joe View) that consumes those endpoints.
- Keep flows simple and pragmatic; this is an internal tool.

### 7.2 Admin API endpoints to implement (order of priority)

Each endpoint is a Next.js App Router route handler under `/api/admin/...`.  
All must:

- Use Supabase Auth to find the current user,
- Check that user appears in `admin.admin_roles` with role `owner`, `support`, or `read_only`,
- Return `401` if unauthenticated, `403` if not an admin.

**1. `GET /api/admin/users` – list users**

- Purpose: Joe View left-hand user list.
- Inputs (query params):
  - `page` (default `1`)
  - `pageSize` (default `50`, max `100`)
  - `search` (optional; fuzzy on email/display_name)
  - `plan` (optional; filter by `plan_id`)
  - `status` (optional; filter by subscription status)
  - `sort` (`last_active_at_desc` default, or `last_active_at_asc`)
- Data source: `admin.vw_user_overview`.
- Response:
  - `data`: array of rows with:
    - `user_id`, `email`, `display_name`, `plan_id`, `plan_name`,
      `subscription_status`, `credit_balance`,
      `project_count`, `job_count`, `generation_count`, `last_active_at`
  - `pagination`: `{ page, pageSize, total }`

**2. `GET /api/admin/users/:id` – single user overview**

- Purpose: right-hand Overview panel.
- Path: `/api/admin/users/[id]`
- Data source: `admin.vw_user_overview` filtered by `user_id`.
- Returns:
  - `{ "user": { ... } }` or `404` if not found.

**3. `GET /api/admin/users/:id/ledger`**

- Purpose: “bank statement” of credit movements for that user.
- Data source: `public.credit_ledger`.
- Inputs: pagination; optional filters (`from`, `to`, `reason`).
- Response: `data` + `pagination`, with full ledger rows.

**4. `GET /api/admin/users/:id/activity`**

- Purpose: merged activity timeline (credits, subscriptions, jobs).
- Data source: `admin.vw_user_activity`.
- Inputs: pagination; optional `from`/`to` on `occurred_at`.
- Response: `data` + `pagination`, with fields:
  - `user_id`, `occurred_at`, `source`, `source_id`, `summary`, `delta_credits`.

**5. `GET /api/admin/users/:id/notes`**

- Purpose: read internal admin notes for a user.
- Data source: `admin.user_notes`.
- Response: array of notes with `id`, `user_id`, `author_id`, `note`, `created_at`.

**6. `POST /api/admin/users/:id/notes`**

- Purpose: create a new admin note.
- Body: `{ "note": "..." }` (required, non-empty).
- Inserts into `admin.user_notes` with:
  - `user_id` from path,
  - `author_id` from current admin’s `auth.users.id`.
- Response: `{ "note": { ...inserted row... } }`.

**7. `GET /api/admin/reports/usage`** (optional, later)

- Purpose: per-user, per-day credits spent.
- Data source: `admin.vw_daily_usage_per_user`.
- Inputs:
  - `from` and `to` (ISO dates).
- Response: list of `{ user_id, day, credits_spent }`.

---

## 8. Stage 1: expected first tasks for the assistant

When a new chat starts and this file has been uploaded, the assistant should:

1. Confirm:
   - That it’s working in **Stage 1 – Core user experience & admin API**,
   - That Stage 0 (admin schema) is complete.

2. Start with:

   **Task A – Implement `GET /api/admin/users`**

   - Create `app/api/admin/users/route.ts` (or the appropriate App Router path) via PowerShell script.
   - Implement a `GET` handler that:
     - Uses Supabase server-side client.
     - Checks the current user is an admin via `admin.admin_roles`.
     - Reads query params: `page`, `pageSize`, `search`, `plan`, `status`, `sort`.
     - Queries `admin.vw_user_overview` with filters + pagination.
     - Returns JSON in the contract specified above.

3. Then proceed to:

   - **Task B:** `GET /api/admin/users/:id`
   - **Task C:** `GET /api/admin/users/:id/ledger` and `/activity`
   - **Task D:** Notes endpoints
   - **Task E:** Minimal Joe View admin UI consuming these endpoints

For each of these, the assistant should:

- Use **PowerShell scripts** to create/update files where practical.
- Show **full file contents** for any code file it touches.
- Explain new concepts in an ELI10-friendly way.

---

End of `myjoe-master-instructions-and-handover.md`.
