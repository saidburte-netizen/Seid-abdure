-- 20261115000001_security_hardening.sql
--
-- Security hardening for the live Supabase project.
--
-- This migration is safe to run more than once. It does not change table data.
--
-- What it does:
--   1. Makes every public view run with the caller's RLS permissions.
--   2. Removes anon's table, view and sequence access.
--   3. Revokes execute on every public function, then grants only the
--      functions the app and RLS policies actually need.
--   4. Sets file-size and MIME limits on every storage bucket.
--
-- Apply this after 20261114000016_void_sale.sql.

begin;

-- 1. Views must not bypass RLS. PostgreSQL 15+ supports security_invoker.
do $$
declare
  target_view regclass;
begin
  for target_view in
    select c.oid::regclass
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'v'
  loop
    execute format(
      'alter view %s set (security_invoker = true)',
      target_view
    );
  end loop;
end
$$;

-- 2. Anonymous callers only need the two login helpers. They do not need
--    table, view or sequence access. The app always signs in first.
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;

-- 3. Functions. Start from zero so a previously over-broad grant cannot
--    survive. Then grant the minimum needed by the app and by RLS.
revoke execute on all functions in schema public from public;
revoke execute on all functions in schema public from anon;
revoke execute on all functions in schema public from authenticated;

-- Intentionally callable before login:
grant execute on function public.has_admin() to anon, authenticated;
grant execute on function public.customer_signup_allowed() to anon, authenticated;

-- RLS and storage policy helpers used by signed-in users:
grant execute on function public.can_read_bucket(text) to authenticated;
grant execute on function public.can_write_bucket(text) to authenticated;
grant execute on function public.current_customer_id() to authenticated;
grant execute on function public.current_employee_id() to authenticated;
grant execute on function public.current_role_code() to authenticated;
grant execute on function public.has_any_role(text[]) to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_staff() to authenticated;

-- Application RPCs:
grant execute on function public.next_number(text) to authenticated;
grant execute on function public.fn_close_day(uuid, date, numeric, text) to authenticated;
grant execute on function public.fn_generate_alerts() to authenticated;
grant execute on function public.fn_generate_payroll(uuid) to authenticated;
grant execute on function public.fn_generate_rent_invoices(date) to authenticated;
grant execute on function public.void_sale(uuid, text) to authenticated;

-- 4. Storage bucket limits. Public image buckets are image-only; private
--    document buckets accept PDFs and images only.
update storage.buckets
set
  file_size_limit = 5 * 1024 * 1024,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id in ('avatars', 'product-images', 'branding');

update storage.buckets
set
  file_size_limit = 10 * 1024 * 1024,
  allowed_mime_types = array['application/pdf', 'image/jpeg', 'image/png']
where id in ('receipts', 'employee-documents', 'contracts');

commit;
