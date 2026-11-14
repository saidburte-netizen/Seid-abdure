-- Products, recipes, and production batches.
-- Batch completion writes compensating stock consumption entries into the
-- append-only ledger and is idempotent.

alter table public.products
  add column if not exists cost_price numeric(14, 2) not null default 0
    check (cost_price >= 0),
  add column if not exists inventory_item_id uuid
    references public.inventory_items (id) on delete set null,
  add column if not exists image_path text,
  add column if not exists barcode text;

create unique index if not exists products_branch_barcode_idx
  on public.products (branch_id, barcode) where barcode is not null;

create table public.recipes (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  name text not null,
  yield_quantity numeric(14, 3) not null default 1 check (yield_quantity > 0),
  yield_unit text not null default 'piece',
  instructions text not null default '',
  is_active boolean not null default true,
  created_by uuid default auth.uid() references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (branch_id, product_id, name)
);

create table public.recipe_items (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references public.recipes (id) on delete cascade,
  inventory_item_id uuid not null references public.inventory_items (id),
  quantity numeric(14, 3) not null check (quantity > 0),
  unit text not null default 'unit',
  waste_percent numeric(5, 2) not null default 0
    check (waste_percent >= 0 and waste_percent <= 100),
  unique (recipe_id, inventory_item_id)
);

create table public.production_batches (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  recipe_id uuid not null references public.recipes (id),
  batch_number text not null,
  planned_quantity numeric(14, 3) not null check (planned_quantity > 0),
  produced_quantity numeric(14, 3) not null default 0
    check (produced_quantity >= 0),
  status text not null default 'planned'
    check (status in ('planned', 'in_progress', 'completed', 'cancelled')),
  scheduled_for date not null default current_date,
  started_at timestamptz,
  completed_at timestamptz,
  notes text not null default '',
  created_by uuid not null default auth.uid()
    references public.profiles (id),
  completed_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (branch_id, batch_number)
);

create table public.production_batch_consumptions (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.production_batches (id) on delete cascade,
  inventory_item_id uuid not null references public.inventory_items (id),
  store_id uuid references public.stores (id),
  quantity numeric(14, 3) not null check (quantity > 0),
  unit_cost numeric(14, 2) check (unit_cost is null or unit_cost >= 0),
  stock_movement_id uuid references public.stock_movements (id),
  created_at timestamptz not null default now()
);

create index recipes_branch_product_idx
  on public.recipes (branch_id, product_id) where is_active;
create index production_batches_branch_date_idx
  on public.production_batches (branch_id, scheduled_for desc);
create index production_consumptions_batch_idx
  on public.production_batch_consumptions (batch_id);

create trigger set_recipes_updated_at
  before update on public.recipes
  for each row execute function public.set_updated_at();
create trigger set_production_batches_updated_at
  before update on public.production_batches
  for each row execute function public.set_updated_at();

alter table public.recipes enable row level security;
alter table public.recipe_items enable row level security;
alter table public.production_batches enable row level security;
alter table public.production_batch_consumptions enable row level security;

create policy "Production staff can read recipes"
  on public.recipes for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Production staff can write recipes"
  on public.recipes for insert to authenticated
  with check (public.has_permission(branch_id, 'production.write'));
create policy "Production staff can update recipes"
  on public.recipes for update to authenticated
  using (public.has_permission(branch_id, 'production.write'))
  with check (public.has_permission(branch_id, 'production.write'));
create policy "Production staff can delete recipes"
  on public.recipes for delete to authenticated
  using (public.has_permission(branch_id, 'production.write'));

create policy "Production staff can read recipe items"
  on public.recipe_items for select to authenticated
  using (
    exists (
      select 1 from public.recipes recipe
      where recipe.id = recipe_id
        and public.user_has_branch_access(recipe.branch_id)
    )
  );
create policy "Production staff can write recipe items"
  on public.recipe_items for insert to authenticated
  with check (
    exists (
      select 1 from public.recipes recipe
      where recipe.id = recipe_id
        and public.has_permission(recipe.branch_id, 'production.write')
    )
  );
create policy "Production staff can update recipe items"
  on public.recipe_items for update to authenticated
  using (
    exists (
      select 1 from public.recipes recipe
      where recipe.id = recipe_id
        and public.has_permission(recipe.branch_id, 'production.write')
    )
  )
  with check (
    exists (
      select 1 from public.recipes recipe
      where recipe.id = recipe_id
        and public.has_permission(recipe.branch_id, 'production.write')
    )
  );
create policy "Production staff can delete recipe items"
  on public.recipe_items for delete to authenticated
  using (
    exists (
      select 1 from public.recipes recipe
      where recipe.id = recipe_id
        and public.has_permission(recipe.branch_id, 'production.write')
    )
  );

create policy "Production staff can read batches"
  on public.production_batches for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Production staff can create batches"
  on public.production_batches for insert to authenticated
  with check (
    public.has_permission(branch_id, 'production.write')
    and created_by = auth.uid()
  );
create policy "Production staff can update batches"
  on public.production_batches for update to authenticated
  using (public.has_permission(branch_id, 'production.write'))
  with check (public.has_permission(branch_id, 'production.write'));

create policy "Production staff can read consumptions"
  on public.production_batch_consumptions for select to authenticated
  using (
    exists (
      select 1 from public.production_batches batch
      where batch.id = batch_id
        and public.user_has_branch_access(batch.branch_id)
    )
  );

create or replace function public.complete_production_batch(
  target_batch uuid,
  actual_quantity numeric,
  target_store uuid default null,
  consumption_cost numeric default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  batch public.production_batches;
  store public.stores;
  recipe_row public.recipes;
  item_row record;
  consumption_quantity numeric(14, 3);
  movement public.stock_movements;
  created_consumptions integer := 0;
begin
  select * into batch
  from public.production_batches
  where id = target_batch
  for update;

  if not found then
    raise exception 'Production batch not found';
  end if;
  if not public.has_permission(batch.branch_id, 'production.write') then
    raise exception 'Production permission required';
  end if;
  if batch.status = 'completed' then
    raise exception 'Batch is already completed';
  end if;
  if batch.status = 'cancelled' then
    raise exception 'Cancelled batches cannot be completed';
  end if;
  if actual_quantity is null or actual_quantity <= 0 then
    raise exception 'Produced quantity must be positive';
  end if;

  select * into recipe_row from public.recipes where id = batch.recipe_id;

  select * into store from public.stores
  where branch_id = batch.branch_id
    and (target_store is null or id = target_store)
  order by (id = target_store) desc, created_at
  limit 1;

  if not found then
    raise exception 'A store is required to complete a batch';
  end if;

  for item_row in
    select
      recipe_item.inventory_item_id,
      recipe_item.quantity,
      recipe_item.waste_percent,
      item.cost_price
    from public.recipe_items recipe_item
    join public.inventory_items item
      on item.id = recipe_item.inventory_item_id
    where recipe_item.recipe_id = batch.recipe_id
  loop
    consumption_quantity := round(
      item_row.quantity * actual_quantity / recipe_row.yield_quantity *
      (1 + item_row.waste_percent / 100),
      3
    );

    if consumption_quantity <= 0 then
      continue;
    end if;

    insert into public.stock_movements (
      branch_id, store_id, inventory_item_id, movement_type,
      quantity_delta, unit_cost, reference_id, notes, actor_id
    )
    values (
      batch.branch_id, store.id, item_row.inventory_item_id, 'production',
      -consumption_quantity,
      coalesce(consumption_cost, item_row.cost_price),
      batch.id,
      'Consumed by production batch ' || batch.batch_number,
      auth.uid()
    )
    returning * into movement;

    insert into public.production_batch_consumptions (
      batch_id, inventory_item_id, store_id, quantity, unit_cost,
      stock_movement_id
    )
    values (
      batch.id, item_row.inventory_item_id, store.id,
      consumption_quantity, coalesce(consumption_cost, item_row.cost_price),
      movement.id
    );

    created_consumptions := created_consumptions + 1;
  end loop;

  update public.production_batches
     set produced_quantity = actual_quantity,
         status = 'completed',
         completed_at = now(),
         completed_by = auth.uid()
   where id = batch.id;

  insert into public.audit_logs (
    branch_id, actor_id, action, entity_table, entity_id, details
  )
  values (
    batch.branch_id, auth.uid(), 'production.complete',
    'production_batches', batch.id,
    jsonb_build_object(
      'batch_number', batch.batch_number,
      'produced_quantity', actual_quantity,
      'consumptions', created_consumptions
    )
  );

  return jsonb_build_object(
    'batch_id', batch.id,
    'produced_quantity', actual_quantity,
    'consumptions', created_consumptions
  );
end;
$$;

revoke all on function public.complete_production_batch(uuid, numeric, uuid, numeric)
  from public, anon;
grant execute on function public.complete_production_batch(uuid, numeric, uuid, numeric)
  to authenticated;

comment on table public.production_batch_consumptions is
  'Actual ingredient usage recorded when a batch is completed; linked to stock_movements for traceability.';
