-- Add indexes for foreign keys flagged by Supabase Performance Advisor

--------------------------------------------------------------------------------
-- credit_ledger
--   credit_ledger_generation_id_fkey -> generation_id
--   credit_ledger_job_id_fkey        -> job_id
--------------------------------------------------------------------------------

create index if not exists credit_ledger_generation_id_idx
  on public.credit_ledger (generation_id);

create index if not exists credit_ledger_job_id_idx
  on public.credit_ledger (job_id);

--------------------------------------------------------------------------------
-- generations
--   generations_job_id_fkey -> job_id
--------------------------------------------------------------------------------

create index if not exists generations_job_id_idx
  on public.generations (job_id);

--------------------------------------------------------------------------------
-- idempotency_keys
--   idempotency_keys_job_id_fkey -> job_id
--------------------------------------------------------------------------------

create index if not exists idempotency_keys_job_id_idx
  on public.idempotency_keys (job_id);

--------------------------------------------------------------------------------
-- jobs
--   jobs_project_id_fkey -> project_id
--------------------------------------------------------------------------------

create index if not exists jobs_project_id_idx
  on public.jobs (project_id);

--------------------------------------------------------------------------------
-- subscriptions
--   subscriptions_plan_id_fkey -> plan_id
--------------------------------------------------------------------------------

create index if not exists subscriptions_plan_id_idx
  on public.subscriptions (plan_id);
