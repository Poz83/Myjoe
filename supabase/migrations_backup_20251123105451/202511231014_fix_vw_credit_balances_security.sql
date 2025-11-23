-- Make vw_credit_balances respect caller permissions and RLS
alter view public.vw_credit_balances
  set (security_invoker = true);
