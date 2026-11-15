-- Business-rule guards found by the contract sequence tests.
--
-- These rules were only enforced in the Flutter UI, so a direct API call
-- could break them. They are enforced here in the database because that is
-- the only place every client shares.
--
-- 1. A payment can never be zero, negative or larger than the outstanding
--    balance (customer credit, supplier payable, rent invoice, sale).
-- 2. A closed day is immutable once written. Only its notes may be appended.
-- 3. Payroll payslip money cannot change after the run leaves draft.
-- 4. A credit sale needs an active customer and must fit the credit limit.
-- 5. Inactive products and customers cannot be used in new sales.

-- 1. Payable payments were the only payment table without a positive check.
alter table public.payable_payments
  drop constraint if exists payable_payments_amount_check;
alter table public.payable_payments
  add constraint payable_payments_amount_check check (amount > 0);

-- 2. Closed days are immutable. Direct UPDATE/DELETE by a signed-in user is
-- rejected; only the notes field may change so a correction can be explained.
create or replace function public.fn_daily_closing_locked()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'A closed day cannot be deleted.';
  end if;

  if new.branch_id is distinct from old.branch_id
     or new.closing_date is distinct from old.closing_date
     or new.opening_cash is distinct from old.opening_cash
     or new.total_sales is distinct from old.total_sales
     or new.cash_sales is distinct from old.cash_sales
     or new.other_sales is distinct from old.other_sales
     or new.total_cash_in is distinct from old.total_cash_in
     or new.total_cash_out is distinct from old.total_cash_out
     or new.expected_cash is distinct from old.expected_cash
     or new.counted_cash is distinct from old.counted_cash
     or new.closed_by is distinct from old.closed_by then
    raise exception 'A closed day cannot be changed. Record a correction instead.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_daily_closing_locked on public.daily_closings;
create trigger trg_daily_closing_locked
  before update or delete on public.daily_closings
  for each row execute function public.fn_daily_closing_locked();

-- 3. Payroll payslip money is frozen once the run is approved or paid.
create or replace function public.fn_payroll_payslip_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
  v_run uuid;
begin
  v_run := case
    when tg_op = 'DELETE' then old.payroll_run_id
    else new.payroll_run_id
  end;

  select status into v_status
  from public.payroll_runs
  where id = v_run;

  if v_status is null then
    raise exception 'Payroll run not found.';
  end if;

  if tg_op = 'INSERT' then
    if v_status <> 'draft' then
      raise exception 'Payslips cannot be added after payroll approval.';
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    if v_status <> 'draft' then
      raise exception 'Payslips cannot be removed after payroll approval.';
    end if;
    return old;
  end if;

  if v_status <> 'draft' and (
       new.base_salary is distinct from old.base_salary
       or new.allowances is distinct from old.allowances
       or new.gross_pay is distinct from old.gross_pay
       or new.income_tax is distinct from old.income_tax
       or new.pension_employee is distinct from old.pension_employee
       or new.advance_deduction is distinct from old.advance_deduction
       or new.total_deductions is distinct from old.total_deductions
       or new.net_pay is distinct from old.net_pay
     ) then
    raise exception 'Payslip amounts cannot change after payroll approval.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_payroll_payslip_guard on public.payslips;
create trigger trg_payroll_payslip_guard
  before insert or update or delete on public.payslips
  for each row execute function public.fn_payroll_payslip_guard();

-- 4/5. New sale lines must reference an active product.
create or replace function public.fn_sale_item_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_active boolean;
begin
  select is_active into v_active
  from public.products
  where id = new.product_id;

  if v_active is null then
    raise exception 'Product not found.';
  end if;

  if not v_active then
    raise exception 'This product is inactive and cannot be sold.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_sale_item_guard on public.sale_items;
create trigger trg_sale_item_guard
  before insert on public.sale_items
  for each row execute function public.fn_sale_item_guard();

-- Customer credit payment: never overpay, never touch a written-off debt.
create or replace function public.fn_receivable_payment_apply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cust uuid;
  v_amount numeric;
  v_paid numeric;
  v_status text;
begin
  select customer_id, amount, paid_amount, status
  into v_cust, v_amount, v_paid, v_status
  from public.receivables
  where id = new.receivable_id
  for update;

  if not found then
    raise exception 'Receivable not found.';
  end if;

  if v_status = 'written_off' then
    raise exception 'This receivable has been written off.';
  end if;

  if new.amount > v_amount - v_paid then
    raise exception 'Payment exceeds the outstanding balance.';
  end if;

  update public.receivables
  set paid_amount = paid_amount + new.amount,
      status = case when paid_amount + new.amount >= amount then 'paid' else 'partial' end
  where id = new.receivable_id;

  insert into public.ledger_entries (party_type, customer_id, description, credit, reference_type, reference_id)
  values ('customer', v_cust, 'Payment received', new.amount, 'receivable_payment', new.id);

  if new.cash_account_id is not null then
    insert into public.cash_transactions (cash_account_id, txn_type, amount, txn_date, description, method, reference_type, reference_id, created_by)
    values (new.cash_account_id, 'in', new.amount, new.payment_date, 'Customer credit payment', new.method, 'receivable_payment', new.id, new.received_by);
  end if;

  return new;
end;
$$;

-- Supplier payable payment: never overpay a bill.
create or replace function public.fn_payable_payment_apply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supplier uuid;
  v_bill uuid;
  v_amount numeric;
  v_paid numeric;
  v_status text;
begin
  select supplier_id, bill_id, amount, paid_amount, status
  into v_supplier, v_bill, v_amount, v_paid, v_status
  from public.payables
  where id = new.payable_id
  for update;

  if not found then
    raise exception 'Payable not found.';
  end if;

  if v_status = 'cancelled' then
    raise exception 'This payable has been cancelled.';
  end if;

  if new.amount > v_amount - v_paid then
    raise exception 'Payment exceeds the outstanding balance.';
  end if;

  update public.payables
  set paid_amount = paid_amount + new.amount,
      status = case when paid_amount + new.amount >= amount then 'paid' else 'partial' end
  where id = new.payable_id;

  insert into public.ledger_entries (party_type, supplier_id, description, debit, reference_type, reference_id)
  values ('supplier', v_supplier, 'Payment made', new.amount, 'payable_payment', new.id);

  if v_bill is not null then
    update public.bills
    set paid_amount = paid_amount + new.amount,
        status = case when paid_amount + new.amount >= amount then 'paid' else 'partial' end
    where id = v_bill;
  end if;

  if new.cash_account_id is not null then
    insert into public.cash_transactions (cash_account_id, txn_type, amount, txn_date, description, method, reference_type, reference_id, created_by)
    values (new.cash_account_id, 'out', new.amount, new.payment_date, 'Supplier payment', new.method, 'payable_payment', new.id, new.paid_by);
  end if;

  return new;
end;
$$;

-- Rent payment: never overpay an invoice.
create or replace function public.fn_rent_payment_apply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_branch uuid;
  v_cat uuid;
  v_amount numeric;
  v_paid numeric;
  v_status text;
begin
  select amount, paid_amount, status
  into v_amount, v_paid, v_status
  from public.rent_invoices
  where id = new.invoice_id
  for update;

  if not found then
    raise exception 'Rent invoice not found.';
  end if;

  if v_status = 'cancelled' then
    raise exception 'This rent invoice has been cancelled.';
  end if;

  if new.amount > v_amount - v_paid then
    raise exception 'Payment exceeds the outstanding balance.';
  end if;

  update public.rent_invoices
  set paid_amount = paid_amount + new.amount,
      status = case when paid_amount + new.amount >= amount then 'paid' else 'partial' end
  where id = new.invoice_id;

  if new.cash_account_id is not null then
    select pr.branch_id into v_branch
    from public.rent_invoices ri
    join public.properties pr on pr.id = ri.property_id
    where ri.id = new.invoice_id;

    select id into v_cat from public.expense_categories where name = 'Rent Income';

    insert into public.cash_transactions (branch_id, cash_account_id, txn_type, category_id, amount, txn_date, description, method, reference_type, reference_id, created_by)
    values (v_branch, new.cash_account_id, 'in', v_cat, new.amount, new.payment_date, 'Rent payment', new.method, 'rent_payment', new.id, new.received_by);
  end if;

  return new;
end;
$$;

-- Sale payment: no overpayment, and credit needs an active customer inside
-- the credit limit.
create or replace function public.fn_sale_payment_apply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_branch uuid;
  v_cust uuid;
  v_cat uuid;
  v_total numeric;
  v_paid_total numeric;
  v_limit numeric;
  v_active boolean;
  v_outstanding numeric;
begin
  select branch_id, customer_id, total_amount
  into v_branch, v_cust, v_total
  from public.sales
  where id = new.sale_id
  for update;

  if not found then
    raise exception 'Sale not found.';
  end if;

  select coalesce(sum(amount), 0) into v_paid_total
  from public.sale_payments
  where sale_id = new.sale_id;
  -- The live trigger is AFTER INSERT, so this sum already includes the new
  -- payment. Compare it directly with the sale total.

  if new.method = 'credit' then
    if v_cust is null then
      raise exception 'A credit sale requires a customer.';
    end if;

    select credit_limit, is_active into v_limit, v_active
    from public.customers
    where id = v_cust;

    if v_limit is null then
      raise exception 'Customer not found.';
    end if;

    if not v_active then
      raise exception 'This customer is inactive and cannot buy on credit.';
    end if;

    if v_paid_total > v_total then
      raise exception 'Payment exceeds the outstanding balance.';
    end if;

    select coalesce(sum(balance), 0) into v_outstanding
    from public.receivables
    where customer_id = v_cust
      and status in ('open', 'partial');

    if v_outstanding + new.amount > v_limit then
      raise exception 'Credit limit exceeded.';
    end if;

    insert into public.receivables (customer_id, sale_id, description, amount, due_date, created_by)
    values (v_cust, new.sale_id, 'Credit sale', new.amount, current_date + 30, new.received_by);
  else
    if v_paid_total > v_total then
      raise exception 'Payment exceeds the outstanding balance.';
    end if;

    update public.sales set paid_amount = paid_amount + new.amount where id = new.sale_id;

    if new.cash_account_id is not null then
      select id into v_cat from public.expense_categories where name = 'Sales Income';

      insert into public.cash_transactions (branch_id, cash_account_id, txn_type, category_id, amount, txn_date, description, method, reference_type, reference_id, created_by)
      values (v_branch, new.cash_account_id, 'in', v_cat, new.amount, current_date, 'Sale payment', new.method, 'sale_payment', new.id, new.received_by);
    end if;
  end if;

  update public.sales
  set payment_status = case
    when paid_amount >= total_amount and total_amount > 0 then 'paid'
    when paid_amount > 0 then 'partial'
    when new.method = 'credit' then 'credit'
    else 'unpaid'
  end
  where id = new.sale_id;

  return new;
end;
$$;

-- Close day: refuse to silently overwrite an existing close.
create or replace function public.fn_close_day(p_branch uuid, p_date date, p_counted numeric, p_notes text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_open numeric;
  v_total numeric;
  v_cash_sales numeric;
  v_in numeric;
  v_out numeric;
  v_expected numeric;
  v_id uuid;
begin
  if auth.uid() is not null and not public.has_any_role(array['cashier', 'accountant', 'manager']) then
    raise exception 'Not allowed';
  end if;

  if exists (
    select 1 from public.daily_closings
    where branch_id = p_branch and closing_date = p_date
  ) then
    raise exception 'This day is already closed. Record a correction instead.';
  end if;

  select counted_cash into v_open
  from public.daily_closings
  where branch_id = p_branch and closing_date < p_date
  order by closing_date desc
  limit 1;
  v_open := coalesce(v_open, 0);

  select coalesce(sum(total_amount), 0) into v_total
  from public.sales
  where branch_id = p_branch
    and status = 'completed'
    and (sale_date at time zone 'Africa/Addis_Ababa')::date = p_date;

  select coalesce(sum(sp.amount), 0) into v_cash_sales
  from public.sale_payments sp
  join public.sales s on s.id = sp.sale_id
  where s.branch_id = p_branch
    and s.status = 'completed'
    and sp.method = 'cash'
    and (s.sale_date at time zone 'Africa/Addis_Ababa')::date = p_date;

  select coalesce(sum(t.amount) filter (where t.txn_type = 'in'), 0),
         coalesce(sum(t.amount) filter (where t.txn_type = 'out'), 0)
  into v_in, v_out
  from public.cash_transactions t
  join public.cash_accounts a on a.id = t.cash_account_id
  where t.branch_id = p_branch
    and t.txn_date = p_date
    and a.account_type = 'cash_drawer'
    and t.status = 'approved';

  v_expected := v_open + v_in - v_out;

  insert into public.daily_closings (
    branch_id, closing_date, opening_cash, total_sales, cash_sales,
    other_sales, total_cash_in, total_cash_out, expected_cash,
    counted_cash, closed_by, notes
  ) values (
    p_branch, p_date, v_open, v_total, v_cash_sales,
    v_total - v_cash_sales, v_in, v_out, v_expected,
    p_counted, auth.uid(), p_notes
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.fn_close_day(uuid, date, numeric, text) from public;
revoke all on function public.fn_close_day(uuid, date, numeric, text) from anon;
grant execute on function public.fn_close_day(uuid, date, numeric, text) to authenticated;

-- The new trigger helpers are SECURITY DEFINER. PostgreSQL grants EXECUTE to
-- PUBLIC by default, so revoke them explicitly; they must only fire from their
-- triggers, never as RPCs.
revoke all on function public.fn_daily_closing_locked() from public, anon, authenticated;
revoke all on function public.fn_payroll_payslip_guard() from public, anon, authenticated;
revoke all on function public.fn_sale_item_guard() from public, anon, authenticated;
