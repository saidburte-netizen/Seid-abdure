-- Dashboard and reporting functions. All functions are read-only, branch
-- scoped, and return JSON so the Flutter client can render and export them.

create or replace function public.report_dashboard(target_branch uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  result jsonb;
begin
  if not public.has_permission(target_branch, 'reports.read') then
    raise exception 'Reports permission required';
  end if;

  select jsonb_build_object(
    'branch_id', target_branch,
    'generated_at', now(),
    'today_sales', coalesce((
      select sum(grand_total) from public.sales
      where branch_id = target_branch and status = 'completed'
        and created_at::date = current_date
    ), 0),
    'month_sales', coalesce((
      select sum(grand_total) from public.sales
      where branch_id = target_branch and status = 'completed'
        and created_at >= date_trunc('month', current_date)
    ), 0),
    'sales_count_today', coalesce((
      select count(*) from public.sales
      where branch_id = target_branch and status = 'completed'
        and created_at::date = current_date
    ), 0),
    'cash_balance', coalesce((
      select sum(balance) from public.cash_account_balances
      where branch_id = target_branch
    ), 0),
    'receivables', coalesce((
      select sum(balance) from public.customer_receivables
      where branch_id = target_branch
    ), 0),
    'payables', coalesce((
      select sum(amount - paid_amount) from public.bills
      where branch_id = target_branch and status in ('unpaid', 'partial')
    ), 0),
    'low_stock_items', coalesce((
      select count(*) from (
        select item.id
        from public.inventory_items item
        left join public.stock_movements movement
          on movement.inventory_item_id = item.id
        where item.branch_id = target_branch and item.is_active
          and item.minimum_quantity > 0
        group by item.id, item.minimum_quantity
        having coalesce(sum(movement.quantity_delta), 0) <= item.minimum_quantity
      ) low_stock
    ), 0),
    'pending_expenses', coalesce((
      select count(*) from public.expenses
      where branch_id = target_branch and status = 'pending'
    ), 0),
    'pending_leave', coalesce((
      select count(*) from public.leave_requests
      where branch_id = target_branch and status = 'pending'
    ), 0),
    'active_employees', coalesce((
      select count(*) from public.employees
      where branch_id = target_branch and status in ('active', 'on_leave')
    ), 0),
    'batches_today', coalesce((
      select count(*) from public.production_batches
      where branch_id = target_branch and scheduled_for = current_date
    ), 0),
    'rent_outstanding', coalesce((
      select sum(amount - paid_amount) from public.rent_invoices
      where branch_id = target_branch and status in ('unpaid', 'partial')
    ), 0),
    'revenue_this_month', coalesce((
      select sum(grand_total - tax_total) from public.sales
      where branch_id = target_branch and status = 'completed'
        and created_at >= date_trunc('month', current_date)
    ), 0)
  ) into result;

  return result;
end;
$$;

create or replace function public.report_sales(
  target_branch uuid,
  from_date date,
  to_date date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  result jsonb;
begin
  if not public.has_permission(target_branch, 'reports.read') then
    raise exception 'Reports permission required';
  end if;

  select jsonb_build_object(
    'from_date', from_date,
    'to_date', to_date,
    'totals', (
      select jsonb_build_object(
        'sales_count', count(*),
        'gross_sales', coalesce(sum(grand_total), 0),
        'discounts', coalesce(sum(discount), 0),
        'tax', coalesce(sum(tax_total), 0),
        'net_sales', coalesce(sum(subtotal - discount), 0),
        'average_sale', coalesce(avg(grand_total), 0)
      )
      from public.sales
      where branch_id = target_branch and status = 'completed'
        and created_at::date between from_date and to_date
    ),
    'daily', coalesce((
      select jsonb_agg(to_jsonb(day_row) order by day_row.business_date)
      from (
        select
          created_at::date as business_date,
          count(*) as sales_count,
          sum(grand_total) as gross_sales,
          sum(grand_total - tax_total) as net_sales
        from public.sales
        where branch_id = target_branch and status = 'completed'
          and created_at::date between from_date and to_date
        group by created_at::date
      ) day_row
    ), '[]'::jsonb),
    'top_products', coalesce((
      select jsonb_agg(to_jsonb(product_row) order by product_row.revenue desc)
      from (
        select
          product.name,
          sum(sale_item.quantity) as quantity,
          sum(sale_item.line_total) as revenue
        from public.sale_items sale_item
        join public.sales sale on sale.id = sale_item.sale_id
        join public.products product on product.id = sale_item.product_id
        where sale.branch_id = target_branch and sale.status = 'completed'
          and sale.created_at::date between from_date and to_date
        group by product.name
        order by revenue desc
        limit 10
      ) product_row
    ), '[]'::jsonb),
    'payment_mix', coalesce((
      select jsonb_agg(to_jsonb(payment_row) order by payment_row.amount desc)
      from (
        select method, count(*) as payments, sum(amount) as amount
        from public.payments payment
        join public.sales sale on sale.id = payment.sale_id
        where sale.branch_id = target_branch and sale.status = 'completed'
          and sale.created_at::date between from_date and to_date
        group by method
      ) payment_row
    ), '[]'::jsonb),
    'by_cashier', coalesce((
      select jsonb_agg(to_jsonb(cashier_row) order by cashier_row.gross_sales desc)
      from (
        select
          profile.full_name as cashier,
          count(*) as sales_count,
          sum(sale.grand_total) as gross_sales
        from public.sales sale
        join public.profiles profile on profile.id = sale.cashier_id
        where sale.branch_id = target_branch and sale.status = 'completed'
          and sale.created_at::date between from_date and to_date
        group by profile.full_name
      ) cashier_row
    ), '[]'::jsonb)
  ) into result;

  return result;
end;
$$;

create or replace function public.report_inventory(target_branch uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  result jsonb;
begin
  if not public.has_permission(target_branch, 'reports.read') then
    raise exception 'Reports permission required';
  end if;

  select jsonb_build_object(
    'items', coalesce((
      select jsonb_agg(to_jsonb(item_row) order by item_row.value desc)
      from (
        select
          item.id,
          item.name,
          item.unit,
          item.minimum_quantity,
          item.cost_price,
          coalesce(sum(movement.quantity_delta), 0) as on_hand,
          coalesce(sum(movement.quantity_delta), 0) * item.cost_price as value
        from public.inventory_items item
        left join public.stock_movements movement
          on movement.inventory_item_id = item.id
        where item.branch_id = target_branch and item.is_active
        group by item.id
      ) item_row
    ), '[]'::jsonb),
    'total_value', coalesce((
      select sum(on_hand * cost_price)
      from (
        select
          item.cost_price,
          coalesce(sum(movement.quantity_delta), 0) as on_hand
        from public.inventory_items item
        left join public.stock_movements movement
          on movement.inventory_item_id = item.id
        where item.branch_id = target_branch and item.is_active
        group by item.id, item.cost_price
      ) valuation
    ), 0),
    'low_stock', coalesce((
      select jsonb_agg(to_jsonb(low_row))
      from (
        select
          item.id, item.name, item.minimum_quantity,
          coalesce(sum(movement.quantity_delta), 0) as on_hand
        from public.inventory_items item
        left join public.stock_movements movement
          on movement.inventory_item_id = item.id
        where item.branch_id = target_branch and item.is_active
          and item.minimum_quantity > 0
        group by item.id
        having coalesce(sum(movement.quantity_delta), 0) <= item.minimum_quantity
      ) low_row
    ), '[]'::jsonb)
  ) into result;

  return result;
end;
$$;

create or replace function public.report_production(
  target_branch uuid,
  from_date date,
  to_date date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  result jsonb;
begin
  if not public.has_permission(target_branch, 'reports.read') then
    raise exception 'Reports permission required';
  end if;

  select jsonb_build_object(
    'from_date', from_date,
    'to_date', to_date,
    'summary', (
      select jsonb_build_object(
        'batches', count(*),
        'planned_quantity', coalesce(sum(planned_quantity), 0),
        'produced_quantity', coalesce(sum(produced_quantity), 0),
        'completed_batches', count(*) filter (where status = 'completed')
      )
      from public.production_batches
      where branch_id = target_branch
        and scheduled_for between from_date and to_date
    ),
    'batches', coalesce((
      select jsonb_agg(to_jsonb(batch_row) order by batch_row.scheduled_for desc)
      from (
        select
          batch.batch_number,
          batch.scheduled_for,
          batch.status,
          batch.planned_quantity,
          batch.produced_quantity,
          recipe.name as recipe,
          product.name as product
        from public.production_batches batch
        join public.recipes recipe on recipe.id = batch.recipe_id
        join public.products product on product.id = recipe.product_id
        where batch.branch_id = target_branch
          and batch.scheduled_for between from_date and to_date
      ) batch_row
    ), '[]'::jsonb),
    'consumption', coalesce((
      select jsonb_agg(to_jsonb(consumption_row) order by consumption_row.quantity desc)
      from (
        select
          item.name,
          item.unit,
          sum(consumption.quantity) as quantity,
          sum(consumption.quantity * coalesce(consumption.unit_cost, 0)) as cost
        from public.production_batch_consumptions consumption
        join public.production_batches batch on batch.id = consumption.batch_id
        join public.inventory_items item on item.id = consumption.inventory_item_id
        where batch.branch_id = target_branch
          and batch.scheduled_for between from_date and to_date
        group by item.name, item.unit
      ) consumption_row
    ), '[]'::jsonb)
  ) into result;

  return result;
end;
$$;

create or replace function public.report_profit_and_loss(
  target_branch uuid,
  from_date date,
  to_date date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  revenue numeric(14, 2);
  discounts numeric(14, 2);
  tax numeric(14, 2);
  cogs numeric(14, 2);
  expenses_total numeric(14, 2);
  payroll_total numeric(14, 2);
  rent_income numeric(14, 2);
  gross_profit numeric(14, 2);
  net_profit numeric(14, 2);
begin
  if not public.has_permission(target_branch, 'reports.read') then
    raise exception 'Reports permission required';
  end if;

  select
    coalesce(sum(subtotal), 0),
    coalesce(sum(discount), 0),
    coalesce(sum(tax_total), 0)
    into revenue, discounts, tax
  from public.sales
  where branch_id = target_branch and status = 'completed'
    and created_at::date between from_date and to_date;

  select coalesce(sum(
    sale_item.quantity * product.cost_price
  ), 0) into cogs
  from public.sale_items sale_item
  join public.sales sale on sale.id = sale_item.sale_id
  join public.products product on product.id = sale_item.product_id
  where sale.branch_id = target_branch and sale.status = 'completed'
    and sale.created_at::date between from_date and to_date;

  select coalesce(sum(amount), 0) into expenses_total
  from public.expenses
  where branch_id = target_branch and status = 'paid'
    and expense_date between from_date and to_date;

  select coalesce(sum(net_total), 0) into payroll_total
  from public.payroll_runs
  where branch_id = target_branch and status in ('approved', 'paid')
    and period_start <= to_date
    and period_end >= from_date;

  select coalesce(sum(paid_amount), 0) into rent_income
  from public.rent_invoices
  where branch_id = target_branch
    and period_start between from_date and to_date;

  gross_profit := revenue - discounts - cogs;
  net_profit := gross_profit + rent_income - expenses_total - payroll_total;

  return jsonb_build_object(
    'from_date', from_date,
    'to_date', to_date,
    'revenue', revenue,
    'discounts', discounts,
    'tax', tax,
    'cost_of_goods_sold', cogs,
    'gross_profit', gross_profit,
    'rent_income', rent_income,
    'expenses', expenses_total,
    'payroll', payroll_total,
    'net_profit', net_profit
  );
end;
$$;

create or replace function public.report_receivables(target_branch uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  result jsonb;
begin
  if not public.has_permission(target_branch, 'reports.read') then
    raise exception 'Reports permission required';
  end if;

  select jsonb_build_object(
    'total', coalesce(sum(balance), 0),
    'customers', coalesce((
      select jsonb_agg(to_jsonb(customer_row) order by customer_row.balance desc)
      from (
        select
          id, name, phone, credit_limit, balance, last_activity
        from public.customer_receivables
        where branch_id = target_branch
      ) customer_row
    ), '[]'::jsonb)
  ) into result
  from public.customer_receivables
  where branch_id = target_branch;

  return result;
end;
$$;

create or replace function public.report_payables(target_branch uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  result jsonb;
begin
  if not public.has_permission(target_branch, 'reports.read') then
    raise exception 'Reports permission required';
  end if;

  select jsonb_build_object(
    'total', coalesce(sum(total_outstanding), 0),
    'suppliers', coalesce((
      select jsonb_agg(to_jsonb(supplier_row) order by supplier_row.total_outstanding desc)
      from public.supplier_aging supplier_row
      where supplier_row.branch_id = target_branch
    ), '[]'::jsonb)
  ) into result
  from public.supplier_aging
  where branch_id = target_branch;

  return result;
end;
$$;

create or replace function public.report_rentals(target_branch uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  result jsonb;
begin
  if not public.has_permission(target_branch, 'reports.read') then
    raise exception 'Reports permission required';
  end if;

  select jsonb_build_object(
    'total_outstanding', coalesce(sum(outstanding), 0),
    'total_invoiced', coalesce(sum(invoiced_total), 0),
    'total_collected', coalesce(sum(collected_total), 0),
    'leases', coalesce((
      select jsonb_agg(to_jsonb(lease_row) order by lease_row.property_name, lease_row.unit_name)
      from public.rent_roll lease_row
      where lease_row.branch_id = target_branch
    ), '[]'::jsonb)
  ) into result
  from public.rent_roll
  where branch_id = target_branch;

  return result;
end;
$$;

create or replace function public.report_payroll(target_run uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  result jsonb;
  run public.payroll_runs;
begin
  select * into run from public.payroll_runs where id = target_run;
  if not found then
    raise exception 'Payroll run not found';
  end if;
  if not public.has_permission(run.branch_id, 'reports.read') then
    raise exception 'Reports permission required';
  end if;

  select jsonb_build_object(
    'payroll_run_id', run.id,
    'period_start', run.period_start,
    'period_end', run.period_end,
    'status', run.status,
    'gross_total', run.gross_total,
    'deduction_total', run.deduction_total,
    'net_total', run.net_total,
    'payslips', coalesce((
      select jsonb_agg(to_jsonb(payslip_row) order by payslip_row.full_name)
      from (
        select
          payslip.payslip_number,
          employee.full_name,
          employee.employee_number,
          payslip.days_worked,
          payslip.overtime_hours,
          payslip.gross_pay,
          payslip.total_deductions,
          payslip.net_pay
        from public.payslips payslip
        join public.employees employee on employee.id = payslip.employee_id
        where payslip.payroll_run_id = run.id
      ) payslip_row
    ), '[]'::jsonb)
  ) into result;

  return result;
end;
$$;

create or replace function public.export_branch_data(target_branch uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  result jsonb;
begin
  if not public.has_permission(target_branch, 'reports.export') then
    raise exception 'Export permission required';
  end if;

  select jsonb_build_object(
    'exported_at', now(),
    'branch', (select to_jsonb(branch) from public.branches branch where id = target_branch),
    'settings', (select to_jsonb(settings) from public.branch_settings settings where branch_id = target_branch),
    'products', (
      select coalesce(jsonb_agg(to_jsonb(product)), '[]'::jsonb)
      from public.products product where branch_id = target_branch
    ),
    'inventory_items', (
      select coalesce(jsonb_agg(to_jsonb(item)), '[]'::jsonb)
      from public.inventory_items item where branch_id = target_branch
    ),
    'stock_movements', (
      select coalesce(jsonb_agg(to_jsonb(movement)), '[]'::jsonb)
      from public.stock_movements movement where branch_id = target_branch
    ),
    'customers', (
      select coalesce(jsonb_agg(to_jsonb(customer)), '[]'::jsonb)
      from public.customers customer where branch_id = target_branch
    ),
    'sales', (
      select coalesce(jsonb_agg(to_jsonb(sale)), '[]'::jsonb)
      from public.sales sale where branch_id = target_branch
    ),
    'sale_items', (
      select coalesce(jsonb_agg(to_jsonb(item)), '[]'::jsonb)
      from public.sale_items item
      join public.sales sale on sale.id = item.sale_id
      where sale.branch_id = target_branch
    ),
    'cash_accounts', (
      select coalesce(jsonb_agg(to_jsonb(account)), '[]'::jsonb)
      from public.cash_accounts account where branch_id = target_branch
    ),
    'cash_transactions', (
      select coalesce(jsonb_agg(to_jsonb(transaction)), '[]'::jsonb)
      from public.cash_transactions transaction where branch_id = target_branch
    ),
    'employees', (
      select coalesce(jsonb_agg(to_jsonb(employee)), '[]'::jsonb)
      from public.employees employee where branch_id = target_branch
    ),
    'payroll_runs', (
      select coalesce(jsonb_agg(to_jsonb(run)), '[]'::jsonb)
      from public.payroll_runs run where branch_id = target_branch
    ),
    'properties', (
      select coalesce(jsonb_agg(to_jsonb(property)), '[]'::jsonb)
      from public.properties property where branch_id = target_branch
    ),
    'leases', (
      select coalesce(jsonb_agg(to_jsonb(lease)), '[]'::jsonb)
      from public.leases lease where branch_id = target_branch
    ),
    'audit_logs', (
      select coalesce(jsonb_agg(to_jsonb(log)), '[]'::jsonb)
      from public.audit_logs log where branch_id = target_branch
    )
  ) into result;

  return result;
end;
$$;

revoke all on function public.report_dashboard(uuid) from public, anon;
revoke all on function public.report_sales(uuid, date, date) from public, anon;
revoke all on function public.report_inventory(uuid) from public, anon;
revoke all on function public.report_production(uuid, date, date) from public, anon;
revoke all on function public.report_profit_and_loss(uuid, date, date) from public, anon;
revoke all on function public.report_receivables(uuid) from public, anon;
revoke all on function public.report_payables(uuid) from public, anon;
revoke all on function public.report_rentals(uuid) from public, anon;
revoke all on function public.report_payroll(uuid) from public, anon;
revoke all on function public.export_branch_data(uuid) from public, anon;

grant execute on function public.report_dashboard(uuid) to authenticated;
grant execute on function public.report_sales(uuid, date, date) to authenticated;
grant execute on function public.report_inventory(uuid) to authenticated;
grant execute on function public.report_production(uuid, date, date) to authenticated;
grant execute on function public.report_profit_and_loss(uuid, date, date) to authenticated;
grant execute on function public.report_receivables(uuid) to authenticated;
grant execute on function public.report_payables(uuid) to authenticated;
grant execute on function public.report_rentals(uuid) to authenticated;
grant execute on function public.report_payroll(uuid) to authenticated;
grant execute on function public.export_branch_data(uuid) to authenticated;

comment on function public.report_dashboard(uuid) is
  'Single-call dashboard payload for a branch; every field is derived from ledger data.';
comment on function public.export_branch_data(uuid) is
  'Logical JSON backup of core branch data for owner-controlled export.';
