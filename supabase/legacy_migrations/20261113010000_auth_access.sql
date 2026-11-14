create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', '')
  );
  return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

insert into public.permissions (permission_key, description)
values
  ('production.read', 'Access production module'),
  ('sales.read', 'Access sales and point-of-sale module'),
  ('inventory.read', 'Access inventory module'),
  ('cash.read', 'Access cash management module'),
  ('people.read', 'Access people and HR module'),
  ('rentals.read', 'Access rentals module'),
  ('reports.read', 'Access reports module'),
  ('settings.manage', 'Manage application settings')
on conflict (permission_key) do nothing;
