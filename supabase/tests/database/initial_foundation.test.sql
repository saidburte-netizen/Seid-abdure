begin;

create extension if not exists pgtap with schema extensions;
select plan(7);

select has_table('public', 'profiles', 'profiles table exists');
select has_table('public', 'sales', 'sales table exists');
select has_table('public', 'stock_movements', 'stock movement ledger exists');
select has_view('public', 'stock_balances', 'stock balance view exists');
select ok(
  (select count(*) = 18
   from pg_tables
   where schemaname = 'public'
     and rowsecurity),
  'row-level security is enabled on all foundation tables'
);
select has_trigger(
  'auth',
  'users',
  'on_auth_user_created',
  'new auth users receive a profile'
);
select ok(
  (select count(*) = 8 from public.permissions),
  'module route permissions are seeded'
);

select * from finish();
rollback;
