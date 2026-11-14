-- Inventory controls, purchasing, suppliers, transfers, counts, and adjustments.

alter table public.inventory_items
  add column if not exists cost_price numeric(14, 2) not null default 0
    check (cost_price >= 0),
  add column if not exists barcode text,
  add column if not exists is_active boolean not null default true,
  add column if not exists updated_at timestamptz not null default now();

create unique index if not exists inventory_items_branch_barcode_idx
  on public.inventory_items (branch_id, barcode) where barcode is not null;

create trigger set_inventory_items_updated_at
  before update on public.inventory_items
  for each row execute function public.set_updated_at();

create table public.suppliers (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  name text not null,
  contact_name text not null default '',
  phone text,
  email text,
  address text not null default '',
  tin text,
  payment_terms_days integer not null default 0
    check (payment_terms_days >= 0 and payment_terms_days <= 365),
  is_active boolean not null default true,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (branch_id, name)
);

create table public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  supplier_id uuid not null references public.suppliers (id),
  po_number text not null,
  status text not null default 'draft'
    check (status in ('draft', 'ordered', 'partially_received', 'received', 'cancelled')),
  ordered_at date,
  expected_at date,
  subtotal numeric(14, 2) not null default 0 check (subtotal >= 0),
  tax_total numeric(14, 2) not null default 0 check (tax_total >= 0),
  total numeric(14, 2) not null default 0 check (total >= 0),
  notes text not null default '',
  created_by uuid not null default auth.uid() references public.profiles (id),
  approved_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (branch_id, po_number)
);

create table public.purchase_order_items (
  id uuid primary key default gen_random_uuid(),
  purchase_order_id uuid not null
    references public.purchase_orders (id) on delete cascade,
  inventory_item_id uuid not null references public.inventory_items (id),
  quantity numeric(14, 3) not null check (quantity > 0),
  unit_cost numeric(14, 2) not null check (unit_cost >= 0),
  received_quantity numeric(14, 3) not null default 0
    check (received_quantity >= 0),
  line_total numeric(14, 2) not null check (line_total >= 0),
  unique (purchase_order_id, inventory_item_id)
);

create table public.goods_receipts (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  purchase_order_id uuid not null references public.purchase_orders (id),
  store_id uuid not null references public.stores (id),
  receipt_number text not null,
  received_at timestamptz not null default now(),
  received_by uuid not null default auth.uid() references public.profiles (id),
  notes text not null default '',
  total_cost numeric(14, 2) not null default 0 check (total_cost >= 0),
  unique (branch_id, receipt_number)
);

create table public.goods_receipt_items (
  id uuid primary key default gen_random_uuid(),
  goods_receipt_id uuid not null references public.goods_receipts (id) on delete cascade,
  purchase_order_item_id uuid not null references public.purchase_order_items (id),
  inventory_item_id uuid not null references public.inventory_items (id),
  quantity numeric(14, 3) not null check (quantity > 0),
  unit_cost numeric(14, 2) not null check (unit_cost >= 0),
  line_total numeric(14, 2) not null check (line_total >= 0)
);

create table public.stock_adjustments (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  store_id uuid not null references public.stores (id),
  reason text not null,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  requested_by uuid not null default auth.uid() references public.profiles (id),
  approved_by uuid references public.profiles (id),
  approved_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.stock_adjustment_items (
  id uuid primary key default gen_random_uuid(),
  stock_adjustment_id uuid not null
    references public.stock_adjustments (id) on delete cascade,
  inventory_item_id uuid not null references public.inventory_items (id),
  quantity_delta numeric(14, 3) not null check (quantity_delta <> 0),
  unit_cost numeric(14, 2),
  notes text not null default ''
);

create table public.stock_transfers (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  from_store_id uuid not null references public.stores (id),
  to_store_id uuid not null references public.stores (id),
  status text not null default 'pending'
    check (status in ('pending', 'completed', 'cancelled')),
  notes text not null default '',
  requested_by uuid not null default auth.uid() references public.profiles (id),
  completed_by uuid references public.profiles (id),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  check (from_store_id <> to_store_id)
);

create table public.stock_transfer_items (
  id uuid primary key default gen_random_uuid(),
  stock_transfer_id uuid not null references public.stock_transfers (id) on delete cascade,
  inventory_item_id uuid not null references public.inventory_items (id),
  quantity numeric(14, 3) not null check (quantity > 0),
  unit_cost numeric(14, 2)
);

create table public.stock_counts (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  store_id uuid not null references public.stores (id),
  status text not null default 'draft'
    check (status in ('draft', 'submitted', 'approved', 'cancelled')),
  counted_at date not null default current_date,
  counted_by uuid not null default auth.uid() references public.profiles (id),
  approved_by uuid references public.profiles (id),
  notes text not null default '',
  created_at timestamptz not null default now()
);

create table public.stock_count_items (
  id uuid primary key default gen_random_uuid(),
  stock_count_id uuid not null references public.stock_counts (id) on delete cascade,
  inventory_item_id uuid not null references public.inventory_items (id),
  system_quantity numeric(14, 3) not null default 0,
  counted_quantity numeric(14, 3) not null check (counted_quantity >= 0),
  unit_cost numeric(14, 2),
  unique (stock_count_id, inventory_item_id)
);

create index suppliers_branch_name_idx
  on public.suppliers (branch_id, name) where is_active;
create index purchase_orders_branch_status_idx
  on public.purchase_orders (branch_id, status, created_at desc);
create index goods_receipts_branch_date_idx
  on public.goods_receipts (branch_id, received_at desc);
create index stock_adjustments_branch_status_idx
  on public.stock_adjustments (branch_id, status, created_at desc);
create index stock_transfers_branch_status_idx
  on public.stock_transfers (branch_id, status, created_at desc);
create index stock_counts_branch_date_idx
  on public.stock_counts (branch_id, counted_at desc);

create trigger set_suppliers_updated_at
  before update on public.suppliers
  for each row execute function public.set_updated_at();
create trigger set_purchase_orders_updated_at
  before update on public.purchase_orders
  for each row execute function public.set_updated_at();

alter table public.suppliers enable row level security;
alter table public.purchase_orders enable row level security;
alter table public.purchase_order_items enable row level security;
alter table public.goods_receipts enable row level security;
alter table public.goods_receipt_items enable row level security;
alter table public.stock_adjustments enable row level security;
alter table public.stock_adjustment_items enable row level security;
alter table public.stock_transfers enable row level security;
alter table public.stock_transfer_items enable row level security;
alter table public.stock_counts enable row level security;
alter table public.stock_count_items enable row level security;

create policy "Purchasing staff can read suppliers"
  on public.suppliers for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Purchasing staff can write suppliers"
  on public.suppliers for insert to authenticated
  with check (public.has_permission(branch_id, 'purchasing.write'));
create policy "Purchasing staff can update suppliers"
  on public.suppliers for update to authenticated
  using (public.has_permission(branch_id, 'purchasing.write'))
  with check (public.has_permission(branch_id, 'purchasing.write'));
create policy "Purchasing staff can delete suppliers"
  on public.suppliers for delete to authenticated
  using (public.has_permission(branch_id, 'purchasing.write'));

create policy "Purchasing staff can read purchase orders"
  on public.purchase_orders for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Purchasing staff can write purchase orders"
  on public.purchase_orders for insert to authenticated
  with check (
    public.has_permission(branch_id, 'purchasing.write')
    and created_by = auth.uid()
  );
create policy "Purchasing staff can update open purchase orders"
  on public.purchase_orders for update to authenticated
  using (
    public.has_permission(branch_id, 'purchasing.write')
    and status in ('draft', 'ordered', 'partially_received')
  )
  with check (
    public.has_permission(branch_id, 'purchasing.write')
    and status in ('draft', 'ordered', 'partially_received', 'cancelled')
  );

create policy "Purchasing staff can read purchase order items"
  on public.purchase_order_items for select to authenticated
  using (
    exists (
      select 1 from public.purchase_orders purchase_order
      where purchase_order.id = purchase_order_id
        and public.user_has_branch_access(purchase_order.branch_id)
    )
  );
create policy "Purchasing staff can write purchase order items"
  on public.purchase_order_items for insert to authenticated
  with check (
    exists (
      select 1 from public.purchase_orders purchase_order
      where purchase_order.id = purchase_order_id
        and public.has_permission(purchase_order.branch_id, 'purchasing.write')
    )
  );
create policy "Purchasing staff can update purchase order items"
  on public.purchase_order_items for update to authenticated
  using (
    exists (
      select 1 from public.purchase_orders purchase_order
      where purchase_order.id = purchase_order_id
        and public.has_permission(purchase_order.branch_id, 'purchasing.write')
    )
  )
  with check (
    exists (
      select 1 from public.purchase_orders purchase_order
      where purchase_order.id = purchase_order_id
        and public.has_permission(purchase_order.branch_id, 'purchasing.write')
    )
  );
create policy "Purchasing staff can delete purchase order items"
  on public.purchase_order_items for delete to authenticated
  using (
    exists (
      select 1 from public.purchase_orders purchase_order
      where purchase_order.id = purchase_order_id
        and public.has_permission(purchase_order.branch_id, 'purchasing.write')
    )
  );

create policy "Purchasing staff can read goods receipts"
  on public.goods_receipts for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Purchasing staff can read goods receipt items"
  on public.goods_receipt_items for select to authenticated
  using (
    exists (
      select 1 from public.goods_receipts receipt
      where receipt.id = goods_receipt_id
        and public.user_has_branch_access(receipt.branch_id)
    )
  );

create policy "Inventory staff can read adjustments"
  on public.stock_adjustments for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Inventory staff can request adjustments"
  on public.stock_adjustments for insert to authenticated
  with check (
    public.has_permission(branch_id, 'inventory.write')
    and requested_by = auth.uid()
  );
create policy "Inventory staff can read adjustment items"
  on public.stock_adjustment_items for select to authenticated
  using (
    exists (
      select 1 from public.stock_adjustments adjustment
      where adjustment.id = stock_adjustment_id
        and public.user_has_branch_access(adjustment.branch_id)
    )
  );
create policy "Inventory staff can request adjustment items"
  on public.stock_adjustment_items for insert to authenticated
  with check (
    exists (
      select 1 from public.stock_adjustments adjustment
      where adjustment.id = stock_adjustment_id
        and public.has_permission(adjustment.branch_id, 'inventory.write')
    )
  );

create policy "Inventory staff can read transfers"
  on public.stock_transfers for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Inventory staff can request transfers"
  on public.stock_transfers for insert to authenticated
  with check (
    public.has_permission(branch_id, 'inventory.write')
    and requested_by = auth.uid()
  );
create policy "Inventory staff can read transfer items"
  on public.stock_transfer_items for select to authenticated
  using (
    exists (
      select 1 from public.stock_transfers transfer
      where transfer.id = stock_transfer_id
        and public.user_has_branch_access(transfer.branch_id)
    )
  );
create policy "Inventory staff can request transfer items"
  on public.stock_transfer_items for insert to authenticated
  with check (
    exists (
      select 1 from public.stock_transfers transfer
      where transfer.id = stock_transfer_id
        and public.has_permission(transfer.branch_id, 'inventory.write')
    )
  );

create policy "Inventory staff can read counts"
  on public.stock_counts for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Inventory staff can create counts"
  on public.stock_counts for insert to authenticated
  with check (
    public.has_permission(branch_id, 'inventory.write')
    and counted_by = auth.uid()
  );
create policy "Inventory staff can update draft counts"
  on public.stock_counts for update to authenticated
  using (
    public.has_permission(branch_id, 'inventory.write')
    and status in ('draft', 'submitted')
  )
  with check (
    public.has_permission(branch_id, 'inventory.write')
    and status in ('draft', 'submitted')
  );
create policy "Inventory staff can read count items"
  on public.stock_count_items for select to authenticated
  using (
    exists (
      select 1 from public.stock_counts stock_count
      where stock_count.id = stock_count_id
        and public.user_has_branch_access(stock_count.branch_id)
    )
  );
create policy "Inventory staff can write count items"
  on public.stock_count_items for insert to authenticated
  with check (
    exists (
      select 1 from public.stock_counts stock_count
      where stock_count.id = stock_count_id
        and public.has_permission(stock_count.branch_id, 'inventory.write')
    )
  );
create policy "Inventory staff can update count items"
  on public.stock_count_items for update to authenticated
  using (
    exists (
      select 1 from public.stock_counts stock_count
      where stock_count.id = stock_count_id
        and public.has_permission(stock_count.branch_id, 'inventory.write')
    )
  )
  with check (
    exists (
      select 1 from public.stock_counts stock_count
      where stock_count.id = stock_count_id
        and public.has_permission(stock_count.branch_id, 'inventory.write')
    )
  );

-- ---------------------------------------------------------------------------
-- Purchasing workflow
-- ---------------------------------------------------------------------------

create or replace function public.receive_purchase_order(
  target_order uuid,
  target_store uuid,
  receipt_lines jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  purchase_order public.purchase_orders;
  receipt public.goods_receipts;
  line jsonb;
  order_line public.purchase_order_items;
  store public.stores;
  receipt_total numeric(14, 2) := 0;
  received_total numeric(14, 3);
  ordered_total numeric(14, 3);
  receipt_number text;
begin
  select * into purchase_order
  from public.purchase_orders
  where id = target_order
  for update;

  if not found then
    raise exception 'Purchase order not found';
  end if;
  if not public.has_permission(purchase_order.branch_id, 'purchasing.write') then
    raise exception 'Purchasing permission required';
  end if;
  if purchase_order.status in ('received', 'cancelled') then
    raise exception 'Purchase order cannot receive goods in status %',
      purchase_order.status;
  end if;

  select * into store
  from public.stores
  where id = target_store and branch_id = purchase_order.branch_id;
  if not found then
    raise exception 'Store does not belong to the purchase order branch';
  end if;

  receipt_number := public.next_document_number(
    purchase_order.branch_id, 'goods_receipt'
  );

  insert into public.goods_receipts (
    branch_id, purchase_order_id, store_id, receipt_number, notes
  )
  values (
    purchase_order.branch_id, purchase_order.id, store.id, receipt_number,
    coalesce(receipt_lines ->> 'notes', '')
  )
  returning * into receipt;

  for line in select * from jsonb_array_elements(receipt_lines -> 'items')
  loop
    select * into order_line
    from public.purchase_order_items
    where purchase_order_id = purchase_order.id
      and inventory_item_id = (line ->> 'inventory_item_id')::uuid;

    if not found then
      raise exception 'Item % is not part of this purchase order',
        line ->> 'inventory_item_id';
    end if;

    if (line ->> 'quantity')::numeric <= 0 then
      raise exception 'Received quantity must be positive';
    end if;

    insert into public.goods_receipt_items (
      goods_receipt_id, purchase_order_item_id, inventory_item_id,
      quantity, unit_cost, line_total
    )
    values (
      receipt.id, order_line.id, order_line.inventory_item_id,
      (line ->> 'quantity')::numeric,
      coalesce((line ->> 'unit_cost')::numeric, order_line.unit_cost),
      (line ->> 'quantity')::numeric *
        coalesce((line ->> 'unit_cost')::numeric, order_line.unit_cost)
    );

    update public.purchase_order_items
       set received_quantity = received_quantity + (line ->> 'quantity')::numeric
     where id = order_line.id;

    insert into public.stock_movements (
      branch_id, store_id, inventory_item_id, movement_type,
      quantity_delta, unit_cost, reference_id, notes, actor_id
    )
    values (
      purchase_order.branch_id, store.id, order_line.inventory_item_id,
      'purchase', (line ->> 'quantity')::numeric,
      coalesce((line ->> 'unit_cost')::numeric, order_line.unit_cost),
      receipt.id, 'Goods receipt ' || receipt.receipt_number, auth.uid()
    );

    update public.inventory_items
       set cost_price = coalesce((line ->> 'unit_cost')::numeric, cost_price)
     where id = order_line.inventory_item_id;

    receipt_total := receipt_total +
      (line ->> 'quantity')::numeric *
      coalesce((line ->> 'unit_cost')::numeric, order_line.unit_cost);
  end loop;

  update public.goods_receipts
     set total_cost = receipt_total
   where id = receipt.id;

  select coalesce(sum(quantity), 0), coalesce(sum(received_quantity), 0)
    into ordered_total, received_total
  from public.purchase_order_items
  where purchase_order_id = purchase_order.id;

  update public.purchase_orders
     set status = case
       when received_total >= ordered_total then 'received'
       else 'partially_received'
     end,
         ordered_at = coalesce(ordered_at, current_date)
   where id = purchase_order.id;

  insert into public.audit_logs (
    branch_id, actor_id, action, entity_table, entity_id, details
  )
  values (
    purchase_order.branch_id, auth.uid(), 'purchasing.receive',
    'purchase_orders', purchase_order.id,
    jsonb_build_object(
      'receipt_number', receipt.receipt_number,
      'total_cost', receipt_total
    )
  );

  return jsonb_build_object(
    'receipt_id', receipt.id,
    'receipt_number', receipt.receipt_number,
    'total_cost', receipt_total
  );
end;
$$;

create or replace function public.approve_stock_adjustment(target_adjustment uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  adjustment public.stock_adjustments;
  item_row record;
  created integer := 0;
begin
  select * into adjustment
  from public.stock_adjustments
  where id = target_adjustment
  for update;

  if not found then
    raise exception 'Stock adjustment not found';
  end if;
  if not public.has_permission(adjustment.branch_id, 'inventory.write') then
    raise exception 'Inventory permission required';
  end if;
  if adjustment.status <> 'pending' then
    raise exception 'Only pending adjustments can be approved';
  end if;

  for item_row in
    select * from public.stock_adjustment_items
    where stock_adjustment_id = adjustment.id
  loop
    insert into public.stock_movements (
      branch_id, store_id, inventory_item_id, movement_type,
      quantity_delta, unit_cost, reference_id, notes, actor_id
    )
    values (
      adjustment.branch_id, adjustment.store_id, item_row.inventory_item_id,
      'adjustment', item_row.quantity_delta, item_row.unit_cost,
      adjustment.id, item_row.notes, auth.uid()
    );
    created := created + 1;
  end loop;

  update public.stock_adjustments
     set status = 'approved', approved_by = auth.uid(), approved_at = now()
   where id = adjustment.id;

  insert into public.audit_logs (
    branch_id, actor_id, action, entity_table, entity_id, details
  )
  values (
    adjustment.branch_id, auth.uid(), 'inventory.adjustment.approve',
    'stock_adjustments', adjustment.id,
    jsonb_build_object('reason', adjustment.reason, 'movements', created)
  );

  return jsonb_build_object('adjustment_id', adjustment.id, 'movements', created);
end;
$$;

create or replace function public.complete_stock_transfer(target_transfer uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  transfer public.stock_transfers;
  item_row record;
  created integer := 0;
begin
  select * into transfer
  from public.stock_transfers
  where id = target_transfer
  for update;

  if not found then
    raise exception 'Stock transfer not found';
  end if;
  if not public.has_permission(transfer.branch_id, 'inventory.write') then
    raise exception 'Inventory permission required';
  end if;
  if transfer.status <> 'pending' then
    raise exception 'Only pending transfers can be completed';
  end if;

  for item_row in
    select * from public.stock_transfer_items
    where stock_transfer_id = transfer.id
  loop
    insert into public.stock_movements (
      branch_id, store_id, inventory_item_id, movement_type,
      quantity_delta, unit_cost, reference_id, notes, actor_id
    )
    values (
      transfer.branch_id, transfer.from_store_id, item_row.inventory_item_id,
      'transfer', -item_row.quantity, item_row.unit_cost, transfer.id,
      'Transfer out', auth.uid()
    );

    insert into public.stock_movements (
      branch_id, store_id, inventory_item_id, movement_type,
      quantity_delta, unit_cost, reference_id, notes, actor_id
    )
    values (
      transfer.branch_id, transfer.to_store_id, item_row.inventory_item_id,
      'transfer', item_row.quantity, item_row.unit_cost, transfer.id,
      'Transfer in', auth.uid()
    );

    created := created + 2;
  end loop;

  update public.stock_transfers
     set status = 'completed', completed_by = auth.uid(), completed_at = now()
   where id = transfer.id;

  insert into public.audit_logs (
    branch_id, actor_id, action, entity_table, entity_id, details
  )
  values (
    transfer.branch_id, auth.uid(), 'inventory.transfer.complete',
    'stock_transfers', transfer.id,
    jsonb_build_object('movements', created)
  );

  return jsonb_build_object('transfer_id', transfer.id, 'movements', created);
end;
$$;

create or replace function public.approve_stock_count(target_count uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  stock_count public.stock_counts;
  item_row record;
  variance numeric(14, 3);
  current_quantity numeric(14, 3);
  created integer := 0;
begin
  select * into stock_count
  from public.stock_counts
  where id = target_count
  for update;

  if not found then
    raise exception 'Stock count not found';
  end if;
  if not public.has_permission(stock_count.branch_id, 'inventory.write') then
    raise exception 'Inventory permission required';
  end if;
  if stock_count.status not in ('draft', 'submitted') then
    raise exception 'Stock count is already finalised';
  end if;

  for item_row in
    select * from public.stock_count_items where stock_count_id = stock_count.id
  loop
    select coalesce(on_hand, 0) into current_quantity
    from public.stock_balances
    where branch_id = stock_count.branch_id
      and store_id = stock_count.store_id
      and inventory_item_id = item_row.inventory_item_id;

    current_quantity := coalesce(current_quantity, 0);
    variance := item_row.counted_quantity - current_quantity;

    update public.stock_count_items
       set system_quantity = current_quantity
     where id = item_row.id;

    if variance = 0 then
      continue;
    end if;

    insert into public.stock_movements (
      branch_id, store_id, inventory_item_id, movement_type,
      quantity_delta, unit_cost, reference_id, notes, actor_id
    )
    values (
      stock_count.branch_id, stock_count.store_id,
      item_row.inventory_item_id, 'adjustment', variance, item_row.unit_cost,
      stock_count.id, 'Stock count variance', auth.uid()
    );
    created := created + 1;
  end loop;

  update public.stock_counts
     set status = 'approved', approved_by = auth.uid()
   where id = stock_count.id;

  insert into public.audit_logs (
    branch_id, actor_id, action, entity_table, entity_id, details
  )
  values (
    stock_count.branch_id, auth.uid(), 'inventory.count.approve',
    'stock_counts', stock_count.id,
    jsonb_build_object('movements', created)
  );

  return jsonb_build_object('stock_count_id', stock_count.id, 'movements', created);
end;
$$;

revoke all on function public.receive_purchase_order(uuid, uuid, jsonb)
  from public, anon;
revoke all on function public.approve_stock_adjustment(uuid) from public, anon;
revoke all on function public.complete_stock_transfer(uuid) from public, anon;
revoke all on function public.approve_stock_count(uuid) from public, anon;
grant execute on function public.receive_purchase_order(uuid, uuid, jsonb)
  to authenticated;
grant execute on function public.approve_stock_adjustment(uuid) to authenticated;
grant execute on function public.complete_stock_transfer(uuid) to authenticated;
grant execute on function public.approve_stock_count(uuid) to authenticated;

comment on view public.stock_balances is
  'On-hand quantity by branch, store, and item. Derived from the append-only stock_movements ledger.';
