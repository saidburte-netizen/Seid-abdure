-- Read-only views already present in the live project.
-- This migration makes the local contract database match the live project.
-- No table, column, policy or trigger is changed here.

create or replace view public.v_stock_overview as
select
  i.id as item_id,
  i.sku,
  i.name,
  i.item_type,
  coalesce(u.code, '') as unit_code,
  coalesce(u.name, '') as unit_name,
  coalesce(sum(l.quantity), 0) as quantity,
  i.min_stock,
  i.cost_price,
  (i.min_stock > 0 and coalesce(sum(l.quantity), 0) <= i.min_stock) as is_low,
  round(coalesce(sum(l.quantity), 0) * i.cost_price, 2) as stock_value,
  i.is_active
from public.items i
left join public.units u on u.id = i.unit_id
left join public.stock_levels l on l.item_id = i.id
group by i.id, u.code, u.name;

create or replace view public.v_dashboard_overview as
select
  (
    select coalesce(sum(s.total_amount), 0)
    from public.sales s
    where s.status = 'completed'
      and (s.sale_date at time zone 'Africa/Addis_Ababa')::date
          = (now() at time zone 'Africa/Addis_Ababa')::date
  ) as today_sales,
  (
    select coalesce(sum(b.balance), 0)
    from public.v_cash_account_balances b
  ) as cash_balance,
  (
    select count(*)
    from public.v_stock_overview v
    where v.is_low
  ) as low_stock_items,
  (
    select coalesce(sum(r.balance), 0)
    from public.receivables r
    where r.status in ('open', 'partial')
      and r.due_date < current_date
  ) as overdue_receivables,
  (
    select coalesce(sum(ri.amount - ri.paid_amount), 0)
    from public.rent_invoices ri
    where ri.status in ('unpaid', 'partial', 'overdue')
      and ri.due_date <= current_date + 7
  ) as rent_due,
  (
    select coalesce(sum(rp.amount), 0)
    from public.rent_payments rp
    where rp.payment_date = current_date
  ) as rent_collected,
  (
    select count(*)
    from public.attendance a
    where a.work_date = current_date
      and a.status in ('present', 'late')
  ) as staff_present_today,
  (
    select coalesce(sum(p.balance), 0)
    from public.payables p
    where p.status in ('open', 'partial')
  ) as payables_due,
  (
    select coalesce(sum(v.stock_value), 0)
    from public.v_stock_overview v
  ) as stock_value;

create or replace view public.v_cashflow_daily as
select
  t.txn_date as day,
  t.branch_id,
  coalesce(sum(t.amount) filter (where t.txn_type = 'in'), 0) as total_in,
  coalesce(sum(t.amount) filter (where t.txn_type = 'out'), 0) as total_out,
  coalesce(sum(t.amount) filter (where t.txn_type = 'in'), 0)
    - coalesce(sum(t.amount) filter (where t.txn_type = 'out'), 0) as net
from public.cash_transactions t
where t.status = 'approved'
group by t.txn_date, t.branch_id;

grant select on public.v_stock_overview to authenticated;
grant select on public.v_dashboard_overview to authenticated;
grant select on public.v_cashflow_daily to authenticated;
