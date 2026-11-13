-- Sales, point of sale, receipts, payments, customer credit posting, and daily
-- cash close. Totals are calculated on the server inside a single transaction.

alter table public.sales
  add column if not exists sale_number text,
  add column if not exists client_id uuid,
  add column if not exists notes text not null default '',
  add column if not exists void_reason text,
  add column if not exists voided_by uuid references public.profiles (id),
  add column if not exists voided_at timestamptz;

create unique index if not exists sales_branch_number_idx
  on public.sales (branch_id, sale_number) where sale_number is not null;
create unique index if not exists sales_branch_client_idx
  on public.sales (branch_id, client_id) where client_id is not null;

create table public.receipts (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  sale_id uuid not null references public.sales (id) on delete cascade,
  receipt_number text not null,
  total numeric(14, 2) not null check (total >= 0),
  issued_by uuid not null default auth.uid() references public.profiles (id),
  issued_at timestamptz not null default now(),
  payload jsonb not null default '{}'::jsonb,
  unique (branch_id, receipt_number),
  unique (sale_id)
);

create table public.daily_closes (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  business_date date not null,
  opening_cash numeric(14, 2) not null default 0,
  cash_in numeric(14, 2) not null default 0,
  cash_out numeric(14, 2) not null default 0,
  expected_cash numeric(14, 2) not null default 0,
  counted_cash numeric(14, 2) not null default 0,
  variance numeric(14, 2) not null default 0,
  sales_total numeric(14, 2) not null default 0,
  status text not null default 'closed' check (status in ('closed', 'reopened')),
  notes text not null default '',
  closed_by uuid not null default auth.uid() references public.profiles (id),
  closed_at timestamptz not null default now(),
  unique (branch_id, business_date)
);

create table public.customer_ledger (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  customer_id uuid not null references public.customers (id) on delete cascade,
  entry_type text not null check (
    entry_type in ('credit_sale', 'payment', 'refund', 'return', 'adjustment', 'opening')
  ),
  debit numeric(14, 2) not null default 0 check (debit >= 0),
  credit numeric(14, 2) not null default 0 check (credit >= 0),
  reference_table text,
  reference_id uuid,
  notes text not null default '',
  actor_id uuid not null default auth.uid() references public.profiles (id),
  created_at timestamptz not null default now(),
  check (debit = 0 or credit = 0)
);

create index customer_ledger_customer_idx
  on public.customer_ledger (branch_id, customer_id, created_at desc);
create index receipts_sale_idx on public.receipts (sale_id);
create index daily_closes_branch_date_idx
  on public.daily_closes (branch_id, business_date desc);

alter table public.receipts enable row level security;
alter table public.daily_closes enable row level security;
alter table public.customer_ledger enable row level security;

create policy "Sales staff can read receipts"
  on public.receipts for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Sales staff can read daily closes"
  on public.daily_closes for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Sales staff can read customer ledger"
  on public.customer_ledger for select to authenticated
  using (public.user_has_branch_access(branch_id));

create or replace view public.customer_balances
with (security_invoker = true)
as
select
  customer_id,
  branch_id,
  sum(debit) - sum(credit) as balance,
  max(created_at) as last_activity
from public.customer_ledger
group by customer_id, branch_id;

create or replace view public.cash_account_balances
with (security_invoker = true)
as
select
  account.id as cash_account_id,
  account.branch_id,
  account.name,
  account.account_type,
  coalesce(sum(
    case transaction.direction
      when 'in' then transaction.amount
      else -transaction.amount
    end
  ), 0) as balance
from public.cash_accounts account
left join public.cash_transactions transaction
  on transaction.cash_account_id = account.id
group by account.id, account.branch_id, account.name, account.account_type;

create or replace function public.complete_sale(
  target_branch uuid,
  sale_items jsonb,
  sale_payments jsonb,
  target_customer uuid default null,
  sale_discount numeric default 0,
  sale_notes text default '',
  p_client_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  existing_sale public.sales;
  new_sale public.sales;
  product_row public.products;
  item jsonb;
  payment jsonb;
  settings public.branch_settings;
  quantity numeric(14, 3);
  unit_price numeric(14, 2);
  subtotal numeric(14, 2) := 0;
  service_charge numeric(14, 2) := 0;
  taxable_base numeric(14, 2);
  tax_total numeric(14, 2) := 0;
  grand_total numeric(14, 2) := 0;
  paid_total numeric(14, 2) := 0;
  credit_total numeric(14, 2) := 0;
  receipt_number text;
  sale_number text;
  receipt public.receipts;
  account public.cash_accounts;
  payment_method text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if not public.has_permission(target_branch, 'sales.write') then
    raise exception 'Sales permission required';
  end if;
  if sale_items is null or jsonb_array_length(sale_items) = 0 then
    raise exception 'A sale requires at least one item';
  end if;
  if sale_discount is null or sale_discount < 0 then
    raise exception 'Discount cannot be negative';
  end if;

  if p_client_id is not null then
    select * into existing_sale
    from public.sales
    where branch_id = target_branch and client_id = p_client_id;
    if found then
      return jsonb_build_object(
        'sale_id', existing_sale.id,
        'sale_number', existing_sale.sale_number,
        'grand_total', existing_sale.grand_total,
        'idempotent', true
      );
    end if;
  end if;

  if target_customer is not null and not exists (
    select 1 from public.customers
    where id = target_customer and branch_id = target_branch
  ) then
    raise exception 'Customer does not belong to this branch';
  end if;

  select * into settings
  from public.branch_settings
  where branch_id = target_branch;
  if not found then
    insert into public.branch_settings (branch_id)
    values (target_branch)
    on conflict (branch_id) do nothing;
    select * into settings
    from public.branch_settings
    where branch_id = target_branch;
  end if;

  -- Validate and price every line from the catalog. Client supplied prices are
  -- deliberately ignored so a modified client cannot change catalog prices.
  for item in select * from jsonb_array_elements(sale_items)
  loop
    quantity := (item ->> 'quantity')::numeric;
    if quantity is null or quantity <= 0 then
      raise exception 'Sale quantity must be positive';
    end if;

    select * into product_row
    from public.products
    where id = (item ->> 'product_id')::uuid
      and branch_id = target_branch
      and is_active;

    if not found then
      raise exception 'Product % is unavailable', item ->> 'product_id';
    end if;

    unit_price := product_row.selling_price;
    subtotal := subtotal + round(quantity * unit_price, 2);
  end loop;

  if sale_discount > subtotal then
    raise exception 'Discount cannot exceed the subtotal';
  end if;

  taxable_base := subtotal - sale_discount;
  service_charge := round(taxable_base * settings.service_charge_rate, 2);

  if settings.tax_inclusive then
    tax_total := round(
      (taxable_base + service_charge) -
      (taxable_base + service_charge) / (1 + settings.tax_rate),
      2
    );
    grand_total := taxable_base + service_charge;
  else
    tax_total := round(
      (taxable_base + service_charge) * settings.tax_rate, 2
    );
    grand_total := taxable_base + service_charge + tax_total;
  end if;

  for payment in select * from jsonb_array_elements(sale_payments)
  loop
    payment_method := payment ->> 'method';
    if payment_method not in (
      'cash', 'telebirr', 'cbe_birr', 'bank', 'credit', 'other'
    ) then
      raise exception 'Unsupported payment method %', payment_method;
    end if;
    if (payment ->> 'amount')::numeric <= 0 then
      raise exception 'Payment amount must be positive';
    end if;
    paid_total := paid_total + (payment ->> 'amount')::numeric;
    if payment_method = 'credit' then
      credit_total := credit_total + (payment ->> 'amount')::numeric;
    end if;
  end loop;

  if paid_total < grand_total then
    raise exception 'Payments (%) do not cover the total (%)',
      paid_total, grand_total;
  end if;
  if credit_total > 0 and target_customer is null then
    raise exception 'Credit sales require a customer';
  end if;

  sale_number := public.next_document_number(target_branch, 'sale');

  insert into public.sales (
    branch_id, customer_id, sale_number, status, subtotal, discount,
    tax_total, grand_total, notes, client_id
  )
  values (
    target_branch, target_customer, sale_number, 'completed', subtotal,
    sale_discount, tax_total, grand_total, coalesce(sale_notes, ''), p_client_id
  )
  returning * into new_sale;

  for item in select * from jsonb_array_elements(sale_items)
  loop
    quantity := (item ->> 'quantity')::numeric;
    select * into product_row
    from public.products
    where id = (item ->> 'product_id')::uuid;

    insert into public.sale_items (
      sale_id, product_id, quantity, unit_price, line_total
    )
    values (
      new_sale.id, product_row.id, quantity, product_row.selling_price,
      round(quantity * product_row.selling_price, 2)
    );

    if product_row.inventory_item_id is not null then
      insert into public.stock_movements (
        branch_id, store_id, inventory_item_id, movement_type,
        quantity_delta, unit_cost, reference_id, notes, actor_id
      )
      select
        target_branch,
        store.id,
        product_row.inventory_item_id,
        'sale',
        -quantity,
        product_row.cost_price,
        new_sale.id,
        'Sale ' || new_sale.sale_number,
        auth.uid()
      from public.stores store
      where store.branch_id = target_branch
      order by store.created_at
      limit 1;
    end if;
  end loop;

  for payment in select * from jsonb_array_elements(sale_payments)
  loop
    payment_method := payment ->> 'method';

    insert into public.payments (sale_id, method, amount, reference)
    values (
      new_sale.id, payment_method, (payment ->> 'amount')::numeric,
      payment ->> 'reference'
    );

    if payment_method = 'credit' then
      insert into public.customer_ledger (
        branch_id, customer_id, entry_type, debit, reference_table,
        reference_id, notes
      )
      values (
        target_branch, target_customer, 'credit_sale',
        (payment ->> 'amount')::numeric, 'sales', new_sale.id,
        'Credit sale ' || new_sale.sale_number
      );
    else
      select * into account
      from public.cash_accounts
      where branch_id = target_branch
        and account_type = case
          when payment_method = 'cash' then 'cash'
          when payment_method in ('telebirr', 'cbe_birr') then 'mobile_money'
          when payment_method = 'bank' then 'bank'
          else account_type
        end
      order by created_at
      limit 1;

      if found then
        insert into public.cash_transactions (
          branch_id, cash_account_id, direction, category, amount, method,
          reference_id, notes, actor_id
        )
        values (
          target_branch, account.id, 'in', 'sale',
          (payment ->> 'amount')::numeric, payment_method, new_sale.id,
          'Payment for ' || new_sale.sale_number, auth.uid()
        );
      end if;
    end if;
  end loop;

  receipt_number := public.next_document_number(target_branch, 'receipt');

  insert into public.receipts (
    branch_id, sale_id, receipt_number, total, payload
  )
  values (
    target_branch, new_sale.id, receipt_number, grand_total,
    jsonb_build_object(
      'sale_number', new_sale.sale_number,
      'subtotal', subtotal,
      'discount', sale_discount,
      'service_charge', service_charge,
      'tax_total', tax_total,
      'grand_total', grand_total,
      'payments', sale_payments
    )
  )
  returning * into receipt;

  insert into public.audit_logs (
    branch_id, actor_id, action, entity_table, entity_id, details
  )
  values (
    target_branch, auth.uid(), 'sales.complete', 'sales', new_sale.id,
    jsonb_build_object(
      'sale_number', new_sale.sale_number,
      'grand_total', grand_total,
      'receipt_number', receipt.receipt_number
    )
  );

  return jsonb_build_object(
    'sale_id', new_sale.id,
    'sale_number', new_sale.sale_number,
    'receipt_id', receipt.id,
    'receipt_number', receipt.receipt_number,
    'subtotal', subtotal,
    'discount', sale_discount,
    'service_charge', service_charge,
    'tax_total', tax_total,
    'grand_total', grand_total,
    'paid_total', paid_total,
    'idempotent', false
  );
end;
$$;

create or replace function public.void_sale(
  target_sale uuid,
  reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  sale public.sales;
  item_row record;
  payment_row record;
  restored integer := 0;
  account public.cash_accounts;
begin
  select * into sale from public.sales where id = target_sale for update;

  if not found then
    raise exception 'Sale not found';
  end if;
  if not public.has_permission(sale.branch_id, 'sales.void') then
    raise exception 'Void permission required';
  end if;
  if sale.status <> 'completed' then
    raise exception 'Only completed sales can be voided';
  end if;
  if reason is null or length(trim(reason)) < 3 then
    raise exception 'A void reason is required';
  end if;

  for item_row in
    select sale_item.*, product.inventory_item_id, product.cost_price
    from public.sale_items sale_item
    join public.products product on product.id = sale_item.product_id
    where sale_item.sale_id = sale.id
  loop
    if item_row.inventory_item_id is not null then
      insert into public.stock_movements (
        branch_id, store_id, inventory_item_id, movement_type,
        quantity_delta, unit_cost, reference_id, notes, actor_id
      )
      select
        sale.branch_id, store.id, item_row.inventory_item_id, 'adjustment',
        item_row.quantity, item_row.cost_price, sale.id,
        'Void of sale ' || sale.sale_number, auth.uid()
      from public.stores store
      where store.branch_id = sale.branch_id
      order by store.created_at
      limit 1;
      restored := restored + 1;
    end if;
  end loop;

  for payment_row in
    select * from public.payments where sale_id = sale.id
  loop
    if payment_row.method = 'credit' then
      insert into public.customer_ledger (
        branch_id, customer_id, entry_type, credit, reference_table,
        reference_id, notes
      )
      values (
        sale.branch_id, sale.customer_id, 'adjustment',
        payment_row.amount, 'sales', sale.id,
        'Void of credit sale ' || sale.sale_number
      );
    else
      select * into account
      from public.cash_accounts
      where branch_id = sale.branch_id
        and account_type = case
          when payment_row.method = 'cash' then 'cash'
          when payment_row.method in ('telebirr', 'cbe_birr') then 'mobile_money'
          else 'bank'
        end
      order by created_at limit 1;

      if found then
        insert into public.cash_transactions (
          branch_id, cash_account_id, direction, category, amount, method,
          reference_id, notes, actor_id
        )
        values (
          sale.branch_id, account.id, 'out', 'sale_void',
          payment_row.amount, payment_row.method, sale.id,
          'Void of sale ' || sale.sale_number, auth.uid()
        );
      end if;
    end if;
  end loop;

  update public.sales
     set status = 'voided',
         void_reason = reason,
         voided_by = auth.uid(),
         voided_at = now()
   where id = sale.id;

  insert into public.audit_logs (
    branch_id, actor_id, action, entity_table, entity_id, details
  )
  values (
    sale.branch_id, auth.uid(), 'sales.void', 'sales', sale.id,
    jsonb_build_object('reason', reason, 'restored_lines', restored)
  );

  return jsonb_build_object(
    'sale_id', sale.id,
    'restored_lines', restored,
    'status', 'voided'
  );
end;
$$;

create or replace function public.close_business_day(
  target_branch uuid,
  business_date date,
  counted_cash numeric,
  close_notes text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  previous_close public.daily_closes;
  closing public.daily_closes;
  opening numeric(14, 2) := 0;
  inflow numeric(14, 2) := 0;
  outflow numeric(14, 2) := 0;
  sales_amount numeric(14, 2) := 0;
  expected numeric(14, 2) := 0;
begin
  if not public.has_permission(target_branch, 'cash.write') then
    raise exception 'Cash permission required';
  end if;
  if business_date > current_date then
    raise exception 'Cannot close a future business day';
  end if;
  if counted_cash is null or counted_cash < 0 then
    raise exception 'Counted cash must be zero or greater';
  end if;

  select * into previous_close
  from public.daily_closes
  where branch_id = target_branch
    and business_date < close_business_day.business_date
    and status = 'closed'
  order by business_date desc
  limit 1;

  if found then
    opening := previous_close.counted_cash;
  end if;

  select
    coalesce(sum(amount) filter (where direction = 'in'), 0),
    coalesce(sum(amount) filter (where direction = 'out'), 0)
    into inflow, outflow
  from public.cash_transactions
  where branch_id = target_branch
    and created_at::date = business_date;

  select coalesce(sum(grand_total), 0) into sales_amount
  from public.sales
  where branch_id = target_branch
    and status = 'completed'
    and created_at::date = business_date;

  expected := opening + inflow - outflow;

  insert into public.daily_closes (
    branch_id, business_date, opening_cash, cash_in, cash_out,
    expected_cash, counted_cash, variance, sales_total, notes, closed_by
  )
  values (
    target_branch, business_date, opening, inflow, outflow,
    expected, counted_cash, counted_cash - expected, sales_amount,
    coalesce(close_notes, ''), auth.uid()
  )
  on conflict (branch_id, business_date) do update
    set opening_cash = excluded.opening_cash,
        cash_in = excluded.cash_in,
        cash_out = excluded.cash_out,
        expected_cash = excluded.expected_cash,
        counted_cash = excluded.counted_cash,
        variance = excluded.variance,
        sales_total = excluded.sales_total,
        notes = excluded.notes,
        closed_by = auth.uid(),
        closed_at = now(),
        status = 'closed'
  returning * into closing;

  insert into public.audit_logs (
    branch_id, actor_id, action, entity_table, entity_id, details
  )
  values (
    target_branch, auth.uid(), 'cash.daily_close', 'daily_closes', closing.id,
    jsonb_build_object(
      'business_date', business_date,
      'variance', closing.variance
    )
  );

  return to_jsonb(closing);
end;
$$;

revoke all on function public.complete_sale(
  uuid, jsonb, jsonb, uuid, numeric, text, uuid
) from public, anon;
revoke all on function public.void_sale(uuid, text) from public, anon;
revoke all on function public.close_business_day(uuid, date, numeric, text)
  from public, anon;
grant execute on function public.complete_sale(
  uuid, jsonb, jsonb, uuid, numeric, text, uuid
) to authenticated;
grant execute on function public.void_sale(uuid, text) to authenticated;
grant execute on function public.close_business_day(uuid, date, numeric, text)
  to authenticated;

comment on table public.receipts is
  'Immutable receipt snapshot emitted by complete_sale; totals also live on sales.';
comment on function public.complete_sale(uuid, jsonb, jsonb, uuid, numeric, text, uuid) is
  'Atomically prices a sale from the catalog, records payments, posts stock and cash movements, updates customer credit, and issues a receipt. client_id makes retries idempotent.';
