begin;

create extension if not exists pgtap with schema extensions;
select plan(5);

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

select * from finish();
rollback;
