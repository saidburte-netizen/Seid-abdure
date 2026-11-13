begin;

create extension if not exists pgtap with schema extensions;
select plan(29);

-- Core operational tables.
select has_table('public', 'products', 'catalog table exists');
select has_table('public', 'stock_movements', 'stock ledger exists');
select has_table('public', 'sales', 'sales table exists');
select has_table('public', 'sale_items', 'sale lines exist');
select has_table('public', 'customers', 'customers table exists');
select has_table('public', 'cash_accounts', 'cash accounts exist');
select has_table('public', 'employees', 'employees table exists');
select has_table('public', 'payroll_runs', 'payroll runs exist');
select has_table('public', 'payslips', 'payslips exist');
select has_table('public', 'leases', 'leases exist');
select has_table('public', 'rent_invoices', 'rent invoices exist');
select has_table('public', 'suppliers', 'suppliers exist');
select has_table('public', 'bills', 'supplier bills exist');
select has_table('public', 'notifications', 'notifications exist');
select has_table('public', 'audit_logs', 'audit log exists');

-- Reporting and helper views.
select has_view('public', 'stock_balances', 'stock balances view exists');
select has_view('public', 'rent_roll', 'rent roll view exists');
select has_view('public', 'supplier_payables', 'supplier payables view exists');
select has_view('public', 'rls_coverage', 'RLS coverage view exists');

-- Server-side write paths.
select has_function('public', 'complete_sale', 'atomic POS sale RPC exists');
select has_function('public', 'process_sale_return', 'sale return RPC exists');
select has_function('public', 'run_payroll', 'payroll RPC exists');
select has_function('public', 'generate_rent_invoices', 'rent invoice RPC exists');
select has_function('public', 'bootstrap_first_owner', 'owner bootstrap RPC exists');
select has_function('public', 'audit_row_change', 'generic audit trigger exists');

-- No public table may be left outside row-level security.
select ok(
  (select bool_and(rowsecurity) from pg_tables where schemaname = 'public'),
  'row-level security is enabled on every public table'
);
select ok(
  not exists (
    select 1 from public.rls_coverage
    where rls_enabled = false or policy_count = 0
  ),
  'every public table has at least one RLS policy'
);
select ok(
  (select count(*) >= 29 from public.permissions),
  'permission catalog includes all module permissions'
);
select ok(
  (select legal_name = 'Brade and Cake House' from public.organization_settings),
  'organization defaults use the official business name'
);

select * from finish();
rollback;
