-- End-to-end contract test for the live schema fixture.
--
-- Run against a disposable local Supabase database after applying
-- supabase/fixtures/live_schema.sql. Everything is wrapped in a transaction
-- and rolled back. No live project is contacted.
--
--   psql "$LOCAL_DB_URL" -v ON_ERROR_STOP=1 -f contract.sql

begin;

-- Keep current_date, sale dates and cash transaction dates on the same
-- business day. The close-day function reports in Africa/Addis_Ababa.
set local timezone = 'Africa/Addis_Ababa';

create or replace function pg_temp.assert_true(condition boolean, message text)
returns void
language plpgsql
as $$
begin
  if condition is not true then
    raise exception 'ASSERTION FAILED: %', message;
  end if;
end;
$$;

-- Assert that a statement fails. The optional fragment must appear in the
-- database error so a wrong failure cannot pass the test.
create or replace function pg_temp.assert_raises(statement text, fragment text, message text)
returns void
language plpgsql
as $$
declare
  v_raised boolean := false;
begin
  begin
    execute statement;
  exception when others then
    v_raised := true;
    if fragment is not null and position(fragment in sqlerrm) = 0 then
      raise exception 'ASSERTION FAILED: % (unexpected error: %)', message, sqlerrm;
    end if;
  end;
  if not v_raised then
    raise exception 'ASSERTION FAILED: %', message;
  end if;
end;
$$;

-- Deterministic test identifiers.
-- branch / store / catalog
-- 11111111-... branch
-- 22222222-... store
-- 33333333-... unit
-- 44444444-... category
-- 55555555-... items
-- 66666666-... product
-- 77777777-... customer
-- 88888888-... cash accounts
-- 99999999-... supplier
-- aaaaaaaa-... employee
-- bbbbbbbb-... property
-- cccccccc-... tenant
-- dddddddd-... lease
-- eeeeeeee-... payroll run
-- ffffffff-... purchase order
-- 12121212-... expense category
-- 13131313-... cash sale
-- 14141414-... credit sale
-- 15151515-... payable
-- 16161616-... payable payment
-- 17171717-... goods receipt
-- 18181818-... stock count
-- 19191919-... production batch
-- 20202020-... recipe
-- 21212121-... cash transfer

insert into public.branches (id, code, name, is_active)
values ('11111111-1111-1111-1111-111111111111', 'TEST', 'Test Branch', true);

insert into public.stores (id, branch_id, name, store_type, is_active)
values
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Test Store', 'main', true),
  ('23232323-2323-2323-2323-232323232323', '11111111-1111-1111-1111-111111111111', 'Test Branch Store', 'shop', true);

insert into public.units (id, code, name, name_am, name_om)
values ('33333333-3333-3333-3333-333333333333', 'test_pcs', 'Test piece', 'የሙከራ ቁራጭ', 'Qaama qorannoo');

insert into public.categories (id, kind, name, name_am, name_om, is_active)
values ('44444444-4444-4444-4444-444444444444', 'product', 'Test category', 'የሙከራ ምድብ', 'Ramaddii qorannoo', true);

insert into public.items (id, sku, name, item_type, category_id, unit_id, cost_price, min_stock, is_active)
values
  ('55555555-5555-5555-5555-555555555501', 'TEST-PO-ITEM', 'PO item', 'raw_material', '44444444-4444-4444-4444-444444444444', '33333333-3333-3333-3333-333333333333', 5, 0, true),
  ('55555555-5555-5555-5555-555555555502', 'TEST-SALE-ITEM', 'Sale item', 'finished_good', '44444444-4444-4444-4444-444444444444', '33333333-3333-3333-3333-333333333333', 20, 1, true),
  ('55555555-5555-5555-5555-555555555503', 'TEST-RAW-ITEM', 'Raw item', 'raw_material', '44444444-4444-4444-4444-444444444444', '33333333-3333-3333-3333-333333333333', 2, 0, true),
  ('55555555-5555-5555-5555-555555555504', 'TEST-VOID-ITEM', 'Void test item', 'finished_good', '44444444-4444-4444-4444-444444444444', '33333333-3333-3333-3333-333333333333', 20, 0, true);

insert into public.products (id, sku, name, name_am, name_om, category_id, item_id, unit_id, price, cost, tax_rate, is_active)
values
  ('66666666-6666-6666-6666-666666666666', 'TEST-PROD-1', 'Test product', 'የሙከራ ምርት', 'Oomisha qorannoo', '44444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555502', '33333333-3333-3333-3333-333333333333', 50, 20, 0, true),
  ('67676767-6767-6767-6767-676767676767', 'TEST-SERVICE-1', 'Test service', 'የሙከራ አገልግሎት', 'Tajaajila qorannoo', '44444444-4444-4444-4444-444444444444', null, '33333333-3333-3333-3333-333333333333', 60, 0, 0, true),
  ('68686868-6868-6868-6868-686868686868', 'TEST-VOID-PROD', 'Void test product', 'የሙከራ ስረዛ ምርት', 'Oomisha qorannoo haqaa', '44444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555504', '33333333-3333-3333-3333-333333333333', 50, 20, 0, true);

insert into public.customers (id, code, full_name, phone, customer_type, credit_limit, is_active)
values ('77777777-7777-7777-7777-777777777777', 'TEST-CUST-1', 'Test customer', '0911000000', 'retail', 1000, true);

insert into public.cash_accounts (id, branch_id, name, account_type, opening_balance, is_active)
values
  ('88888888-8888-8888-8888-888888888881', '11111111-1111-1111-1111-111111111111', 'Test cash drawer', 'cash_drawer', 0, true),
  ('88888888-8888-8888-8888-888888888882', '11111111-1111-1111-1111-111111111111', 'Test safe', 'safe', 0, true),
  ('88888888-8888-8888-8888-888888888883', '11111111-1111-1111-1111-111111111111', 'Void test drawer', 'cash_drawer', 0, true);

insert into public.suppliers (id, name, payment_terms_days, is_active)
values ('99999999-9999-9999-9999-999999999999', 'Test supplier', 30, true);

insert into public.expense_categories (id, name, kind, is_active)
values ('12121212-1212-1212-1212-121212121212', 'Sales Income', 'income', true);

insert into public.tenants (id, full_name, phone, is_active)
values ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Test tenant', '0911000001', true);

insert into public.properties (id, code, name, property_type, branch_id, monthly_rent, status, is_active)
values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'TEST-PROP-1', 'Test property', 'shop', '11111111-1111-1111-1111-111111111111', 5000, 'occupied', true);

insert into public.leases (id, lease_no, property_id, tenant_id, start_date, end_date, rent_amount, billing_frequency, status, created_by)
values (
  'dddddddd-dddd-dddd-dddd-dddddddddddd',
  'TEST-LEASE-1',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  date_trunc('month', current_date)::date,
  (date_trunc('month', current_date) + interval '1 year')::date,
  5000,
  'monthly',
  'active',
  null
);

-- Auth users: the first profile becomes admin, later ones become customers.
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
) values
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@test.local', 'test-hash', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Test Admin"}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'manager@test.local', 'test-hash', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Test Manager"}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cashier@test.local', 'test-hash', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Test Cashier"}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'baker@test.local', 'test-hash', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Test Baker"}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'store@test.local', 'test-hash', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Test Store Keeper"}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'hr@test.local', 'test-hash', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Test HR"}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'accountant@test.local', 'test-hash', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Test Accountant"}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'staff@test.local', 'test-hash', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Test Staff"}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'customer@test.local', 'test-hash', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Test Customer"}', now(), now(), '', '', '', '');

update public.profiles set role_code = 'admin', branch_id = '11111111-1111-1111-1111-111111111111' where id = '00000000-0000-0000-0000-000000000001';
update public.profiles set role_code = 'manager', branch_id = '11111111-1111-1111-1111-111111111111' where id = '00000000-0000-0000-0000-000000000002';
update public.profiles set role_code = 'cashier', branch_id = '11111111-1111-1111-1111-111111111111' where id = '00000000-0000-0000-0000-000000000003';
update public.profiles set role_code = 'baker', branch_id = '11111111-1111-1111-1111-111111111111' where id = '00000000-0000-0000-0000-000000000004';
update public.profiles set role_code = 'store_keeper', branch_id = '11111111-1111-1111-1111-111111111111' where id = '00000000-0000-0000-0000-000000000005';
update public.profiles set role_code = 'hr_officer', branch_id = '11111111-1111-1111-1111-111111111111' where id = '00000000-0000-0000-0000-000000000006';
update public.profiles set role_code = 'accountant', branch_id = '11111111-1111-1111-1111-111111111111' where id = '00000000-0000-0000-0000-000000000007';
update public.profiles set role_code = 'staff', branch_id = '11111111-1111-1111-1111-111111111111' where id = '00000000-0000-0000-0000-000000000008';
update public.profiles set role_code = 'customer', branch_id = '11111111-1111-1111-1111-111111111111' where id = '00000000-0000-0000-0000-000000000009';

insert into public.employees (
  id, employee_no, profile_id, branch_id, full_name, hire_date,
  employment_type, status, base_salary, transport_allowance,
  housing_allowance, other_allowance, pension_rate
) values (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'TEST-EMP-1',
  '00000000-0000-0000-0000-000000000008',
  '11111111-1111-1111-1111-111111111111',
  'Test Employee',
  current_date,
  'full_time',
  'active',
  10000,
  1000,
  500,
  0,
  7
);

insert into public.payroll_runs (id, period_month, branch_id, cash_account_id, status, created_by)
values (
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
  date_trunc('month', current_date)::date,
  '11111111-1111-1111-1111-111111111111',
  '88888888-8888-8888-8888-888888888881',
  'draft',
  '00000000-0000-0000-0000-000000000001'
);

insert into public.purchase_orders (
  id, po_number, supplier_id, store_id, order_date, status, tax_amount, created_by
) values (
  'ffffffff-ffff-ffff-ffff-ffffffffffff',
  'TEST-PO-1',
  '99999999-9999-9999-9999-999999999999',
  '22222222-2222-2222-2222-222222222222',
  current_date,
  'ordered',
  0,
  '00000000-0000-0000-0000-000000000001'
);

insert into public.purchase_order_items (po_id, item_id, quantity_ordered, quantity_received, unit_cost)
values ('ffffffff-ffff-ffff-ffff-ffffffffffff', '55555555-5555-5555-5555-555555555501', 10, 0, 5);

select pg_temp.assert_true(
  (select subtotal = 50 and total_amount = 50 from public.purchase_orders where id = 'ffffffff-ffff-ffff-ffff-ffffffffffff'),
  'purchase order totals trigger'
);

insert into public.goods_receipts (id, receipt_no, po_id, store_id, received_date, received_by)
values ('17171717-1717-1717-1717-171717171717', 'TEST-GR-1', 'ffffffff-ffff-ffff-ffff-ffffffffffff', '22222222-2222-2222-2222-222222222222', current_date, '00000000-0000-0000-0000-000000000001');

insert into public.goods_receipt_items (receipt_id, item_id, quantity, unit_cost)
values ('17171717-1717-1717-1717-171717171717', '55555555-5555-5555-5555-555555555501', 10, 5);

select pg_temp.assert_true(
  (select quantity = 10 from public.stock_levels where store_id = '22222222-2222-2222-2222-222222222222' and item_id = '55555555-5555-5555-5555-555555555501'),
  'receipt creates stock movement'
);
select pg_temp.assert_true(
  (select quantity_received = 10 from public.purchase_order_items where po_id = 'ffffffff-ffff-ffff-ffff-ffffffffffff' and item_id = '55555555-5555-5555-5555-555555555501'),
  'receipt updates purchase order item'
);
select pg_temp.assert_true(
  (select status = 'received' from public.purchase_orders where id = 'ffffffff-ffff-ffff-ffff-ffffffffffff'),
  'receipt completes purchase order'
);

insert into public.stock_counts (id, store_id, count_date, status, created_by)
values ('18181818-1818-1818-1818-181818181818', '22222222-2222-2222-2222-222222222222', current_date, 'draft', '00000000-0000-0000-0000-000000000001');
insert into public.stock_count_items (count_id, item_id, system_qty, counted_qty)
values ('18181818-1818-1818-1818-181818181818', '55555555-5555-5555-5555-555555555501', 10, 7);
update public.stock_counts set status = 'completed' where id = '18181818-1818-1818-1818-181818181818';
select pg_temp.assert_true(
  (select quantity = 7 from public.stock_levels where store_id = '22222222-2222-2222-2222-222222222222' and item_id = '55555555-5555-5555-5555-555555555501'),
  'stock count completion adjusts stock'
);

insert into public.stock_movements (store_id, item_id, movement_type, quantity, unit_cost, created_by)
values ('22222222-2222-2222-2222-222222222222', '55555555-5555-5555-5555-555555555502', 'purchase', 10, 20, '00000000-0000-0000-0000-000000000001');
insert into public.stock_movements (store_id, item_id, movement_type, quantity, unit_cost, created_by)
values ('22222222-2222-2222-2222-222222222222', '55555555-5555-5555-5555-555555555502', 'sale', -2, 20, '00000000-0000-0000-0000-000000000001');
select pg_temp.assert_true(
  (select quantity = 8 from public.stock_levels where store_id = '22222222-2222-2222-2222-222222222222' and item_id = '55555555-5555-5555-5555-555555555502'),
  'stock movement ledger accumulates'
);

insert into public.stock_movements (store_id, item_id, movement_type, quantity, unit_cost, created_by)
values ('22222222-2222-2222-2222-222222222222', '55555555-5555-5555-5555-555555555504', 'purchase', 10, 20, '00000000-0000-0000-0000-000000000001');
select pg_temp.assert_true(
  (select quantity = 10 from public.stock_levels where store_id = '22222222-2222-2222-2222-222222222222' and item_id = '55555555-5555-5555-5555-555555555504'),
  'void fixture opening stock'
);

insert into public.recipes (id, product_id, name, yield_quantity, is_active)
values ('20202020-2020-2020-2020-202020202020', '66666666-6666-6666-6666-666666666666', 'Test recipe', 10, true);
insert into public.recipe_items (recipe_id, item_id, quantity)
values ('20202020-2020-2020-2020-202020202020', '55555555-5555-5555-5555-555555555503', 5);
insert into public.stock_movements (store_id, item_id, movement_type, quantity, unit_cost, created_by)
values ('22222222-2222-2222-2222-222222222222', '55555555-5555-5555-5555-555555555503', 'purchase', 100, 2, '00000000-0000-0000-0000-000000000001');
insert into public.production_batches (id, branch_id, store_id, product_id, recipe_id, planned_qty, produced_qty, status, baker_id, created_by)
values ('19191919-1919-1919-1919-191919191919', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', '66666666-6666-6666-6666-666666666666', '20202020-2020-2020-2020-202020202020', 10, 10, 'in_progress', '00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000001');
update public.production_batches set status = 'completed' where id = '19191919-1919-1919-1919-191919191919';
select pg_temp.assert_true(
  (select quantity = 95 from public.stock_levels where store_id = '22222222-2222-2222-2222-222222222222' and item_id = '55555555-5555-5555-5555-555555555503'),
  'production consumes ingredients'
);
select pg_temp.assert_true(
  (select quantity = 18 from public.stock_levels where store_id = '22222222-2222-2222-2222-222222222222' and item_id = '55555555-5555-5555-5555-555555555502'),
  'production adds finished goods to existing stock'
);

insert into public.sales (
  id, receipt_no, branch_id, store_id, customer_id, cashier_id, sale_date,
  subtotal, discount_amount, tax_amount, total_amount, paid_amount,
  payment_status, status
) values (
  '13131313-1313-1313-1313-131313131313', 'TEST-SALE-CASH',
  '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222',
  '77777777-7777-7777-7777-777777777777', '00000000-0000-0000-0000-000000000003',
  now(), 100, 0, 0, 100, 0, 'unpaid', 'completed'
);
insert into public.sale_items (sale_id, product_id, product_name, quantity, unit_price, discount_amount, tax_amount, line_total)
values ('13131313-1313-1313-1313-131313131313', '66666666-6666-6666-6666-666666666666', 'Test product', 2, 50, 0, 0, 100);
insert into public.sale_payments (sale_id, cash_account_id, method, amount, received_by)
values ('13131313-1313-1313-1313-131313131313', '88888888-8888-8888-8888-888888888881', 'cash', 100, '00000000-0000-0000-0000-000000000003');
select pg_temp.assert_true(
  (select paid_amount = 100 and payment_status = 'paid' from public.sales where id = '13131313-1313-1313-1313-131313131313'),
  'cash payment settles sale'
);
select pg_temp.assert_true(
  (select count(*) = 1 from public.cash_transactions where reference_type = 'sale_payment' and txn_type = 'in' and amount = 100),
  'cash payment posts cash transaction'
);
select pg_temp.assert_raises(
  $$insert into public.sale_payments (sale_id, cash_account_id, method, amount, received_by)
    values ('13131313-1313-1313-1313-131313131313', '88888888-8888-8888-8888-888888888881', 'cash', 1, '00000000-0000-0000-0000-000000000003')$$,
  'outstanding balance',
  'a sale payment cannot exceed the outstanding balance'
);
select pg_temp.assert_raises(
  $$insert into public.sale_payments (sale_id, method, amount, received_by)
    values ('13131313-1313-1313-1313-131313131313', 'cash', -1, '00000000-0000-0000-0000-000000000003')$$,
  null,
  'a negative sale payment is rejected'
);

insert into public.sales (
  id, receipt_no, branch_id, store_id, customer_id, cashier_id, sale_date,
  subtotal, discount_amount, tax_amount, total_amount, paid_amount,
  payment_status, status
) values (
  '14141414-1414-1414-1414-141414141414', 'TEST-SALE-CREDIT',
  '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222',
  '77777777-7777-7777-7777-777777777777', '00000000-0000-0000-0000-000000000003',
  now(), 50, 0, 0, 50, 0, 'unpaid', 'completed'
);
insert into public.sale_items (sale_id, product_id, product_name, quantity, unit_price, discount_amount, tax_amount, line_total)
values ('14141414-1414-1414-1414-141414141414', '66666666-6666-6666-6666-666666666666', 'Test product', 1, 50, 0, 0, 50);
insert into public.sale_payments (sale_id, method, amount, received_by)
values ('14141414-1414-1414-1414-141414141414', 'credit', 50, '00000000-0000-0000-0000-000000000003');
select pg_temp.assert_true(
  (select amount = 50 and balance = 50 and status = 'open' from public.receivables where sale_id = '14141414-1414-1414-1414-141414141414'),
  'credit sale creates receivable'
);
select pg_temp.assert_raises(
  $$insert into public.sale_payments (sale_id, method, amount, received_by)
    values ('14141414-1414-1414-1414-141414141414', 'credit', 10, '00000000-0000-0000-0000-000000000003')$$,
  'outstanding balance',
  'a credit payment cannot exceed the sale balance'
);
select pg_temp.assert_true(
  (select amount = 50 and balance = 50 from public.receivables where sale_id = '14141414-1414-1414-1414-141414141414'),
  'rejected credit payment leaves the receivable unchanged'
);

-- A credit sale must name an active customer.
insert into public.sales (
  id, receipt_no, branch_id, store_id, customer_id, cashier_id, sale_date,
  subtotal, discount_amount, tax_amount, total_amount, paid_amount,
  payment_status, status
) values (
  '32323232-3232-3232-3232-323232323232', 'TEST-SALE-NO-CUSTOMER',
  '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222',
  null, '00000000-0000-0000-0000-000000000003',
  now(), 10, 0, 0, 10, 0, 'unpaid', 'completed'
);
select pg_temp.assert_raises(
  $$insert into public.sale_payments (sale_id, method, amount, received_by)
    values ('32323232-3232-3232-3232-323232323232', 'credit', 10, '00000000-0000-0000-0000-000000000003')$$,
  'requires a customer',
  'a credit sale without a customer is rejected'
);

select public.fn_close_day('11111111-1111-1111-1111-111111111111', current_date, 150);
select pg_temp.assert_true(
  (select total_sales = 160 and cash_sales = 100 and expected_cash = 100 and counted_cash = 150 and difference = 50 from public.daily_closings where branch_id = '11111111-1111-1111-1111-111111111111' and closing_date = current_date),
  'daily closing totals'
);
select pg_temp.assert_raises(
  $$select public.fn_close_day('11111111-1111-1111-1111-111111111111', current_date, 999)$$,
  'already closed',
  'a closed day cannot be closed again'
);
select pg_temp.assert_raises(
  $$update public.daily_closings set counted_cash = 999
    where branch_id = '11111111-1111-1111-1111-111111111111' and closing_date = current_date$$,
  'cannot be changed',
  'closed day totals cannot be edited directly'
);
select pg_temp.assert_true(
  (select counted_cash = 150 from public.daily_closings
   where branch_id = '11111111-1111-1111-1111-111111111111' and closing_date = current_date),
  'rejected edits leave the closed day untouched'
);

insert into public.payables (id, supplier_id, description, amount, due_date, status, created_by)
values ('15151515-1515-1515-1515-151515151515', '99999999-9999-9999-9999-999999999999', 'Test payable', 200, current_date + 30, 'open', '00000000-0000-0000-0000-000000000001');
select pg_temp.assert_true(
  (select count(*) = 1 from public.ledger_entries where reference_type = 'payable' and reference_id = '15151515-1515-1515-1515-151515151515' and credit = 200),
  'payable creates supplier ledger entry'
);
insert into public.payable_payments (id, payable_id, cash_account_id, amount, payment_date, method, paid_by)
values ('16161616-1616-1616-1616-161616161616', '15151515-1515-1515-1515-151515151515', '88888888-8888-8888-8888-888888888881', 200, current_date, 'cash', '00000000-0000-0000-0000-000000000001');
select pg_temp.assert_true(
  (select paid_amount = 200 and status = 'paid' from public.payables where id = '15151515-1515-1515-1515-151515151515'),
  'payable payment settles payable'
);
select pg_temp.assert_true(
  (select count(*) = 1 from public.ledger_entries where reference_type = 'payable_payment' and reference_id = '16161616-1616-1616-1616-161616161616' and debit = 200),
  'payable payment creates ledger entry'
);
select pg_temp.assert_true(
  (select count(*) = 1 from public.cash_transactions where reference_type = 'payable_payment' and reference_id = '16161616-1616-1616-1616-161616161616' and txn_type = 'out'),
  'payable payment posts cash transaction'
);
select pg_temp.assert_raises(
  $$insert into public.payable_payments (payable_id, amount, paid_by)
    values ('15151515-1515-1515-1515-151515151515', 1, '00000000-0000-0000-0000-000000000001')$$,
  'outstanding balance',
  'a supplier payment cannot exceed the payable balance'
);
select pg_temp.assert_raises(
  $$insert into public.payable_payments (payable_id, amount, paid_by)
    values ('15151515-1515-1515-1515-151515151515', -1, '00000000-0000-0000-0000-000000000001')$$,
  null,
  'a negative supplier payment is rejected'
);

insert into public.cash_transfers (id, from_account_id, to_account_id, amount, transfer_date, created_by)
values ('21212121-2121-2121-2121-212121212121', '88888888-8888-8888-8888-888888888881', '88888888-8888-8888-8888-888888888882', 50, current_date, '00000000-0000-0000-0000-000000000001');
select pg_temp.assert_true(
  (select count(*) = 2 from public.cash_transactions where reference_type = 'cash_transfer' and reference_id = '21212121-2121-2121-2121-212121212121'),
  'cash transfer posts both sides'
);

select public.fn_generate_payroll('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee');
select pg_temp.assert_true(
  (select gross_pay = 11500 and total_deductions = 700 and net_pay = 10800 from public.payslips where payroll_run_id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee' and employee_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'payroll payslip totals'
);
select pg_temp.assert_true(
  (select total_gross = 11500 and total_net = 10800 from public.payroll_runs where id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'),
  'payroll run totals'
);

select public.fn_generate_rent_invoices(current_date);
select pg_temp.assert_true(
  (select count(*) = 1 from public.rent_invoices where lease_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd' and period_start = date_trunc('month', current_date)::date),
  'rent invoice generation'
);
select public.fn_generate_rent_invoices(current_date);
select pg_temp.assert_true(
  (select count(*) = 1 from public.rent_invoices where lease_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd' and period_start = date_trunc('month', current_date)::date),
  'rent invoice generation is idempotent'
);

update public.items set min_stock = 20 where id = '55555555-5555-5555-5555-555555555502';
update public.rent_invoices set due_date = current_date + 2 where lease_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
select public.fn_generate_alerts();
select public.fn_generate_alerts();
select pg_temp.assert_true(
  (select count(*) = 1 from public.notifications where type = 'low_stock' and data->>'key' like 'low_stock:%'),
  'low stock alert is generated once'
);
select pg_temp.assert_true(
  (
    select count(*) = 1
    from public.notifications
    where type = 'rent_due'
      and data->>'invoice_id' = (
        select id::text
        from public.rent_invoices
        where lease_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd'
          and period_start = date_trunc('month', current_date)::date
      )
  ),
  'rent due alert is generated once for the generated invoice'
);

select pg_temp.assert_true(
  (select public.next_number('TEST') = 'TEST-000001'),
  'next_number first value'
);
select pg_temp.assert_true(
  (select public.next_number('TEST') = 'TEST-000002'),
  'next_number increments'
);

update public.app_settings set value = jsonb_set(value, '{name}', '"Brade and Cake House QA"') where key = 'business_name';
select pg_temp.assert_true(
  (select count(*) >= 1 from public.audit_logs where table_name = 'app_settings' and action = 'UPDATE'),
  'app settings update is audited'
);

-- Customer credit payment.
insert into public.receivable_payments (
  id, receivable_id, cash_account_id, amount, payment_date, method, received_by
)
select
  '17171717-1717-1717-1717-171717171717', id,
  '88888888-8888-8888-8888-888888888881', 20, current_date, 'cash',
  '00000000-0000-0000-0000-000000000001'
from public.receivables
where sale_id = '14141414-1414-1414-1414-141414141414';
select pg_temp.assert_true(
  (select paid_amount = 20 and balance = 30 and status = 'partial'
   from public.receivables
   where sale_id = '14141414-1414-1414-1414-141414141414'),
  'customer payment reduces receivable'
);
select pg_temp.assert_true(
  (select count(*) = 1 from public.ledger_entries
   where reference_type = 'receivable_payment'
     and reference_id = '17171717-1717-1717-1717-171717171717'
     and credit = 20),
  'customer payment posts ledger credit'
);
select pg_temp.assert_true(
  (select count(*) = 1 from public.cash_transactions
   where reference_type = 'receivable_payment'
     and reference_id = '17171717-1717-1717-1717-171717171717'
     and txn_type = 'in' and amount = 20),
  'customer payment posts cash transaction'
);
select pg_temp.assert_raises(
  $$insert into public.receivable_payments (receivable_id, amount, received_by)
    select id, 31, '00000000-0000-0000-0000-000000000003'
    from public.receivables where sale_id = '14141414-1414-1414-1414-141414141414'$$,
  'outstanding balance',
  'a customer payment cannot exceed the receivable balance'
);
select pg_temp.assert_raises(
  $$insert into public.receivable_payments (receivable_id, amount, received_by)
    select id, -1, '00000000-0000-0000-0000-000000000003'
    from public.receivables where sale_id = '14141414-1414-1414-1414-141414141414'$$,
  null,
  'a negative customer payment is rejected'
);

-- Sale return restores stock and refunds cash.
insert into public.sale_returns (
  id, return_no, sale_id, return_date, reason, refund_amount,
  cash_account_id, created_by
) values (
  '18181818-1818-1818-1818-181818181818', 'TEST-RETURN-1',
  '14141414-1414-1414-1414-141414141414', now(), 'QA return', 10,
  '88888888-8888-8888-8888-888888888881',
  '00000000-0000-0000-0000-000000000001'
);
insert into public.sale_return_items (
  return_id, sale_item_id, product_id, quantity, amount
)
select
  '18181818-1818-1818-1818-181818181818', id, product_id, 1, 10
from public.sale_items
where sale_id = '14141414-1414-1414-1414-141414141414';
update public.sales
set status = 'returned'
where id = '14141414-1414-1414-1414-141414141414';
select pg_temp.assert_true(
  (select count(*) = 1 from public.stock_movements
   where reference_type = 'sale_return'
     and reference_id = '18181818-1818-1818-1818-181818181818'
     and movement_type = 'return_in' and quantity = 1),
  'sale return restores stock'
);
select pg_temp.assert_true(
  (select count(*) = 1 from public.cash_transactions
   where reference_type = 'sale_return'
     and reference_id = '18181818-1818-1818-1818-181818181818'
     and txn_type = 'out' and amount = 10),
  'sale return refunds cash'
);
select pg_temp.assert_true(
  (select status = 'returned' from public.sales
   where id = '14141414-1414-1414-1414-141414141414'),
  'sale return updates sale status'
);

-- Staff cannot void sales; the RPC is limited to cashier, manager,
-- accountant and admin roles.
do $$
declare
  v_denied boolean := false;
begin
  perform set_config(
    'request.jwt.claim.sub',
    '00000000-0000-0000-0000-000000000008',
    true
  );
  execute 'set local role authenticated';
  begin
    perform public.void_sale(
      '13131313-1313-1313-1313-131313131313', 'staff attempt'
    );
  exception when others then
    if position('permission' in lower(sqlerrm)) > 0 then
      v_denied := true;
    else
      raise;
    end if;
  end;
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', '', true);
  if not v_denied then
    raise exception 'ASSERTION FAILED: staff could void a sale';
  end if;
end $$;

-- Voiding a completed cash sale reverses stock and cash exactly once.
select public.void_sale(
  '13131313-1313-1313-1313-131313131313', 'QA void'
);
select pg_temp.assert_true(
  (select status = 'void' and payment_status = 'refunded'
   from public.sales
   where id = '13131313-1313-1313-1313-131313131313'),
  'void sale updates sale status'
);
select pg_temp.assert_true(
  (select count(*) = 1 from public.stock_movements
   where reference_type = 'sale_void'
     and reference_id = '13131313-1313-1313-1313-131313131313'
     and movement_type = 'return_in' and quantity = 2),
  'void sale restores stock'
);
select pg_temp.assert_true(
  (select count(*) = 1 from public.cash_transactions
   where reference_type = 'sale_void'
     and reference_id = '13131313-1313-1313-1313-131313131313'
     and txn_type = 'out' and amount = 100),
  'void sale reverses cash'
);
select pg_temp.assert_true(
  (select count(*) >= 1 from public.audit_logs
   where table_name = 'sales'
     and record_id = '13131313-1313-1313-1313-131313131313'
     and action = 'UPDATE'
     and new_data->>'status' = 'void'),
  'void sale is audited'
);

-- A second void is rejected and must not add another stock or cash reversal.
do $$
declare
  v_rejected boolean := false;
begin
  begin
    perform public.void_sale(
      '13131313-1313-1313-1313-131313131313', 'QA void again'
    );
  exception when others then
    if position('already been voided' in lower(sqlerrm)) > 0 then
      v_rejected := true;
    else
      raise;
    end if;
  end;
  if not v_rejected then
    raise exception 'ASSERTION FAILED: second void was not rejected';
  end if;
end $$;
select pg_temp.assert_true(
  (select count(*) = 1 from public.cash_transactions
   where reference_type = 'sale_void'
     and reference_id = '13131313-1313-1313-1313-131313131313'),
  'second void adds no cash reversal'
);
select pg_temp.assert_true(
  (select count(*) = 1 from public.stock_movements
   where reference_type = 'sale_void'
     and reference_id = '13131313-1313-1313-1313-131313131313'),
  'second void adds no stock movement'
);

-- Isolated cash sale: stock and cash must return to their exact pre-sale
-- values, proving the trigger restores stock once and the RPC never inserts a
-- stock movement itself.
insert into public.sales (
  id, receipt_no, branch_id, store_id, customer_id, cashier_id, sale_date,
  subtotal, discount_amount, tax_amount, total_amount, paid_amount,
  payment_status, status
) values (
  '29292929-2929-2929-2929-292929292929', 'TEST-SALE-VOID',
  '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222',
  '77777777-7777-7777-7777-777777777777', '00000000-0000-0000-0000-000000000003',
  now(), 100, 0, 0, 100, 0, 'unpaid', 'completed'
);
insert into public.sale_items (sale_id, product_id, product_name, quantity, unit_price, discount_amount, tax_amount, line_total)
values ('29292929-2929-2929-2929-292929292929', '68686868-6868-6868-6868-686868686868', 'Void test product', 2, 50, 0, 0, 100);
insert into public.sale_payments (sale_id, cash_account_id, method, amount, received_by)
values ('29292929-2929-2929-2929-292929292929', '88888888-8888-8888-8888-888888888883', 'cash', 100, '00000000-0000-0000-0000-000000000003');
select pg_temp.assert_true(
  (select quantity = 8 from public.stock_levels
   where store_id = '22222222-2222-2222-2222-222222222222'
     and item_id = '55555555-5555-5555-5555-555555555504'),
  'void test sale reduces stock'
);
select pg_temp.assert_true(
  (select balance = 100 from public.v_cash_account_balances
   where id = '88888888-8888-8888-8888-888888888883'),
  'void test sale increases cash'
);
select public.void_sale(
  '29292929-2929-2929-2929-292929292929', 'QA isolated void'
);
select pg_temp.assert_true(
  (select quantity = 10 from public.stock_levels
   where store_id = '22222222-2222-2222-2222-222222222222'
     and item_id = '55555555-5555-5555-5555-555555555504'),
  'void restores stock to exact pre-sale quantity'
);
select pg_temp.assert_true(
  (select balance = 0 from public.v_cash_account_balances
   where id = '88888888-8888-8888-8888-888888888883'),
  'void restores cash to exact pre-sale balance'
);
select pg_temp.assert_true(
  (select count(*) = 1 from public.stock_movements
   where reference_type = 'sale_void'
     and reference_id = '29292929-2929-2929-2929-292929292929'
     and movement_type = 'return_in' and quantity = 2),
  'void inserts exactly one stock restoration through the trigger'
);
select pg_temp.assert_true(
  (select count(*) = 1 from public.cash_transactions
   where reference_type = 'sale_void'
     and reference_id = '29292929-2929-2929-2929-292929292929'
     and txn_type = 'out' and amount = 100),
  'void inserts exactly one cash reversal'
);
do $$
declare
  v_rejected boolean := false;
begin
  begin
    perform public.void_sale(
      '29292929-2929-2929-2929-292929292929', 'QA isolated void again'
    );
  exception when others then
    if position('already been voided' in lower(sqlerrm)) > 0 then
      v_rejected := true;
    else
      raise;
    end if;
  end;
  if not v_rejected then
    raise exception 'ASSERTION FAILED: repeat void was not rejected';
  end if;
end $$;

-- A completed sale with a partial return cannot be voided. The failed void
-- must leave the already-returned stock and refunded cash unchanged.
insert into public.sales (
  id, receipt_no, branch_id, store_id, customer_id, cashier_id, sale_date,
  subtotal, discount_amount, tax_amount, total_amount, paid_amount,
  payment_status, status
) values (
  '31313131-3131-3131-3131-313131313131', 'TEST-SALE-PARTIAL-RETURN',
  '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222',
  '77777777-7777-7777-7777-777777777777', '00000000-0000-0000-0000-000000000003',
  now(), 100, 0, 0, 100, 0, 'unpaid', 'completed'
);
insert into public.sale_items (
  sale_id, product_id, product_name, quantity, unit_price,
  discount_amount, tax_amount, line_total
) values (
  '31313131-3131-3131-3131-313131313131',
  '68686868-6868-6868-6868-686868686868', 'Void test product',
  2, 50, 0, 0, 100
);
insert into public.sale_payments (
  sale_id, cash_account_id, method, amount, received_by
) values (
  '31313131-3131-3131-3131-313131313131',
  '88888888-8888-8888-8888-888888888883', 'cash', 100,
  '00000000-0000-0000-0000-000000000003'
);
select pg_temp.assert_true(
  (select quantity = 8 from public.stock_levels
   where store_id = '22222222-2222-2222-2222-222222222222'
     and item_id = '55555555-5555-5555-5555-555555555504'),
  'partial-return void fixture reduces stock'
);
select pg_temp.assert_true(
  (select balance = 100 from public.v_cash_account_balances
   where id = '88888888-8888-8888-8888-888888888883'),
  'partial-return void fixture increases cash'
);

insert into public.sale_returns (
  id, return_no, sale_id, return_date, reason, refund_amount,
  cash_account_id, created_by
) values (
  '32323232-3232-3232-3232-323232323232', 'TEST-RETURN-VOID',
  '31313131-3131-3131-3131-313131313131', now(), 'QA partial return', 50,
  '88888888-8888-8888-8888-888888888883',
  '00000000-0000-0000-0000-000000000001'
);
insert into public.sale_return_items (
  return_id, sale_item_id, product_id, quantity, amount
)
select
  '32323232-3232-3232-3232-323232323232', id, product_id, 1, 50
from public.sale_items
where sale_id = '31313131-3131-3131-3131-313131313131';

select pg_temp.assert_true(
  (select quantity = 9 from public.stock_levels
   where store_id = '22222222-2222-2222-2222-222222222222'
     and item_id = '55555555-5555-5555-5555-555555555504'),
  'partial return restores one unit'
);
select pg_temp.assert_true(
  (select balance = 50 from public.v_cash_account_balances
   where id = '88888888-8888-8888-8888-888888888883'),
  'partial return refunds half the cash'
);
select pg_temp.assert_true(
  (select count(*) = 1 from public.stock_movements
   where reference_type = 'sale_return'
     and reference_id = '32323232-3232-3232-3232-323232323232'
     and movement_type = 'return_in' and quantity = 1),
  'partial return posts one stock movement'
);
select pg_temp.assert_true(
  (select count(*) = 1 from public.cash_transactions
   where reference_type = 'sale_return'
     and reference_id = '32323232-3232-3232-3232-323232323232'
     and txn_type = 'out' and amount = 50),
  'partial return posts one cash refund'
);

do $$
declare
  v_rejected boolean := false;
begin
  begin
    perform public.void_sale(
      '31313131-3131-3131-3131-313131313131', 'QA partial return void'
    );
  exception when others then
    if position('already has returns' in lower(sqlerrm)) > 0 then
      v_rejected := true;
    else
      raise;
    end if;
  end;
  if not v_rejected then
    raise exception 'ASSERTION FAILED: sale with a return was voided';
  end if;
end $$;

select pg_temp.assert_true(
  (select status = 'completed' and payment_status = 'paid'
   from public.sales
   where id = '31313131-3131-3131-3131-313131313131'),
  'failed void leaves the sale completed'
);
select pg_temp.assert_true(
  (select quantity = 9 from public.stock_levels
   where store_id = '22222222-2222-2222-2222-222222222222'
     and item_id = '55555555-5555-5555-5555-555555555504'),
  'failed void leaves returned stock unchanged'
);
select pg_temp.assert_true(
  (select balance = 50 from public.v_cash_account_balances
   where id = '88888888-8888-8888-8888-888888888883'),
  'failed void leaves refunded cash unchanged'
);
select pg_temp.assert_true(
  (select count(*) = 0 from public.stock_movements
   where reference_type = 'sale_void'
     and reference_id = '31313131-3131-3131-3131-313131313131'),
  'failed void adds no stock movement'
);
select pg_temp.assert_true(
  (select count(*) = 0 from public.cash_transactions
   where reference_type = 'sale_void'
     and reference_id = '31313131-3131-3131-3131-313131313131'),
  'failed void adds no cash reversal'
);

-- Credit sale: void writes off the receivable, refunds any credit payments,
-- and posts the matching customer ledger credit.
insert into public.sales (
  id, receipt_no, branch_id, store_id, customer_id, cashier_id, sale_date,
  subtotal, discount_amount, tax_amount, total_amount, paid_amount,
  payment_status, status
) values (
  '30303030-3030-3030-3030-303030303030', 'TEST-SALE-CREDIT-VOID',
  '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222',
  '77777777-7777-7777-7777-777777777777', '00000000-0000-0000-0000-000000000003',
  now(), 60, 0, 0, 60, 0, 'unpaid', 'completed'
);
insert into public.sale_items (sale_id, product_id, product_name, quantity, unit_price, discount_amount, tax_amount, line_total)
values ('30303030-3030-3030-3030-303030303030', '67676767-6767-6767-6767-676767676767', 'Test service', 1, 60, 0, 0, 60);
update public.customers set credit_limit = 40
where id = '77777777-7777-7777-7777-777777777777';
select pg_temp.assert_raises(
  $$insert into public.sale_payments (sale_id, method, amount, received_by)
    values ('30303030-3030-3030-3030-303030303030', 'credit', 60, '00000000-0000-0000-0000-000000000003')$$,
  'Credit limit exceeded',
  'a credit sale above the customer credit limit is rejected'
);
select pg_temp.assert_true(
  (select count(*) = 0 from public.receivables
   where sale_id = '30303030-3030-3030-3030-303030303030'),
  'rejected credit sale creates no receivable'
);
update public.customers set credit_limit = 1000
where id = '77777777-7777-7777-7777-777777777777';
insert into public.sale_payments (sale_id, method, amount, received_by)
values ('30303030-3030-3030-3030-303030303030', 'credit', 60, '00000000-0000-0000-0000-000000000003');
select pg_temp.assert_true(
  (select amount = 60 and balance = 60 and status = 'open'
   from public.receivables
   where sale_id = '30303030-3030-3030-3030-303030303030'),
  'void credit fixture creates receivable'
);
select public.void_sale(
  '30303030-3030-3030-3030-303030303030', 'QA credit void'
);
select pg_temp.assert_true(
  (select status = 'void' and payment_status = 'refunded'
   from public.sales
   where id = '30303030-3030-3030-3030-303030303030'),
  'void credit sale updates sale status'
);
select pg_temp.assert_true(
  (select status = 'written_off' and balance = 0 and paid_amount = 60
   from public.receivables
   where sale_id = '30303030-3030-3030-3030-303030303030'),
  'void credit sale writes off receivable'
);
select pg_temp.assert_true(
  (select coalesce(sum(debit), 0) = 60 and coalesce(sum(credit), 0) = 60
   from public.ledger_entries
   where customer_id = '77777777-7777-7777-7777-777777777777'
     and (
       (reference_type = 'receivable' and reference_id = (
         select id from public.receivables
         where sale_id = '30303030-3030-3030-3030-303030303030'
       ))
       or (reference_type = 'sale_void'
         and reference_id = '30303030-3030-3030-3030-303030303030')
     )),
  'void credit sale balances customer ledger'
);
select pg_temp.assert_true(
  (select count(*) = 0 from public.cash_transactions
   where reference_type = 'sale_void'
     and reference_id = '30303030-3030-3030-3030-303030303030'),
  'void credit sale creates no cash reversal without cash payment'
);

-- Payroll approval and payment.
update public.payroll_runs
set cash_account_id = '88888888-8888-8888-8888-888888888881',
    status = 'approved'
where id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
select pg_temp.assert_true(
  (select status = 'approved' and approved_at is not null
   from public.payroll_runs
   where id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'),
  'payroll approval'
);
select pg_temp.assert_raises(
  $$select public.fn_generate_payroll('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee')$$,
  'Only a draft payroll',
  'payroll cannot be regenerated after approval'
);
select pg_temp.assert_raises(
  $$update public.payslips set net_pay = net_pay + 1
    where payroll_run_id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'$$,
  'after payroll approval',
  'payslip amounts cannot be edited after approval'
);
select pg_temp.assert_raises(
  $$insert into public.payslips (
      payroll_run_id, employee_id, base_salary, allowances, gross_pay,
      income_tax, pension_employee, advance_deduction, total_deductions, net_pay
    )
    select payroll_run_id, employee_id, base_salary, allowances, gross_pay,
           income_tax, pension_employee, advance_deduction, total_deductions, net_pay
    from public.payslips
    where payroll_run_id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
    limit 1$$,
  'after payroll approval',
  'a payslip cannot be added after approval'
);
update public.payroll_runs
set status = 'paid'
where id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
select pg_temp.assert_true(
  (select status = 'paid' and paid_at is not null
   from public.payroll_runs
   where id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'),
  'payroll payment'
);
select pg_temp.assert_true(
  (select bool_and(is_paid) from public.payslips
   where payroll_run_id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'),
  'payroll payslips are paid'
);
select pg_temp.assert_true(
  (select count(*) = 1 from public.cash_transactions
   where reference_type = 'payroll_run'
     and reference_id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
     and txn_type = 'out' and amount = 10800),
  'payroll payment posts cash transaction'
);

-- Operating expense.
insert into public.expense_categories (id, name, kind, is_active)
values (
  '19191919-1919-1919-1919-191919191919', 'QA Expense', 'expense', true
);
insert into public.cash_transactions (
  id, branch_id, cash_account_id, txn_type, category_id, amount, txn_date,
  description, reference_type, reference_id, created_by
) values (
  '20202020-2020-2020-2020-202020202020',
  '11111111-1111-1111-1111-111111111111',
  '88888888-8888-8888-8888-888888888881', 'out',
  '19191919-1919-1919-1919-191919191919', 25, current_date,
  'QA expense', 'expense', '20202020-2020-2020-2020-202020202020',
  '00000000-0000-0000-0000-000000000001'
);
select pg_temp.assert_true(
  (select count(*) = 1 from public.cash_transactions
   where reference_type = 'expense'
     and reference_id = '20202020-2020-2020-2020-202020202020'
     and txn_type = 'out' and amount = 25),
  'expense posts cash transaction'
);
select pg_temp.assert_true(
  (select total = 25 from public.v_expense_summary
   where category = 'QA Expense' and txn_type = 'out'),
  'expense appears in expense summary'
);

-- Supplier bill and its payment.
insert into public.expense_categories (id, name, kind, is_active)
values (
  '29292929-2929-2929-2929-292929292929', 'QA Bill Expense', 'expense', true
);
insert into public.bills (
  id, bill_no, supplier_id, branch_id, category_id, description, amount,
  paid_amount, bill_date, due_date, status, created_by
) values (
  '22222222-2222-2222-2222-222222222221', 'TEST-BILL-1',
  '99999999-9999-9999-9999-999999999999',
  '11111111-1111-1111-1111-111111111111',
  '29292929-2929-2929-2929-292929292929', 'QA bill', 40, 40,
  current_date, current_date + 30, 'paid',
  '00000000-0000-0000-0000-000000000001'
);
insert into public.cash_transactions (
  id, branch_id, cash_account_id, txn_type, category_id, amount, txn_date,
  description, reference_type, reference_id, created_by
) values (
  '23232323-2323-2323-2323-232323232320',
  '11111111-1111-1111-1111-111111111111',
  '88888888-8888-8888-8888-888888888881', 'out',
  '29292929-2929-2929-2929-292929292929', 40, current_date,
  'QA bill payment', 'bill_payment',
  '22222222-2222-2222-2222-222222222221',
  '00000000-0000-0000-0000-000000000001'
);
select pg_temp.assert_true(
  (select paid_amount = 40 and status = 'paid' from public.bills
   where id = '22222222-2222-2222-2222-222222222221'),
  'bill payment settles bill'
);
select pg_temp.assert_true(
  (select count(*) >= 1 from public.audit_logs
   where table_name = 'bills'
     and record_id = '22222222-2222-2222-2222-222222222221'
     and action = 'INSERT'),
  'bill creation is audited'
);
select pg_temp.assert_true(
  (select count(*) = 1 from public.cash_transactions
   where reference_type = 'bill_payment'
     and reference_id = '22222222-2222-2222-2222-222222222221'
     and txn_type = 'out' and amount = 40),
  'bill payment posts cash transaction'
);

-- Approval decision.
insert into public.approvals (
  id, entity_type, entity_id, requested_by, status, amount, reason
) values (
  '24242424-2424-2424-2424-242424242424', 'write_off',
  '27272727-2727-2727-2727-272727272727',
  '00000000-0000-0000-0000-000000000001', 'pending', 30,
  'QA approval'
);
update public.approvals
set status = 'approved',
    approver_id = '00000000-0000-0000-0000-000000000001',
    decided_at = now(),
    decision_note = 'Approved'
where id = '24242424-2424-2424-2424-242424242424';
select pg_temp.assert_true(
  (select status = 'approved' and decided_at is not null
   from public.approvals
   where id = '24242424-2424-2424-2424-242424242424'),
  'approval decision is recorded'
);

-- Stock transfer between stores.
insert into public.stock_transfers (
  id, transfer_no, from_store_id, to_store_id, item_id, quantity,
  notes, created_by
) values (
  '25252525-2525-2525-2525-252525252525', 'TEST-TRANSFER-1',
  '22222222-2222-2222-2222-222222222222',
  '23232323-2323-2323-2323-232323232323',
  '55555555-5555-5555-5555-555555555501', 5, 'QA transfer',
  '00000000-0000-0000-0000-000000000001'
);
select pg_temp.assert_true(
  (select count(*) = 2 from public.stock_movements
   where reference_type = 'stock_transfer'
     and reference_id = '25252525-2525-2525-2525-252525252525'),
  'stock transfer posts both sides'
);
select pg_temp.assert_true(
  (select quantity = 5 from public.stock_levels
   where store_id = '23232323-2323-2323-2323-232323232323'
     and item_id = '55555555-5555-5555-5555-555555555501'),
  'stock transfer updates destination level'
);

-- Rent payment.
insert into public.rent_payments (
  id, invoice_id, cash_account_id, amount, payment_date, method, received_by
)
select
  '26262626-2626-2626-2626-262626262626', id,
  '88888888-8888-8888-8888-888888888881', 5000, current_date, 'cash',
  '00000000-0000-0000-0000-000000000001'
from public.rent_invoices
where lease_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
select pg_temp.assert_true(
  (select paid_amount = 5000 and status = 'paid'
   from public.rent_invoices
   where lease_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd'),
  'rent payment settles invoice'
);
select pg_temp.assert_true(
  (select count(*) = 1 from public.cash_transactions
   where reference_type = 'rent_payment'
     and reference_id = '26262626-2626-2626-2626-262626262626'
     and txn_type = 'in' and amount = 5000),
  'rent payment posts cash transaction'
);
select pg_temp.assert_raises(
  $$insert into public.rent_payments (invoice_id, amount, received_by)
    select id, 1, '00000000-0000-0000-0000-000000000001'
    from public.rent_invoices where lease_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd'$$,
  'outstanding balance',
  'a rent payment cannot exceed the invoice balance'
);
select pg_temp.assert_raises(
  $$insert into public.rent_payments (invoice_id, amount, received_by)
    select id, -1, '00000000-0000-0000-0000-000000000001'
    from public.rent_invoices where lease_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd'$$,
  null,
  'a negative rent payment is rejected'
);

-- Receivable write-off.
insert into public.write_offs (
  id, receivable_id, amount, reason, status, requested_by
)
select
  '27272727-2727-2727-2727-272727272727', id, 30, 'QA write-off',
  'pending', '00000000-0000-0000-0000-000000000001'
from public.receivables
where sale_id = '14141414-1414-1414-1414-141414141414';
update public.write_offs
set status = 'approved',
    approved_by = '00000000-0000-0000-0000-000000000001',
    decided_at = now()
where id = '27272727-2727-2727-2727-272727272727';
select pg_temp.assert_true(
  (select status = 'written_off' from public.receivables
   where sale_id = '14141414-1414-1414-1414-141414141414'),
  'write-off closes receivable'
);
select pg_temp.assert_true(
  (select count(*) = 1 from public.ledger_entries
   where reference_type = 'write_off'
     and reference_id = '27272727-2727-2727-2727-272727272727'
     and credit = 30),
  'write-off posts ledger credit'
);

-- Role permission change.
delete from public.role_permissions
where role_code = 'customer' and permission_code = 'products.view';
select pg_temp.assert_true(
  (select count(*) = 0 from public.role_permissions
   where role_code = 'customer' and permission_code = 'products.view'),
  'role permission removal'
);
insert into public.role_permissions (role_code, permission_code)
values ('customer', 'products.view');
select pg_temp.assert_true(
  (select count(*) = 1 from public.role_permissions
   where role_code = 'customer' and permission_code = 'products.view'),
  'role permission restoration'
);

-- Finished-goods stock is back to 18 after one return and one void.
select pg_temp.assert_true(
  (select quantity = 18 from public.stock_levels
   where store_id = '22222222-2222-2222-2222-222222222222'
     and item_id = '55555555-5555-5555-5555-555555555502'),
  'finished-goods stock after return and void'
);

-- Split tender: one sale paid with cash and bank.
insert into public.sales (
  id, receipt_no, branch_id, store_id, customer_id, cashier_id, sale_date,
  subtotal, discount_amount, tax_amount, total_amount, paid_amount,
  payment_status, status
) values (
  '28282828-2828-2828-2828-282828282828', 'TEST-SALE-SPLIT',
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '77777777-7777-7777-7777-777777777777',
  '00000000-0000-0000-0000-000000000003',
  now(), 60, 0, 0, 60, 0, 'unpaid', 'completed'
);
insert into public.sale_items (
  sale_id, product_id, product_name, quantity, unit_price,
  discount_amount, tax_amount, line_total
) values (
  '28282828-2828-2828-2828-282828282828',
  '67676767-6767-6767-6767-676767676767', 'Test service', 1, 60, 0, 0, 60
);
insert into public.sale_payments (
  sale_id, cash_account_id, method, amount, received_by
) values
  (
    '28282828-2828-2828-2828-282828282828',
    '88888888-8888-8888-8888-888888888881', 'cash', 30,
    '00000000-0000-0000-0000-000000000003'
  ),
  (
    '28282828-2828-2828-2828-282828282828',
    '88888888-8888-8888-8888-888888888882', 'bank', 30,
    '00000000-0000-0000-0000-000000000003'
  );
select pg_temp.assert_true(
  (select paid_amount = 60 and payment_status = 'paid'
   from public.sales
   where id = '28282828-2828-2828-2828-282828282828'),
  'split tender settles sale'
);
select pg_temp.assert_true(
  (select count(*) = 2 from public.cash_transactions
   where reference_type = 'sale_payment'
     and reference_id in (
       select id from public.sale_payments
       where sale_id = '28282828-2828-2828-2828-282828282828'
     )
     and txn_type = 'in'),
  'split tender posts two cash transactions'
);

-- Translation columns on every catalog table named by the product contract.
do $$
declare
  missing text;
begin
  select string_agg(format('%s.%s', t.table_name, c.column_name), ', ')
  into missing
  from (values ('units'), ('categories'), ('expense_categories'), ('departments'), ('leave_types'), ('shifts')) t(table_name)
  cross join (values ('name_am'), ('name_om')) c(column_name)
  where not exists (
    select 1
    from information_schema.columns ic
    where ic.table_schema = 'public'
      and ic.table_name = t.table_name
      and ic.column_name = c.column_name
  );
  if missing is not null then
    raise exception 'ASSERTION FAILED: missing translation columns: %', missing;
  end if;
end $$;

-- Every public table must have row level security enabled.
do $$
declare
  missing text;
begin
  select string_agg(c.relname, ', ')
  into missing
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind = 'r'
    and not c.relrowsecurity;
  if missing is not null then
    raise exception 'ASSERTION FAILED: RLS disabled on: %', missing;
  end if;
end $$;

-- Anonymous access: the two login RPCs work, and no table or view is readable.
set local role anon;
do $$
declare
  readable text;
begin
  if not public.has_admin() then
    raise exception 'ASSERTION FAILED: has_admin() is false for anon';
  end if;
  if not public.customer_signup_allowed() then
    raise exception 'ASSERTION FAILED: customer_signup_allowed() is false for anon';
  end if;

  select string_agg(c.relname, ', ')
  into readable
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind in ('r', 'v', 'm', 'p')
    and has_table_privilege('anon', c.oid, 'SELECT');
  if readable is not null then
    raise exception 'ASSERTION FAILED: anon still has SELECT on: %', readable;
  end if;

  -- Even if a privilege is granted by mistake, RLS must return no rows.
  begin
    perform count(*) from public.profiles;
    raise exception 'ASSERTION FAILED: anon can read profiles';
  exception when insufficient_privilege then
    null;
  end;
  begin
    perform count(*) from public.app_settings;
    raise exception 'ASSERTION FAILED: anon can read app_settings';
  exception when insufficient_privilege then
    null;
  end;
end $$;
reset role;

-- Admin: full visibility, audit and settings write.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
do $$
begin
  if (select count(*) from public.profiles) <> 9 then
    raise exception 'ASSERTION FAILED: admin profile visibility';
  end if;
  if (select count(*) from public.audit_logs) = 0 then
    raise exception 'ASSERTION FAILED: admin audit visibility';
  end if;
  if (select count(*) from public.sales) = 0 then
    raise exception 'ASSERTION FAILED: admin sales visibility';
  end if;
  update public.app_settings set description = 'QA admin write' where key = 'business_name';
end $$;
reset role;

-- Manager: audit is admin-only, operational reads remain.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
set local role authenticated;
do $$
begin
  if (select count(*) from public.audit_logs) <> 0 then
    raise exception 'ASSERTION FAILED: manager can read audit logs';
  end if;
  if (select count(*) from public.sales) = 0 then
    raise exception 'ASSERTION FAILED: manager sales visibility';
  end if;
end $$;
reset role;

-- Cashier: sales/cash read, no audit, no HR.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
set local role authenticated;
do $$
begin
  if (select count(*) from public.sales) = 0 then
    raise exception 'ASSERTION FAILED: cashier sales visibility';
  end if;
  if (select count(*) from public.audit_logs) <> 0 then
    raise exception 'ASSERTION FAILED: cashier can read audit logs';
  end if;
  if (select count(*) from public.employees) <> 0 then
    raise exception 'ASSERTION FAILED: cashier can read employees';
  end if;
end $$;
reset role;

-- Baker: production/inventory reads, no sales.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000004', true);
set local role authenticated;
do $$
begin
  if (select count(*) from public.items) = 0 then
    raise exception 'ASSERTION FAILED: baker item visibility';
  end if;
  if (select count(*) from public.sales) <> 0 then
    raise exception 'ASSERTION FAILED: baker can read sales';
  end if;
end $$;
reset role;

-- Store keeper: inventory reads, no sales, no audit.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000005', true);
set local role authenticated;
do $$
begin
  if (select count(*) from public.items) = 0 then
    raise exception 'ASSERTION FAILED: store keeper item visibility';
  end if;
  if (select count(*) from public.sales) <> 0 then
    raise exception 'ASSERTION FAILED: store keeper can read sales';
  end if;
  if (select count(*) from public.notifications where type = 'low_stock') = 0 then
    raise exception 'ASSERTION FAILED: store keeper low-stock notification visibility';
  end if;
end $$;
reset role;

-- HR officer: employee reads, no sales.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000006', true);
set local role authenticated;
do $$
begin
  if (select count(*) from public.employees) = 0 then
    raise exception 'ASSERTION FAILED: HR employee visibility';
  end if;
  if (select count(*) from public.sales) <> 0 then
    raise exception 'ASSERTION FAILED: HR can read sales';
  end if;
end $$;
reset role;

-- Accountant: payroll and financial reads.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000007', true);
set local role authenticated;
do $$
begin
  if (select count(*) from public.payroll_runs) = 0 then
    raise exception 'ASSERTION FAILED: accountant payroll visibility';
  end if;
  if (select count(*) from public.receivables) = 0 then
    raise exception 'ASSERTION FAILED: accountant receivable visibility';
  end if;
end $$;
reset role;

-- Staff: own profile and attendance self-service only.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000008', true);
set local role authenticated;
do $$
begin
  if (select count(*) from public.profiles) <> 9 then
    raise exception 'ASSERTION FAILED: staff profile visibility';
  end if;
  if (select count(*) from public.sales) <> 0 then
    raise exception 'ASSERTION FAILED: staff can read sales';
  end if;
  update public.profiles set full_name = 'Test Staff Updated' where id = '00000000-0000-0000-0000-000000000008';
  begin
    update public.profiles set role_code = 'admin' where id = '00000000-0000-0000-0000-000000000008';
    raise exception 'ASSERTION FAILED: staff changed own role';
  exception
    when others then
      if sqlerrm like 'ASSERTION FAILED:%' then
        raise;
      end if;
  end;
end $$;
reset role;

-- Customer: own profile and active products only.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000009', true);
set local role authenticated;
do $$
begin
  if (select count(*) from public.profiles) <> 1 then
    raise exception 'ASSERTION FAILED: customer profile visibility';
  end if;
  if (select count(*) from public.products) = 0 then
    raise exception 'ASSERTION FAILED: customer product visibility';
  end if;
  if (select count(*) from public.items) <> 0 then
    raise exception 'ASSERTION FAILED: customer item visibility';
  end if;
  if (select count(*) from public.sales) <> 0 then
    raise exception 'ASSERTION FAILED: customer sales visibility';
  end if;
  if (select count(*) from public.notifications where type = 'low_stock') <> 0 then
    raise exception 'ASSERTION FAILED: customer low-stock notification visibility';
  end if;
end $$;
reset role;

-- Avatar bucket and own-folder storage policy.
do $$
begin
  if (select count(*) from storage.buckets where id = 'avatars') <> 1 then
    raise exception 'ASSERTION FAILED: avatars bucket missing';
  end if;
  if (select count(*) from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'avatars_%') < 4 then
    raise exception 'ASSERTION FAILED: avatar storage policies missing';
  end if;
end $$;

-- A customer may write only inside their own avatar folder. Staff roles are
-- allowed to manage any bucket through can_write_bucket(), which is covered
-- separately.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000009', true);
set local role authenticated;
do $$
begin
  begin
    insert into storage.objects (bucket_id, name, owner)
    values ('avatars', '00000000-0000-0000-0000-000000000009/avatar.png', '00000000-0000-0000-0000-000000000009');
  exception
    when others then
      raise exception 'ASSERTION FAILED: own avatar upload rejected: %', sqlerrm;
  end;
  begin
    insert into storage.objects (bucket_id, name, owner)
    values ('avatars', '00000000-0000-0000-0000-000000000001/avatar.png', '00000000-0000-0000-0000-000000000009');
    raise exception 'ASSERTION FAILED: cross-user avatar upload allowed';
  exception
    when insufficient_privilege then
      null;
  end;
end $$;
reset role;

select pg_temp.assert_true(
  (select count(*) >= 4 from public.role_permissions where role_code = 'admin'),
  'admin permission catalog'
);
select pg_temp.assert_true(
  (select count(*) >= 1 from public.role_permissions where role_code = 'customer' and permission_code = 'products.view'),
  'customer product permission'
);

-- Deactivated records cannot be used in new sales.
insert into public.sales (
  id, receipt_no, branch_id, store_id, customer_id, cashier_id, sale_date,
  subtotal, discount_amount, tax_amount, total_amount, paid_amount,
  payment_status, status
) values (
  '34343434-3434-3434-3434-343434343434', 'TEST-SALE-INACTIVE-PRODUCT',
  '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222',
  null, '00000000-0000-0000-0000-000000000003',
  now(), 10, 0, 0, 10, 0, 'unpaid', 'completed'
);
update public.products set is_active = false
where id = '66666666-6666-6666-6666-666666666666';
select pg_temp.assert_raises(
  $$insert into public.sale_items (sale_id, product_id, product_name, quantity, unit_price, discount_amount, tax_amount, line_total)
    values ('34343434-3434-3434-3434-343434343434', '66666666-6666-6666-6666-666666666666', 'Inactive product', 1, 10, 0, 0, 10)$$,
  'inactive',
  'an inactive product cannot be added to a new sale'
);
update public.products set is_active = true
where id = '66666666-6666-6666-6666-666666666666';

-- Deactivated customers cannot buy on credit.
insert into public.sales (
  id, receipt_no, branch_id, store_id, customer_id, cashier_id, sale_date,
  subtotal, discount_amount, tax_amount, total_amount, paid_amount,
  payment_status, status
) values (
  '35353535-3535-3535-3535-353535353535', 'TEST-SALE-INACTIVE-CUSTOMER',
  '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222',
  '77777777-7777-7777-7777-777777777777', '00000000-0000-0000-0000-000000000003',
  now(), 10, 0, 0, 10, 0, 'unpaid', 'completed'
);
update public.customers set is_active = false
where id = '77777777-7777-7777-7777-777777777777';
select pg_temp.assert_raises(
  $$insert into public.sale_payments (sale_id, method, amount, received_by)
    values ('35353535-3535-3535-3535-353535353535', 'credit', 10, '00000000-0000-0000-0000-000000000003')$$,
  'inactive',
  'an inactive customer cannot buy on credit'
);
update public.customers set is_active = true
where id = '77777777-7777-7777-7777-777777777777';

-- Deactivated users lose every role helper and every role-gated RPC.
select set_config('request.jwt.claim.sub', '', true);
update public.profiles set is_active = false
where id = '00000000-0000-0000-0000-000000000001';
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
select pg_temp.assert_true(
  (select public.current_role_code()) is null,
  'a deactivated user has no role code'
);
select pg_temp.assert_true(
  not public.has_admin(),
  'a deactivated admin no longer counts as an admin'
);
select pg_temp.assert_true(
  not public.has_any_role(array['cashier', 'manager', 'accountant']),
  'a deactivated user has no staff roles'
);
select pg_temp.assert_raises(
  $$select public.fn_close_day('11111111-1111-1111-1111-111111111111', current_date - 1, 0)$$,
  'Not allowed',
  'a deactivated user cannot run a role-gated RPC'
);
select set_config('request.jwt.claim.sub', '', true);
update public.profiles set is_active = true
where id = '00000000-0000-0000-0000-000000000001';
select set_config('request.jwt.claim.sub', '', true);

-- New SECURITY DEFINER helpers must not be exposed as RPCs.
select pg_temp.assert_true(
  not has_function_privilege('anon', 'public.fn_daily_closing_locked()', 'execute'),
  'anon cannot execute the daily-closing guard'
);
select pg_temp.assert_true(
  not has_function_privilege('authenticated', 'public.fn_daily_closing_locked()', 'execute'),
  'authenticated cannot execute the daily-closing guard'
);
select pg_temp.assert_true(
  not has_function_privilege('authenticated', 'public.fn_payroll_payslip_guard()', 'execute'),
  'authenticated cannot execute the payslip guard'
);
select pg_temp.assert_true(
  not has_function_privilege('authenticated', 'public.fn_sale_item_guard()', 'execute'),
  'authenticated cannot execute the sale-item guard'
);
select pg_temp.assert_true(
  has_function_privilege('authenticated', 'public.fn_close_day(uuid,date,numeric,text)', 'execute'),
  'authenticated can execute fn_close_day'
);
select pg_temp.assert_true(
  not has_function_privilege('anon', 'public.fn_close_day(uuid,date,numeric,text)', 'execute'),
  'anon cannot execute fn_close_day'
);

-- Deactivated staff cannot be paid by regenerating payroll.
update public.employees set status = 'terminated'
where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
select pg_temp.assert_true(
  (select count(*) = 0 from public.employees
   where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and status in ('active', 'on_leave')),
  'a terminated employee is excluded from payroll generation'
);
update public.employees set status = 'active'
where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

-- ---------------------------------------------------------------------------
-- Round 4: product stock linking, stock/dashboard views, rent partial payment
-- ---------------------------------------------------------------------------

-- A tracked product points at its finished-good item and opening stock is a
-- positive adjustment into the shop store.
insert into public.items (
  id, sku, name, item_type, category_id, unit_id, cost_price, min_stock, is_active
) values (
  '55555555-5555-5555-5555-555555555505', 'TEST-TRACKED-ITEM',
  'Tracked product', 'finished_good',
  '44444444-4444-4444-4444-444444444444',
  '33333333-3333-3333-3333-333333333333', 20, 2, true
);
insert into public.products (
  id, sku, name, category_id, item_id, unit_id, price, cost, tax_rate, is_active
) values (
  '69696969-6969-6969-6969-696969696969', 'TEST-TRACKED-PROD',
  'Tracked product', '44444444-4444-4444-4444-444444444444',
  '55555555-5555-5555-5555-555555555505',
  '33333333-3333-3333-3333-333333333333', 50, 20, 0, true
);
insert into public.stock_movements (
  id, store_id, item_id, movement_type, quantity, unit_cost,
  reference_type, reference_id, created_by
) values (
  '2a2a2a2a-2a2a-2a2a-2a2a-2a2a2a2a2a2a',
  '22222222-2222-2222-2222-222222222222',
  '55555555-5555-5555-5555-555555555505',
  'adjustment', 4, 20, 'opening_stock',
  '69696969-6969-6969-6969-696969696969',
  '00000000-0000-0000-0000-000000000001'
);
select pg_temp.assert_true(
  (select item_id = '55555555-5555-5555-5555-555555555505'
   from public.products where id = '69696969-6969-6969-6969-696969696969'),
  'product is linked to its stock item'
);
select pg_temp.assert_true(
  (select quantity = 4 from public.stock_levels
   where store_id = '22222222-2222-2222-2222-222222222222'
     and item_id = '55555555-5555-5555-5555-555555555505'),
  'opening stock creates a positive stock level'
);

-- Selling a tracked product reduces stock by the sold quantity.
insert into public.sales (
  id, receipt_no, branch_id, store_id, cashier_id, sale_date,
  subtotal, discount_amount, tax_amount, total_amount, paid_amount,
  payment_status, status
) values (
  '2b2b2b2b-2b2b-2b2b-2b2b-2b2b2b2b2b2b', 'TEST-SALE-TRACKED',
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '00000000-0000-0000-0000-000000000003', now(),
  100, 0, 0, 100, 100, 'paid', 'completed'
);
insert into public.sale_items (
  sale_id, product_id, product_name, quantity, unit_price,
  discount_amount, tax_amount, line_total
) values (
  '2b2b2b2b-2b2b-2b2b-2b2b-2b2b2b2b2b2b',
  '69696969-6969-6969-6969-696969696969', 'Tracked product',
  2, 50, 0, 0, 100
);
insert into public.sale_payments (
  sale_id, cash_account_id, method, amount, received_by
) values (
  '2b2b2b2b-2b2b-2b2b-2b2b-2b2b2b2b2b2b',
  '88888888-8888-8888-8888-888888888881', 'cash', 100,
  '00000000-0000-0000-0000-000000000003'
);
select pg_temp.assert_true(
  (select quantity = 2 from public.stock_levels
   where store_id = '22222222-2222-2222-2222-222222222222'
     and item_id = '55555555-5555-5555-5555-555555555505'),
  'selling 2 pieces reduces tracked stock by 2'
);
select pg_temp.assert_true(
  (select count(*) = 1 from public.sale_payments
   where sale_id = '2b2b2b2b-2b2b-2b2b-2b2b-2b2b2b2b2b2b'),
  'sale payment exists'
);
select pg_temp.assert_true(
  (select count(*) = 1 from public.cash_transactions
   where reference_type = 'sale_payment' and reference_id =
     (select id from public.sale_payments
      where sale_id = '2b2b2b2b-2b2b-2b2b-2b2b-2b2b2b2b2b2b')
     and txn_type = 'in' and amount = 100),
  'sale payment posts a cash entry'
);

-- The stock view returns translated unit names and a low-stock flag.
select pg_temp.assert_true(
  (select unit_name = 'Test piece' and quantity = 2 and is_low = true
   from public.v_stock_overview
   where item_id = '55555555-5555-5555-5555-555555555505'),
  'stock overview exposes unit names and low-stock state'
);
select pg_temp.assert_true(
  (select stock_value >= 100 from public.v_dashboard_overview),
  'dashboard overview reflects stock value'
);

-- Rent partial payment, then full payment, then a rejected overpayment.
insert into public.rent_invoices (
  id, invoice_no, lease_id, tenant_id, property_id,
  period_start, period_end, amount, paid_amount, due_date, status
) values (
  '2c2c2c2c-2c2c-2c2c-2c2c-2c2c2c2c2c2c', 'TEST-RIN-PARTIAL',
  'dddddddd-dddd-dddd-dddd-dddddddddddd',
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  current_date, current_date + 30, 1000, 0, current_date, 'unpaid'
);
insert into public.rent_payments (
  id, invoice_id, cash_account_id, amount, payment_date, method, received_by
) values (
  '2d2d2d2d-2d2d-2d2d-2d2d-2d2d2d2d2d2d',
  '2c2c2c2c-2c2c-2c2c-2c2c-2c2c2c2c2c2c',
  '88888888-8888-8888-8888-888888888881', 400, current_date, 'cash',
  '00000000-0000-0000-0000-000000000001'
);
select pg_temp.assert_true(
  (select paid_amount = 400 and status = 'partial'
   from public.rent_invoices
   where id = '2c2c2c2c-2c2c-2c2c-2c2c-2c2c2c2c2c2c'),
  'partial rent payment updates invoice status and paid amount'
);
select pg_temp.assert_true(
  (select count(*) = 1 from public.cash_transactions
   where reference_type = 'rent_payment'
     and reference_id = '2d2d2d2d-2d2d-2d2d-2d2d-2d2d2d2d2d2d'
     and txn_type = 'in' and amount = 400),
  'partial rent payment posts a cash entry'
);
insert into public.rent_payments (
  id, invoice_id, cash_account_id, amount, payment_date, method, received_by
) values (
  '2e2e2e2e-2e2e-2e2e-2e2e-2e2e2e2e2e2e',
  '2c2c2c2c-2c2c-2c2c-2c2c-2c2c2c2c2c2c',
  '88888888-8888-8888-8888-888888888881', 600, current_date, 'telebirr',
  '00000000-0000-0000-0000-000000000001'
);
select pg_temp.assert_true(
  (select paid_amount = 1000 and status = 'paid'
   from public.rent_invoices
   where id = '2c2c2c2c-2c2c-2c2c-2c2c-2c2c2c2c2c2c'),
  'full rent payment settles the invoice'
);
select pg_temp.assert_raises(
  $$insert into public.rent_payments (
      invoice_id, amount, received_by
    ) values (
      '2c2c2c2c-2c2c-2c2c-2c2c-2c2c2c2c2c2c', 1,
      '00000000-0000-0000-0000-000000000001'
    )$$,
  'outstanding balance',
  'overpayment is rejected after a full rent payment'
);
select pg_temp.assert_true(
  (select rent_collected >= 6000 from public.v_dashboard_overview),
  'dashboard rent collected includes the partial and full payments'
);
select pg_temp.assert_true(
  (select sum(total_in) >= 6000 from public.v_cashflow_daily
   where day = current_date),
  'daily cashflow view reflects rent and sale cash entries'
);

rollback;
