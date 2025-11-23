**SMART HANDOVER PROMPT FOR NEW CHAT (MY JOE / JOE VIEW)**

myjoe-handover-cheatsheet

You are taking over an in-progress project called **My Joe**. Please read this handover carefully. Then reply with **“Ready mate”** and a short summary of:

* What My Joe is,
* Which stage you own,
* What you plan to do first.

After that, continue from the “Next chat: Stage 1 focus” section below.

---

1. Project name & one-line summary
----------------------------------

**Project:** My Joe (a.k.a. My Joe Image Creator)  

**One-liner:** A web app that helps non-artists generate true 1-bit, black-and-white, KDP-safe colouring pages and interiors with AI — no greys, no steampunk motifs, and with strict cost controls so margins stay ≥ 40%.

The system has:

* **Frontend:** Next.js 14 (App Router) + TypeScript + Tailwind.
* **Backend:** Supabase (Postgres/Auth/Storage/RLS/Realtime).
* **Worker:** Python worker for AI pipelines and job queue.
* **Billing:** Stripe (subscriptions + credits), Resend later for email.

The app is meant to be **production-grade**, not a toy: code quality, safety, and cost discipline matter.

---

2. Repo, environment & workflow facts
-------------------------------------

**Local environment**

* OS: Windows 11.
* Shell: PowerShell.
* Repo root: `C:\myjoe\myjoe-app`.

**Git & GitHub**

* Repo: `https://github.com/Poz83/Myjoe`
* Main branch: `main` (protected; requires PR + 1 approval).
* Preferred flow:
  * Create feature branch (`feat/...`),
  * Commit changes,
  * Open PR to `main`,
  * Let CI run,
  * Merge via **squash**.
* GitHub Pro, Dependabot security alerts/updates enabled.

**CI**

* `.github/workflows/ci.yml` runs on every push/PR to `main`.
* The long-term plan is to require CI to pass before merging once it’s stable.

**Supabase**

* Staging project is linked via Supabase CLI (ref is already stored in the repo).
* Migrations live under `supabase/migrations`.
* `supabase db push` is used from `C:\myjoe\myjoe-app` to apply migrations.

**PowerShell preference**

* The owner prefers that **any task which can reasonably be done via PowerShell is the default/first option**, unless it clearly compromises safety or correctness.

---

3. Stages overview & current stage
----------------------------------

We use these working stages:

* **Stage 0 – Database & Admin Infrastructure (“Joe View foundation”)**  
  * Supabase project linking, core schema migrations, security/performance hardening.  
  * Admin-facing database schema & views to power “Joe View” (the internal admin UI).

* **Stage 1 – Core user experience & admin API**  
  * User-facing flows in Next.js (sign-up, sign-in, dashboard, simple generation flows).  
  * First pass of internal admin APIs (Joe View endpoints) wired to the Stage 0 admin schema.

* **Stage 2 – Worker & generation pipeline**  
  * Python worker, job queue, AI providers, credit-spend logic, 1-bit finisher pipeline.

* **Stage 3 – Billing & business logic**  
  * Stripe subscriptions & credits, pricing plans, usage limits, margin guards.

* **Stage 4+ – Reporting, analytics, quality-of-life**  
  * Joe View polish, analytics dashboards, multi-admin features, etc.

**Current stage for the *next* chat:**  
You are now entering **Stage 1 – Core user experience & admin API**, because **Stage 0 is complete** (see section 4).

---

4. What was done in the last chat (Stage 0 recap)
-------------------------------------------------

### 4.1 Joe View admin schema migration fixed and deployed

The previous chat focused on stabilising the **admin schema** that powers the Joe View internal admin UI.

Work completed:

1. **Fixed the Joe View admin migration:**

   * Migration file:  
     `supabase/migrations/20251123112137_joe_view_admin_schema.sql`
   * The broken references were corrected:
     * Replaced a non-existent `b.balance_credits` with  
       `coalesce(public.fn_credit_balance(u.id), 0)::numeric` in `admin.vw_user_overview`.
     * Replaced references to a non-existent `occurred_at` column in `credit_ledger` with `created_at` in `admin.vw_daily_usage_per_user`.
   * The migration now creates:
     * Schema: `admin`
     * Tables:
       * `admin.user_notes`
       * `admin.user_tags`
       * `admin.admin_roles`
     * Views:
       * `admin.vw_user_overview`
       * `admin.vw_user_activity`
       * `admin.vw_daily_usage_per_user`

2. **Applied the migration to Supabase (staging):**

   * Used `supabase db push` from `C:\myjoe\myjoe-app`.
   * Verified via `supabase migration list` that migration `20251123112137` is applied both locally and on the remote DB.

3. **Verified schema in Supabase Studio:**

   * In the **Table Editor**, with schema set to `admin`, the following objects are visible:
     * Tables: `admin_roles`, `user_notes`, `user_tags`.
     * Views: `vw_user_overview`, `vw_user_activity`, `vw_daily_usage_per_user`.
   * “View data” on each view runs without SQL errors (even if results are currently sparse).

4. **Git housekeeping:**

   * Created a feature branch:
     * `feat/joe-view-admin-schema-fix`
   * Committed the migration fix and pushed to GitHub:
     * `supabase/migrations/20251123112137_joe_view_admin_schema.sql`
   * The branch is ready for a PR into `main` if not already merged.

### 4.2 Admin JSON/API contracts designed (but not yet implemented)

As part of Stage 0, we **designed** — but did **not implement** — the API layer that will sit on top of the new admin schema.

Endpoints (each guarded by `admin.admin_roles` and Supabase Auth):

1. `GET /api/admin/users`  
   * Purpose: list users for Joe View’s left-hand user list.
   * Query params (all optional):
     * `page` (default `1`), `pageSize` (default `50`, max `100`)
     * `search` (fuzzy match on email or display_name)
     * `plan` (filter by `plan_id`)
     * `status` (filter by subscription status)
     * `sort` (`last_active_at_desc` default, or `last_active_at_asc`)
   * Response shape:
     * `data`: array of rows from `admin.vw_user_overview`
     * `pagination`: `{ page, pageSize, total }`

2. `GET /api/admin/users/:id`  
   * Purpose: right-hand Overview panel for a single user.
   * Returns a single row (or 404) from `admin.vw_user_overview`.

3. `GET /api/admin/users/:id/ledger`  
   * Purpose: “bank statement” of credit movements for that user.
   * Backed directly by `public.credit_ledger`, with pagination + optional filters.

4. `GET /api/admin/users/:id/activity`  
   * Purpose: merged timeline feed (credits, subscriptions, jobs).
   * Backed by `admin.vw_user_activity` with pagination and date filters.

5. `GET /api/admin/users/:id/notes`  
   * Purpose: read internal admin notes.
   * Backed by `admin.user_notes`.

6. `POST /api/admin/users/:id/notes`  
   * Purpose: add a new admin note.
   * Body: `{ "note": "..." }`
   * Inserts into `admin.user_notes` with `author_id` from the current admin user.

7. `GET /api/admin/reports/usage` (optional for later)  
   * Purpose: per-user, per-day credit usage between `from` and `to`.
   * Backed by `admin.vw_daily_usage_per_user`.

These contracts are **ready to be implemented** as Next.js App Router route handlers in Stage 1.

---

5. Files & paths touched (Stage 0)
----------------------------------

The last chat primarily touched:

* `supabase/migrations/20251123112137_joe_view_admin_schema.sql`  
  * Rewritten to correctly define:
    * `admin` schema,
    * `admin.user_notes`, `admin.user_tags`, `admin.admin_roles`,
    * `admin.vw_user_overview`, `admin.vw_user_activity`, `admin.vw_daily_usage_per_user`.

Other key locations (read/used but not fully rewritten in the last chat):

* Root: `C:\myjoe\myjoe-app`
* Supabase migrations directory: `C:\myjoe\myjoe-app\supabase\migrations\`

There are some extra untracked folders (e.g. `supabase/.temp/`, `supabase/migrations_backup_...`, `archive/`, `docs/handover/`), but those were not committed or relied upon.

---

6. Commands run (Stage 0)
-------------------------

These are the **key commands and patterns** that were used and can be reused.

**PowerShell (migration file overwrite pattern)**

Used to overwrite the admin migration file with known-good SQL:

```powershell
$migrationPath = "supabase/migrations/20251123112137_joe_view_admin_schema.sql"

@'
-- (full admin schema SQL here: admin schema, tables, views)
