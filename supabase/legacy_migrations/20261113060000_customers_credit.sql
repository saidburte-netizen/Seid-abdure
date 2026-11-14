-- Customers, credit limits, receivable ledger, and sales returns.

alter table public.customers
  add column if not exists email text,
  add column if not exists address text not null default '',
  add column if not exists credit_limit numeric(14, 2) not null default 0
    check (credit_limit >= 0),
  add column if not exists notes text not null default '',
  add column if not exists is_active boolean not null default true,
  add column if not exists updated_at timestamptz not null default now();

create trigger set_customers_updated_at
  before update on public.customers
  for each row execute function public.set_updated_at();

create table public.sale_returns (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  sale_id uuid not null references public.sales (id),
  customer_id uuid references public.customers (id),
  return_number text not null,
  status text not null default 'completed'
    check (status in ('completed', 'voided')),
  refund_method text not null default 'cash'
    check (refund_method in ('cash', 'customer_credit', 'original')),
  subtotal numeric(14, 2) not null default 0 check (subtotal >= 0),
  tax_total numeric(14, 2) not null default 0 check (tax_total >= 0),
  total numeric(14, 2) not null default 0 check (total >= 0),
  reason text not null default '',
  processed_by uuid not null default auth.uid() references public.profiles (id),
  created_at timestamptz not null default now(),
  unique (branch_id, return_number)
);

create table public.sale_return_items (
  id uuid primary key default gen_random_uuid(),
  return_id uuid not null references public.sale_returns (id) on delete cascade,
  sale_item_id uuid not null references public.sale_items (id),
  product_id uuid not null references public.products (id),
  quantity numeric(14, 3) not null check (quantity > 0),
  unit_price numeric(14, 2) not null check (unit_price >= 0),
  line_total numeric(14, 2) not null check (line_total >= 0)
);

create index sale_returns_branch_date_idx
  on public.sale_returns (branch_id, created_at desc);
create index sale_return_items_return_idx
  on public.sale_return_items (return_id);

alter table public.sale_returns enable row level security;
alter table public.sale_return_items enable row level security;

create policy "Sales staff can read returns"
  on public.sale_returns for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Sales staff can read return items"
  on public.sale_return_items for select to authenticated
  using (
    exists (
      select 1 from public.sale_returns sale_return
      where sale_return.id = return_id
        and public.user_has_branch_access(sale_return.branch_id)
    )
  );

-- Prevent credit sales from silently exceeding a configured limit. A zero
-- limit means "no credit facility" rather than unlimited credit.
create or replace function public.enforce_customer_credit_limit()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  customer public.customers;
  current_balance numeric(14, 2);
begin
  if new.entry_type not in ('credit_sale', 'adjustment') or new.debit = 0 then
    return new;
  end if;

  select * into customer from public.customers where id = new.customer_id;
  if not found or customer.credit_limit = 0 then
    if new.entry_type = 'credit_sale' then
      raise exception 'Customer does not have a credit facility';
    end if;
    return new;
  end if;

  select coalesce(sum(debit) - sum(credit), 0) into current_balance
  from public.customer_ledger
  where customer_id = new.customer_id;

  if current_balance + new.debit > customer.credit_limit then
    raise exception 'Credit limit exceeded: balance %, limit %, new charge %',
      current_balance, customer.credit_limit, new.debit;
  end if;

  return new;
end;
$$;

create trigger enforce_customer_credit_limit
  before insert on public.customer_ledger
  for each row execute function public.enforce_customer_credit_limit();

create or replace view public.customer_receivables
with (security_invoker = true)
as
select
  customer.id,
  customer.branch_id,
  customer.name,
  customer.phone,
  customer.credit_limit,
  coalesce(sum(ledger.debit) - sum(ledger.credit), 0) as balance,
  max(ledger.created_at) as last_activity
from public.customers customer
left join public.customer_ledger ledger on ledger.customer_id = customer.id
where customer.is_active
group by
  customer.id, customer.branch_id, customer.name, customer.phone,
  customer.credit_limit
having coalesce(sum(ledger.debit) - sum(ledger.credit), 0) <> 0;

create or replace function public.process_sale_return(
  target_sale uuid,
  return_lines jsonb,
  refund_method text default 'cash',
  return_reason text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  sale public.sales;
  sale_return public.sale_returns;
  line jsonb;
  sale_line public.sale_items;
  already_returned numeric(14, 3);
  product_row public.products;
  line_amount numeric(14, 2) := 0;
  ratio numeric(10, 6) := 1;
  subtotal numeric(14, 2) := 0;
  total numeric(14, 2) := 0;
  return_number text;
  account public.cash_accounts;
  remaining numeric(14, 3);
  total_returned numeric(14, 3);
  total_sold numeric(14, 3);
begin
  if refund_method not in ('cash', 'customer_credit', 'original') then
    raise exception 'Unsupported refund method %', refund_method;
  end if;

  select * into sale from public.sales where id = target_sale for update;
  if not found then
    raise exception 'Sale not found';
  end if;
  if not public.has_permission(sale.branch_id, 'customers.write') then
    raise exception 'Customer permission required';
  end if;
  if sale.status <> 'completed' then
    raise exception 'Returns are only possible for completed sales';
  end if;
  if return_lines is null or jsonb_array_length(return_lines) = 0 then
    raise exception 'A return requires at least one line';
  end if;

  if sale.subtotal > 0 then
    ratio := sale.grand_total / sale.subtotal;
  end if;

  return_number := public.next_document_number(sale.branch_id, 'return');

  for line in select * from jsonb_array_elements(return_lines)
  loop
    select * into sale_line
    from public.sale_items
    where id = (line ->> 'sale_item_id')::uuid
      and sale_id = sale.id;

    if not found then
      raise exception 'Sale line % is not part of this sale',
        line ->> 'sale_item_id';
    end if;

    select coalesce(sum(return_item.quantity), 0) into already_returned
    from public.sale_return_items return_item
    join public.sale_returns sr
      on sr.id = return_item.return_id
    where return_item.sale_item_id = sale_line.id
      and sr.status = 'completed';

    remaining := sale_line.quantity - already_returned;
    if (line ->> 'quantity')::numeric <= 0
      or (line ->> 'quantity')::numeric > remaining then
      raise exception 'Return quantity for line % must be between 0 and %',
        sale_line.id, remaining;
    end if;

    line_amount := round(
      (line ->> 'quantity')::numeric * sale_line.unit_price, 2
    );
    subtotal := subtotal + line_amount;
  end loop;

  total := round(subtotal * ratio, 2);

  insert into public.sale_returns (
    branch_id, sale_id, customer_id, return_number, refund_method,
    subtotal, tax_total, total, reason, processed_by
  )
  values (
    sale.branch_id, sale.id, sale.customer_id, return_number, refund_method,
    subtotal, total - subtotal, total, coalesce(return_reason, ''), auth.uid()
  )
  returning * into sale_return;

  for line in select * from jsonb_array_elements(return_lines)
  loop
    select * into sale_line from public.sale_items
    where id = (line ->> 'sale_item_id')::uuid and sale_id = sale.id;

    line_amount := round(
      (line ->> 'quantity')::numeric * sale_line.unit_price, 2
    );

    insert into public.sale_return_items (
      return_id, sale_item_id, product_id, quantity, unit_price, line_total
    )
    values (
      sale_return.id, sale_line.id, sale_line.product_id,
      (line ->> 'quantity')::numeric, sale_line.unit_price, line_amount
    );

    select * into product_row from public.products where id = sale_line.product_id;

    if product_row.inventory_item_id is not null then
      insert into public.stock_movements (
        branch_id, store_id, inventory_item_id, movement_type,
        quantity_delta, unit_cost, reference_id, notes, actor_id
      )
      select
        sale.branch_id, store.id, product_row.inventory_item_id, 'adjustment',
        (line ->> 'quantity')::numeric, product_row.cost_price,
        sale_return.id, 'Return ' || sale_return.return_number, auth.uid()
      from public.stores store
      where store.branch_id = sale.branch_id
      order by store.created_at
      limit 1;
    end if;
  end loop;

  if refund_method in ('customer_credit', 'original')
    and sale.customer_id is not null then
    insert into public.customer_ledger (
      branch_id, customer_id, entry_type, credit, reference_table,
      reference_id, notes
    )
    values (
      sale.branch_id, sale.customer_id, 'return', total, 'sale_returns',
      sale_return.id, 'Return ' || sale_return.return_number
    );
  else
    select * into account
    from public.cash_accounts
    where branch_id = sale.branch_id and account_type = 'cash'
    order by created_at limit 1;

    if not found then
      raise exception 'A cash account is required for cash refunds';
    end if;

    insert into public.cash_transactions (
      branch_id, cash_account_id, direction, category, amount, method,
      reference_id, notes, actor_id
    )
    values (
      sale.branch_id, account.id, 'out', 'refund', total, 'cash',
      sale_return.id, 'Refund ' || sale_return.return_number, auth.uid()
    );
  end if;

  select coalesce(sum(return_item.quantity), 0) into total_returned
  from public.sale_return_items return_item
  join public.sale_returns sr
    on sr.id = return_item.return_id
  where sr.sale_id = sale.id
    and sr.status = 'completed';

  select coalesce(sum(quantity), 0) into total_sold
  from public.sale_items where sale_id = sale.id;

  if total_returned >= total_sold then
    update public.sales set status = 'refunded' where id = sale.id;
  end if;

  insert into public.audit_logs (
    branch_id, actor_id, action, entity_table, entity_id, details
  )
  values (
    sale.branch_id, auth.uid(), 'sales.return', 'sale_returns', sale_return.id,
    jsonb_build_object(
      'sale_number', sale.sale_number,
      'return_number', sale_return.return_number,
      'total', total,
      'refund_method', refund_method
    )
  );

  return jsonb_build_object(
    'return_id', sale_return.id,
    'return_number', sale_return.return_number,
    'subtotal', subtotal,
    'total', total
  );
end;
$$;

create or replace function public.record_customer_payment(
  target_customer uuid,
  target_account uuid,
  payment_amount numeric,
  payment_method text default 'cash',
  payment_reference text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  customer public.customers;
  account public.cash_accounts;
  entry public.customer_ledger;
begin
  select * into customer from public.customers where id = target_customer;
  if not found then
    raise exception 'Customer not found';
  end if;
  if not public.has_permission(customer.branch_id, 'customers.write') then
    raise exception 'Customer permission required';
  end if;
  if payment_amount is null or payment_amount <= 0 then
    raise exception 'Payment must be positive';
  end if;

  select * into account
  from public.cash_accounts
  where id = target_account and branch_id = customer.branch_id;
  if not found then
    raise exception 'Cash account does not belong to this branch';
  end if;

  insert into public.customer_ledger (
    branch_id, customer_id, entry_type, credit, reference_table, notes
  )
  values (
    customer.branch_id, customer.id, 'payment', payment_amount,
    'cash_accounts', coalesce(payment_reference, '')
  )
  returning * into entry;

  insert into public.cash_transactions (
    branch_id, cash_account_id, direction, category, amount, method,
    reference_id, notes, actor_id
  )
  values (
    customer.branch_id, account.id, 'in', 'customer_payment', payment_amount,
    payment_method, entry.id, 'Payment from ' || customer.name, auth.uid()
  );

  insert into public.audit_logs (
    branch_id, actor_id, action, entity_table, entity_id, details
  )
  values (
    customer.branch_id, auth.uid(), 'customers.payment', 'customer_ledger',
    entry.id, jsonb_build_object('customer', customer.name, 'amount', payment_amount)
  );

  return jsonb_build_object(
    'ledger_id', entry.id, 'customer_id', customer.id, 'amount', payment_amount
  );
end;
$$;

revoke all on function public.process_sale_return(uuid, jsonb, text, text)
  from public, anon;
revoke all on function public.record_customer_payment(uuid, uuid, numeric, text, text)
  from public, anon;
grant execute on function public.process_sale_return(uuid, jsonb, text, text)
  to authenticated;
grant execute on function public.record_customer_payment(uuid, uuid, numeric, text, text)
  to authenticated;

comment on table public.sale_returns is
  'Immutable return header; processing restores stock and either refunds cash or credits the customer ledger.';
