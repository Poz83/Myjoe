-- Harden objects flagged by Supabase Security Advisor
-- 1) Make credit view respect caller permissions (security_invoker)
-- 2) Pin search_path for core functions to avoid "Function Search Path Mutable" warnings

--------------------------------------------------------------------------------
-- 1. vw_credit_balances -> security_invoker
--------------------------------------------------------------------------------

alter view public.vw_credit_balances
  set (security_invoker = true);

--------------------------------------------------------------------------------
-- 2. Pin search_path on functions
--------------------------------------------------------------------------------

-- fn_credit_balance(p_user_id uuid)
alter function public.fn_credit_balance(uuid)
  set search_path = '';

-- updated_at trigger
alter function public.tgr_set_updated_at()
  set search_path = '';

-- block update/delete on credit_ledger trigger
alter function public.tgr_block_ledger_ud()
  set search_path = '';
