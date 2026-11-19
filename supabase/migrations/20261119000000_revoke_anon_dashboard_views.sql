-- The dashboard read views are authenticated-only.
--
-- The live schema snapshot granted SELECT on these views to anon. The
-- original view migration only added the authenticated grant, so a fresh
-- Supabase stack still exposed the views to anonymous callers. Revoke the
-- inherited and direct grants explicitly, then restore the authenticated
-- grant. This is idempotent and safe on databases where the grant was never
-- present.

revoke all on public.v_stock_overview from anon;
revoke all on public.v_dashboard_overview from anon;
revoke all on public.v_cashflow_daily from anon;

revoke all on public.v_stock_overview from public;
revoke all on public.v_dashboard_overview from public;
revoke all on public.v_cashflow_daily from public;

grant select on public.v_stock_overview to authenticated;
grant select on public.v_dashboard_overview to authenticated;
grant select on public.v_cashflow_daily to authenticated;
