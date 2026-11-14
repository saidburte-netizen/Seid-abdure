-- Supplier payables, aging, and statements.

create or replace view public.supplier_payables
with (security_invoker = true)
as
select
  bill.branch_id,
  bill.supplier_id,
  supplier.name as supplier_name,
  supplier.phone as supplier_phone,
  bill.id as bill_id,
  bill.bill_number,
  bill.issue_date,
  bill.due_date,
  bill.amount,
  bill.paid_amount,
  bill.amount - bill.paid_amount as balance,
  bill.status,
  case
    when bill.status in ('paid', 'void') then 0
    when bill.due_date >= current_date then 0
    else current_date - bill.due_date
  end as days_overdue,
  case
    when bill.status in ('paid', 'void') then 'settled'
    when bill.due_date >= current_date then 'current'
    when current_date - bill.due_date <= 30 then '1-30'
    when current_date - bill.due_date <= 60 then '31-60'
    when current_date - bill.due_date <= 90 then '61-90'
    else '90+'
  end as aging_bucket
from public.bills bill
left join public.suppliers supplier on supplier.id = bill.supplier_id
where bill.status in ('unpaid', 'partial');

create or replace view public.supplier_aging
with (security_invoker = true)
as
select
  branch_id,
  supplier_id,
  supplier_name,
  count(*) as open_bills,
  coalesce(sum(balance) filter (where aging_bucket = 'current'), 0) as current_amount,
  coalesce(sum(balance) filter (where aging_bucket = '1-30'), 0) as days_1_30,
  coalesce(sum(balance) filter (where aging_bucket = '31-60'), 0) as days_31_60,
  coalesce(sum(balance) filter (where aging_bucket = '61-90'), 0) as days_61_90,
  coalesce(sum(balance) filter (where aging_bucket = '90+'), 0) as days_over_90,
  coalesce(sum(balance), 0) as total_outstanding
from public.supplier_payables
group by branch_id, supplier_id, supplier_name;

create or replace function public.supplier_statement(
  target_branch uuid,
  target_supplier uuid,
  from_date date default (current_date - interval '1 year')::date,
  to_date date default current_date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  supplier public.suppliers;
  bill_lines jsonb;
  payment_lines jsonb;
  opening_balance numeric(14, 2);
  closing_balance numeric(14, 2);
begin
  if not public.has_permission(target_branch, 'payables.read') then
    raise exception 'Payables permission required';
  end if;

  select * into supplier
  from public.suppliers
  where id = target_supplier and branch_id = target_branch;
  if not found then
    raise exception 'Supplier not found in this branch';
  end if;

  select coalesce(sum(amount - paid_amount), 0) into opening_balance
  from public.bills
  where supplier_id = target_supplier
    and branch_id = target_branch
    and issue_date < from_date
    and status not in ('void');

  select coalesce(jsonb_agg(to_jsonb(row_data) order by row_data.issue_date), '[]')
    into bill_lines
  from (
    select
      bill.id, bill.bill_number, bill.issue_date, bill.due_date,
      bill.description, bill.amount, bill.paid_amount,
      bill.amount - bill.paid_amount as balance, bill.status
    from public.bills bill
    where bill.supplier_id = target_supplier
      and bill.branch_id = target_branch
      and bill.issue_date between from_date and to_date
  ) row_data;

  select coalesce(jsonb_agg(to_jsonb(row_data) order by row_data.paid_at), '[]')
    into payment_lines
  from (
    select
      payment.id, payment.paid_at, payment.amount, payment.method,
      payment.reference, bill.bill_number
    from public.bill_payments payment
    join public.bills bill on bill.id = payment.bill_id
    where bill.supplier_id = target_supplier
      and bill.branch_id = target_branch
      and payment.paid_at::date between from_date and to_date
  ) row_data;

  select coalesce(sum(amount - paid_amount), 0) into closing_balance
  from public.bills
  where supplier_id = target_supplier
    and branch_id = target_branch
    and issue_date <= to_date
    and status not in ('void');

  return jsonb_build_object(
    'supplier_id', supplier.id,
    'supplier_name', supplier.name,
    'from_date', from_date,
    'to_date', to_date,
    'opening_balance', opening_balance,
    'closing_balance', closing_balance,
    'bills', bill_lines,
    'payments', payment_lines
  );
end;
$$;

create or replace function public.record_supplier_payment(
  target_bill uuid,
  target_account uuid,
  payment_amount numeric,
  payment_method text default 'cash',
  payment_reference text default ''
)
returns jsonb
language sql
security definer
set search_path = public, pg_temp
as $$
  select public.pay_bill(
    target_bill, target_account, payment_amount, payment_method,
    payment_reference
  );
$$;

revoke all on function public.supplier_statement(uuid, uuid, date, date)
  from public, anon;
revoke all on function public.record_supplier_payment(uuid, uuid, numeric, text, text)
  from public, anon;
grant execute on function public.supplier_statement(uuid, uuid, date, date)
  to authenticated;
grant execute on function public.record_supplier_payment(uuid, uuid, numeric, text, text)
  to authenticated;

comment on view public.supplier_aging is
  'Outstanding supplier balances grouped into standard aging buckets.';
