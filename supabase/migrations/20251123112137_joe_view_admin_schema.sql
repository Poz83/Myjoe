-- Joe View admin schema: overview, notes/tags, roles, activity, usage

-- 1) Admin schema
create schema if not exists admin;

--------------------------------------------------------------------------------
-- 2) User overview view
--    One row per user: identity, plan, status, balance, simple usage stats
--------------------------------------------------------------------------------

create or replace view admin.vw_user_overview
with (security_invoker = true)
as
select
  u.id                                as user_id,
  u.email,
  p.display_name,
  s.plan_id,
  pl.name                             as plan_name,
  s.status                            as subscription_status,
  coalesce(public.fn_credit_balance(u.id), 0)::numeric as credit_balance,
  count(distinct pr.id)               as project_count,
  count(distinct j.id)                as job_count,
  count(distinct g.id)                as generation_count,
  coalesce(u.last_sign_in_at, u.created_at) as last_active_at
from auth.users u
left join public.profiles      p  on p.id = u.id
left join public.subscriptions s  on s.user_id = u.id
left join public.plans         pl on pl.id = s.plan_id
left join public.projects      pr on pr.user_id = u.id
left join public.jobs          j  on j.project_id = pr.id
left join public.generations   g  on g.job_id = j.id
group by
  u.id, u.email, p.display_name,
  s.plan_id, pl.name, s.status,
  u.last_sign_in_at, u.created_at;

--------------------------------------------------------------------------------
-- 3) Admin notes and tags
--------------------------------------------------------------------------------

create table if not exists admin.user_notes (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  author_id   uuid not null references auth.users(id),
  note        text not null,
  created_at  timestamptz not null default now()
);

create table if not exists admin.user_tags (
  user_id     uuid not null references auth.users(id) on delete cascade,
  tag         text not null,
  created_at  timestamptz not null default now(),
  created_by  uuid not null references auth.users(id),
  primary key (user_id, tag)
);

--------------------------------------------------------------------------------
-- 4) Admin roles
--------------------------------------------------------------------------------

create table if not exists admin.admin_roles (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  role       text not null check (role in ('owner', 'support', 'read_only')),
  granted_at timestamptz not null default now()
);

--------------------------------------------------------------------------------
-- 5) User activity timeline view
--    Combines credit ledger, subscription events, jobs into one feed
--------------------------------------------------------------------------------

create or replace view admin.vw_user_activity
with (security_invoker = true)
as
select
  cl.user_id,
  cl.created_at                       as occurred_at,
  'credit_ledger'::text               as source,
  cl.id::text                         as source_id,
  cl.reason::text                     as summary,
  cl.delta_credits                    as delta_credits
from public.credit_ledger cl

union all

select
  s.user_id,
  s.updated_at                        as occurred_at,
  'subscription'::text                as source,
  s.id::text                          as source_id,
  concat('Subscription ', s.status)   as summary,
  null::numeric                       as delta_credits
from public.subscriptions s

union all

select
  j.user_id,
  j.created_at                        as occurred_at,
  'job'::text                         as source,
  j.id::text                          as source_id,
  concat('Job ', j.id, ' (', j.status::text, ')') as summary,
  null::numeric                       as delta_credits
from public.jobs j;

--------------------------------------------------------------------------------
-- 6) Daily usage per user view (for charts and reports)
--------------------------------------------------------------------------------

create or replace view admin.vw_daily_usage_per_user
with (security_invoker = true)
as
select
  cl.user_id,
  date_trunc('day', cl.created_at)::date as day,
  sum(
    case
      when cl.delta_credits < 0 then -cl.delta_credits
      else 0
    end
  ) as credits_spent
from public.credit_ledger cl
group by cl.user_id, date_trunc('day', cl.created_at)::date;
