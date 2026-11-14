-- One-time SQL required by the app's sign-in screen.
--
-- The app calls this RPC before showing "Create the first account". It must
-- be installed in the live project once. Security definer keeps it usable by
-- anonymous visitors without exposing the profiles table directly.
create or replace function public.has_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where role_code = 'admin'
  );
$$;

grant execute on function public.has_admin() to anon, authenticated;
