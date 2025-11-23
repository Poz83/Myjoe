-- ============================================================
-- My Joe – Core Schema (Palladium v1)
-- One migration that defines the main tables, RLS, and core
-- credit + job logic. Designed to be safe to re-run in a fresh
-- database.
-- ============================================================

-- === Extensions ===
create extension if not exists pgcrypto;  -- for gen_random_uuid()

-- === Types ===
do $$
begin
  if not exists (select 1 from pg_type where typname = 'job_status') then
    create type job_status as enum ('pending','in_progress','completed','failed','cancelled');
  end if;
  if not exists (select 1 from pg_type where typname = 'ledger_reason') then
    create type ledger_reason as enum ('grant','burn','topup','refund','adjustment');
  end if;
end$$;

-- === Private schema for sensitive functions ===
create schema if not exists app_private;
revoke all on schema app_private from public;

-- ============================================================
-- TABLES
-- ============================================================

-- 1) profiles: user metadata + trial flags
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  is_admin boolean not null default false,
  trial_enabled boolean not null default true,
  trial_images_remaining int not null default 10,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 2) plans: plan catalogue (Lite/Pro/Max)
create table if not exists public.plans (
  id text primary key, -- 'lite','pro','max'
  name text not null,
  monthly_price_usd numeric(10,2) not null,
  monthly_credits int not null,
  features jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.plans (id, name, monthly_price_usd, monthly_credits, features)
values
  ('lite','Lite',9.99,115,'{"vector": false, "fix_upscale": false}'::jsonb),
  ('pro','Pro',29.99,375,'{"vector": false, "fix_upscale": true}'::jsonb),
  ('max','Max',59.99,800,'{"vector": true, "fix_upscale": true}'::jsonb)
on conflict (id) do nothing;

-- 3) subscriptions: link users to plans and Stripe
create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_id text not null references public.plans(id),
  status text not null, -- 'trialing','active','past_due','canceled','incomplete',...
  stripe_customer_id text,
  stripe_subscription_id text,
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists subs_user_idx on public.subscriptions(user_id);

-- one active-like subscription per user
create unique index if not exists subs_one_active_per_user
on public.subscriptions(user_id)
where status in ('trialing','active','past_due','incomplete');

-- stripe subscription id unique when present
create unique index if not exists subs_stripe_sub_uidx
on public.subscriptions(stripe_subscription_id)
where stripe_subscription_id is not null;


-- 4) projects: books/projects
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists projects_user_idx on public.projects(user_id, created_at desc);


-- 5) jobs: async work items (queue)
create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  project_id uuid references public.projects(id) on delete set null,
  type text not null, -- 'raster','fix_upscale','vector'
  payload jsonb not null,
  status job_status not null default 'pending',

  priority int not null default 100,
  scheduled_at timestamptz not null default now(),

  locked_by text,
  locked_at timestamptz,

  attempts int not null default 0,
  max_attempts int not null default 3,
  last_error text,

  client_request_id text, -- optional client-side idempotency key

  started_at timestamptz,
  completed_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists jobs_status_sched_idx
  on public.jobs(status, scheduled_at, priority, created_at);
create index if not exists jobs_user_created_idx
  on public.jobs(user_id, created_at desc);
create index if not exists jobs_locked_by_idx
  on public.jobs(locked_by);
create unique index if not exists jobs_client_request_uidx
  on public.jobs(user_id, client_request_id)
  where client_request_id is not null;

-- coherence / safety checks
alter table public.jobs
  add constraint jobs_attempts_check
  check (attempts >= 0 and max_attempts >= 1 and attempts <= max_attempts)
  not valid;
alter table public.jobs validate constraint jobs_attempts_check;

alter table public.jobs
  add constraint jobs_lock_coherence
  check (
    (status = 'in_progress' and locked_by is not null and locked_at is not null)
    or (status <> 'in_progress' and locked_by is null and locked_at is null)
  ) not valid;
alter table public.jobs validate constraint jobs_lock_coherence;

alter table public.jobs
  add constraint jobs_completed_has_ts
  check (
    (status <> 'completed') or (completed_at is not null)
  ) not valid;
alter table public.jobs validate constraint jobs_completed_has_ts;


-- 6) generations: image outputs & metadata
create table if not exists public.generations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  project_id uuid references public.projects(id) on delete set null,
  job_id uuid references public.jobs(id) on delete set null,

  status text not null default 'completed', -- 'completed','failed'
  provider text,
  model text,
  width int,
  height int,
  dpi int,
  bit_depth int,           -- 1 or 8
  file_ext text,           -- 'png','pdf','svg', etc.
  storage_path text not null,
  thumb_path text,

  cost_estimated_usd numeric(12,6),
  cost_measured_usd numeric(12,6),
  qc jsonb,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists gens_user_idx
  on public.generations(user_id, created_at desc);
create index if not exists gens_project_idx
  on public.generations(project_id, created_at desc);
create unique index if not exists gens_storage_path_uidx
  on public.generations(storage_path);

alter table public.generations
  add constraint gens_dim_check
  check (width > 0 and height > 0 and dpi between 72 and 1200)
  not valid;
alter table public.generations validate constraint gens_dim_check;

alter table public.generations
  add constraint gens_bitdepth_check
  check (bit_depth in (1,8))
  not valid;
alter table public.generations validate constraint gens_bitdepth_check;


-- 7) credit_ledger: append-only credit movements
create table if not exists public.credit_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  reason ledger_reason not null,
  delta_credits numeric(12,2) not null,  -- burns negative; grants/topups positive
  operation_type text,                   -- 'raster','vector','fix_upscale',...
  job_id uuid references public.jobs(id) on delete set null,
  generation_id uuid references public.generations(id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists credit_ledger_user_idx
  on public.credit_ledger(user_id, created_at desc);

alter table public.credit_ledger
  add constraint ledger_nonzero check (delta_credits <> 0)
  not valid;
alter table public.credit_ledger validate constraint ledger_nonzero;

alter table public.credit_ledger
  add constraint ledger_reason_sign check (
    (reason = 'burn' and delta_credits < 0)
    or (reason in ('grant','topup','refund','adjustment') and delta_credits > 0)
  ) not valid;
alter table public.credit_ledger validate constraint ledger_reason_sign;


-- 8) cost_events: provider usage & costs
create table if not exists public.cost_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  job_id uuid references public.jobs(id) on delete set null,
  provider text not null,
  model text,
  usage jsonb,                  -- tokens, seconds, image_count, etc.
  cost_usd numeric(12,6),
  created_at timestamptz not null default now()
);

create index if not exists cost_events_user_idx
  on public.cost_events(user_id, created_at desc);
create index if not exists cost_events_job_idx
  on public.cost_events(job_id);


-- 9) provider_prices: live unit pricing for Governor
create table if not exists public.provider_prices (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  model text not null,
  unit text not null,             -- 'image','1k_tokens','sec'
  unit_price_usd numeric(12,6) not null,
  active boolean not null default true,
  meta jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create unique index if not exists provider_prices_uidx
  on public.provider_prices(provider, model, unit);

alter table public.provider_prices
  add constraint provider_prices_nonneg
  check (unit_price_usd >= 0)
  not valid;
alter table public.provider_prices validate constraint provider_prices_nonneg;


-- 10) idempotency_keys: avoid double-enqueue
create table if not exists public.idempotency_keys (
  user_id uuid not null references auth.users(id) on delete cascade,
  scope text not null,     -- e.g. 'enqueue'
  key text not null,       -- client-provided idempotency key
  job_id uuid references public.jobs(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (user_id, scope, key)
);


-- 11) stripe_events: webhook dedupe
create table if not exists public.stripe_events (
  id text primary key,          -- Stripe event ID
  type text,
  payload jsonb,
  received_at timestamptz not null default now()
);


-- ============================================================
-- VIEWS & FUNCTIONS
-- ============================================================

-- credit balance helper
create or replace view public.vw_credit_balances as
  select user_id, coalesce(sum(delta_credits),0)::numeric(12,2) as balance
  from public.credit_ledger
  group by user_id;

create or replace function public.fn_credit_balance(p_user_id uuid)
returns numeric
language sql
stable
security invoker
as $$
  select coalesce(sum(delta_credits),0)::numeric
  from public.credit_ledger
  where user_id = p_user_id;
$$;


-- updated_at trigger
create or replace function public.tgr_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end$$;

do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'tgr_upd_profiles') then
    create trigger tgr_upd_profiles before update on public.profiles
      for each row execute function public.tgr_set_updated_at();
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'tgr_upd_plans') then
    create trigger tgr_upd_plans before update on public.plans
      for each row execute function public.tgr_set_updated_at();
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'tgr_upd_subscriptions') then
    create trigger tgr_upd_subscriptions before update on public.subscriptions
      for each row execute function public.tgr_set_updated_at();
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'tgr_upd_projects') then
    create trigger tgr_upd_projects before update on public.projects
      for each row execute function public.tgr_set_updated_at();
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'tgr_upd_jobs') then
    create trigger tgr_upd_jobs before update on public.jobs
      for each row execute function public.tgr_set_updated_at();
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'tgr_upd_generations') then
    create trigger tgr_upd_generations before update on public.generations
      for each row execute function public.tgr_set_updated_at();
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'tgr_upd_credit_ledger') then
    create trigger tgr_upd_credit_ledger before update on public.credit_ledger
      for each row execute function public.tgr_set_updated_at();
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'tgr_upd_provider_prices') then
    create trigger tgr_upd_provider_prices before update on public.provider_prices
      for each row execute function public.tgr_set_updated_at();
  end if;
end$$;


-- append-only ledger guard
create or replace function public.tgr_block_ledger_ud()
returns trigger
language plpgsql
as $$
begin
  raise exception 'append-only: credit_ledger is immutable';
end$$;

do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'credit_ledger_no_update') then
    create trigger credit_ledger_no_update before update on public.credit_ledger
      for each statement execute function public.tgr_block_ledger_ud();
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'credit_ledger_no_delete') then
    create trigger credit_ledger_no_delete before delete on public.credit_ledger
      for each statement execute function public.tgr_block_ledger_ud();
  end if;
end$$;


-- core atomic enqueue + burn (private)
create or replace function app_private.sp_enqueue_and_burn_core(
  p_user_id uuid,
  p_project_id uuid,
  p_job_type text,
  p_operation_type text,
  p_burn_credits numeric(12,2),
  p_payload jsonb,
  p_priority int default 100,
  p_idempotency_key text default null,
  p_scope text default 'enqueue'
) returns uuid
language plpgsql
security definer
set search_path = public, app_private
as $$
declare
  v_uid uuid;
  v_balance numeric;
  v_job_id uuid;
begin
  -- determine caller
  if auth.role() = 'service_role' then
    v_uid := p_user_id;
  else
    v_uid := auth.uid();
    if v_uid is null or v_uid <> p_user_id then
      raise exception 'unauthorized_user_mismatch';
    end if;
  end if;

  -- idempotency (optional)
  if p_idempotency_key is not null then
    insert into public.idempotency_keys(user_id, scope, key)
    values (v_uid, coalesce(p_scope,'enqueue'), p_idempotency_key)
    on conflict do nothing;

    select job_id into v_job_id
    from public.idempotency_keys
    where user_id = v_uid
      and scope = coalesce(p_scope,'enqueue')
      and key = p_idempotency_key
      and job_id is not null;

    if v_job_id is not null then
      return v_job_id;
    end if;
  end if;

  -- serialize burns per user
  perform 1
  from public.profiles
  where id = v_uid
  for update;
  if not found then
    insert into public.profiles(id) values (v_uid)
    on conflict do nothing;
    perform 1 from public.profiles where id = v_uid for update;
  end if;

  select public.fn_credit_balance(v_uid) into v_balance;
  if v_balance < p_burn_credits then
    raise exception 'insufficient_credits';
  end if;

  -- create job
  insert into public.jobs(user_id, project_id, type, payload, priority, scheduled_at)
  values (v_uid, p_project_id, p_job_type, p_payload, coalesce(p_priority,100), now())
  returning id into v_job_id;

  -- burn credits (negative)
  insert into public.credit_ledger(user_id, reason, delta_credits, operation_type, job_id, notes)
  values (v_uid, 'burn', -1 * p_burn_credits, p_operation_type, v_job_id, 'burn via core');

  -- back-fill idempotency mapping
  if p_idempotency_key is not null then
    update public.idempotency_keys
    set job_id = v_job_id
    where user_id = v_uid
      and scope = coalesce(p_scope,'enqueue')
      and key = p_idempotency_key
      and job_id is null;
  end if;

  return v_job_id;
end
$$;

-- public wrapper
create or replace function public.sp_enqueue_and_burn(
  p_user_id uuid,
  p_project_id uuid,
  p_job_type text,
  p_operation_type text,
  p_burn_credits numeric(12,2),
  p_payload jsonb,
  p_priority int default 100,
  p_idempotency_key text default null,
  p_scope text default 'enqueue'
) returns uuid
language sql
security definer
set search_path = public, app_private
as $$
  select app_private.sp_enqueue_and_burn_core(
    p_user_id, p_project_id, p_job_type, p_operation_type,
    p_burn_credits, p_payload, p_priority, p_idempotency_key, p_scope
  );
$$;

-- ============================================================
-- RLS (Row Level Security)
-- ============================================================

-- enable RLS
alter table public.profiles          enable row level security;
alter table public.plans             enable row level security;
alter table public.subscriptions     enable row level security;
alter table public.projects          enable row level security;
alter table public.jobs              enable row level security;
alter table public.generations       enable row level security;
alter table public.credit_ledger     enable row level security;
alter table public.cost_events       enable row level security;
alter table public.provider_prices   enable row level security;
alter table public.idempotency_keys  enable row level security;
alter table public.stripe_events     enable row level security;

-- profiles: owner read/update; inserts via service_role
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select using (id = auth.uid());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "profiles_insert_srv" on public.profiles;
create policy "profiles_insert_srv" on public.profiles
  for insert with check (auth.role() = 'service_role');

-- plans: read for authenticated; write by service_role
drop policy if exists "plans_read" on public.plans;
create policy "plans_read" on public.plans
  for select using (auth.role() in ('authenticated','service_role'));

drop policy if exists "plans_write_srv" on public.plans;
create policy "plans_write_srv" on public.plans
  for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

-- subscriptions: owner read; service_role writes
drop policy if exists "subs_select_own" on public.subscriptions;
create policy "subs_select_own" on public.subscriptions
  for select using (user_id = auth.uid());

drop policy if exists "subs_write_srv" on public.subscriptions;
create policy "subs_write_srv" on public.subscriptions
  for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

-- projects: owner full CRUD
drop policy if exists "projects_owner_select" on public.projects;
create policy "projects_owner_select" on public.projects
  for select using (user_id = auth.uid());

drop policy if exists "projects_owner_insert" on public.projects;
create policy "projects_owner_insert" on public.projects
  for insert with check (user_id = auth.uid());

drop policy if exists "projects_owner_update" on public.projects;
create policy "projects_owner_update" on public.projects
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "projects_owner_delete" on public.projects;
create policy "projects_owner_delete" on public.projects
  for delete using (user_id = auth.uid());

-- jobs: owner can read; writes only via service_role (server actions/worker)
drop policy if exists "jobs_select_own" on public.jobs;
create policy "jobs_select_own" on public.jobs
  for select using (user_id = auth.uid());

drop policy if exists "jobs_write_srv" on public.jobs;
create policy "jobs_write_srv" on public.jobs
  for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

-- generations: owner read; writes by service_role
drop policy if exists "gens_select_own" on public.generations;
create policy "gens_select_own" on public.generations
  for select using (user_id = auth.uid());

drop policy if exists "gens_write_srv" on public.generations;
create policy "gens_write_srv" on public.generations
  for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

-- credit_ledger: owner read; insert-only via service_role (append-only)
drop policy if exists "ledger_select_own" on public.credit_ledger;
create policy "ledger_select_own" on public.credit_ledger
  for select using (user_id = auth.uid());

drop policy if exists "ledger_insert_srv" on public.credit_ledger;
create policy "ledger_insert_srv" on public.credit_ledger
  for insert with check (auth.role() = 'service_role');

-- cost_events: owner read; writes by service_role
drop policy if exists "cost_select_own" on public.cost_events;
create policy "cost_select_own" on public.cost_events
  for select using (user_id = auth.uid());

drop policy if exists "cost_write_srv" on public.cost_events;
create policy "cost_write_srv" on public.cost_events
  for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

-- provider_prices: read to authenticated; writes by service_role
drop policy if exists "pp_read" on public.provider_prices;
create policy "pp_read" on public.provider_prices
  for select using (auth.role() in ('authenticated','service_role'));

drop policy if exists "pp_write_srv" on public.provider_prices;
create policy "pp_write_srv" on public.provider_prices
  for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

-- idempotency_keys: owner read; writes by service_role
drop policy if exists "idemp_select_own" on public.idempotency_keys;
create policy "idemp_select_own" on public.idempotency_keys
  for select using (user_id = auth.uid());

drop policy if exists "idemp_write_srv" on public.idempotency_keys;
create policy "idemp_write_srv" on public.idempotency_keys
  for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

-- stripe_events: service_role only
drop policy if exists "stripe_ev_read_srv" on public.stripe_events;
create policy "stripe_ev_read_srv" on public.stripe_events
  for select using (auth.role() = 'service_role');

drop policy if exists "stripe_ev_write_srv" on public.stripe_events;
create policy "stripe_ev_write_srv" on public.stripe_events
  for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

-- ============================================================
-- End Palladium schema v1
-- ============================================================
