-- Initial branch-scoped foundation for identity, catalog, stock ledger, sales,
-- cash, and audit history. Rollback: drop dependent objects in reverse order;
-- this migration is intentionally forward-only for environments with data.

create extension if not exists pgcrypto with schema extensions;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  preferred_locale text not null default 'en'
    check (preferred_locale in ('en', 'am', 'om')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.branches (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.roles (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.branches (id) on delete cascade,
  name text not null,
  slug text not null,
  created_at timestamptz not null default now(),
  unique nulls not distinct (branch_id, slug)
);

create table public.permissions (
  id uuid primary key default gen_random_uuid(),
  permission_key text not null unique,
  description text not null default ''
);

create table public.role_permissions (
  role_id uuid not null references public.roles (id) on delete cascade,
  permission_id uuid not null references public.permissions (id) on delete cascade,
  primary key (role_id, permission_id)
);

create table public.branch_memberships (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role_id uuid not null references public.roles (id),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (branch_id, user_id)
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  name text not null,
  kind text not null check (kind in ('product', 'inventory')),
  created_at timestamptz not null default now(),
  unique (branch_id, kind, name)
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  category_id uuid references public.categories (id),
  name text not null,
  sku text,
  unit text not null default 'piece',
  selling_price numeric(14, 2) not null default 0 check (selling_price >= 0),
  tax_rate numeric(7, 4) not null default 0 check (tax_rate >= 0 and tax_rate <= 1),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (branch_id, sku)
);

create table public.stores (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  unique (branch_id, name)
);

create table public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  category_id uuid references public.categories (id),
  name text not null,
  sku text,
  unit text not null,
  minimum_quantity numeric(14, 3) not null default 0 check (minimum_quantity >= 0),
  created_at timestamptz not null default now(),
  unique (branch_id, sku)
);

create table public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  store_id uuid not null references public.stores (id),
  inventory_item_id uuid not null references public.inventory_items (id),
  movement_type text not null check (
    movement_type in ('purchase', 'production', 'sale', 'damage', 'adjustment', 'transfer')
  ),
  quantity_delta numeric(14, 3) not null check (quantity_delta <> 0),
  unit_cost numeric(14, 2) check (unit_cost is null or unit_cost >= 0),
  reference_id uuid,
  notes text not null default '',
  actor_id uuid not null references public.profiles (id),
  created_at timestamptz not null default now()
);

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  name text not null,
  phone text,
  created_at timestamptz not null default now()
);

create table public.sales (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  customer_id uuid references public.customers (id),
  cashier_id uuid not null references public.profiles (id),
  status text not null default 'completed'
    check (status in ('draft', 'completed', 'voided', 'refunded')),
  subtotal numeric(14, 2) not null check (subtotal >= 0),
  discount numeric(14, 2) not null default 0 check (discount >= 0),
  tax_total numeric(14, 2) not null default 0 check (tax_total >= 0),
  grand_total numeric(14, 2) not null check (grand_total >= 0),
  created_at timestamptz not null default now()
);

create table public.sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales (id) on delete cascade,
  product_id uuid not null references public.products (id),
  quantity numeric(14, 3) not null check (quantity > 0),
  unit_price numeric(14, 2) not null check (unit_price >= 0),
  line_total numeric(14, 2) not null check (line_total >= 0)
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales (id) on delete cascade,
  method text not null check (
    method in ('cash', 'telebirr', 'cbe_birr', 'bank', 'credit', 'other')
  ),
  amount numeric(14, 2) not null check (amount > 0),
  reference text,
  created_at timestamptz not null default now()
);

create table public.cash_accounts (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  name text not null,
  account_type text not null check (account_type in ('cash', 'bank', 'mobile_money')),
  currency text not null default 'ETB' check (currency = 'ETB'),
  created_at timestamptz not null default now(),
  unique (branch_id, name)
);

create table public.cash_transactions (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  cash_account_id uuid not null references public.cash_accounts (id),
  direction text not null check (direction in ('in', 'out')),
  category text not null,
  amount numeric(14, 2) not null check (amount > 0),
  method text not null,
  reference_id uuid,
  notes text not null default '',
  actor_id uuid not null references public.profiles (id),
  created_at timestamptz not null default now()
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.branches (id) on delete set null,
  actor_id uuid references public.profiles (id) on delete set null,
  action text not null,
  entity_table text not null,
  entity_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index branch_memberships_user_branch_idx
  on public.branch_memberships (user_id, branch_id) where is_active;
create index stock_movements_branch_item_created_idx
  on public.stock_movements (branch_id, inventory_item_id, created_at desc);
create index sales_branch_created_idx on public.sales (branch_id, created_at desc);
create index cash_transactions_branch_created_idx
  on public.cash_transactions (branch_id, created_at desc);

create or replace function public.user_has_branch_access(target_branch uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
set row_security = off
as $$
  select exists (
    select 1
    from public.branch_memberships membership
    where membership.branch_id = target_branch
      and membership.user_id = auth.uid()
      and membership.is_active
  );
$$;

revoke all on function public.user_has_branch_access(uuid) from public;
grant execute on function public.user_has_branch_access(uuid) to authenticated;

create view public.stock_balances
with (security_invoker = true)
as
select
  branch_id,
  store_id,
  inventory_item_id,
  sum(quantity_delta) as on_hand
from public.stock_movements
group by branch_id, store_id, inventory_item_id;

alter table public.profiles enable row level security;
alter table public.branches enable row level security;
alter table public.roles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.branch_memberships enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.stores enable row level security;
alter table public.inventory_items enable row level security;
alter table public.stock_movements enable row level security;
alter table public.customers enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.payments enable row level security;
alter table public.cash_accounts enable row level security;
alter table public.cash_transactions enable row level security;
alter table public.audit_logs enable row level security;

create policy "Profiles are readable by their owner"
  on public.profiles for select to authenticated using (id = auth.uid());
create policy "Profiles are editable by their owner"
  on public.profiles for update to authenticated using (id = auth.uid())
  with check (id = auth.uid());

create policy "Members can read their branches"
  on public.branches for select to authenticated
  using (public.user_has_branch_access(id));

create policy "Authenticated users can read role catalog"
  on public.roles for select to authenticated using (true);
create policy "Authenticated users can read permission catalog"
  on public.permissions for select to authenticated using (true);
create policy "Authenticated users can read role permissions"
  on public.role_permissions for select to authenticated using (true);

create policy "Members can read memberships in their branches"
  on public.branch_memberships for select to authenticated
  using (user_id = auth.uid() or public.user_has_branch_access(branch_id));

create policy "Members can read branch categories"
  on public.categories for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Members can read branch products"
  on public.products for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Members can read branch stores"
  on public.stores for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Members can read branch inventory items"
  on public.inventory_items for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Members can read stock movements"
  on public.stock_movements for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Members can read branch customers"
  on public.customers for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Members can read branch sales"
  on public.sales for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Members can read sale items"
  on public.sale_items for select to authenticated
  using (exists (
    select 1 from public.sales sale
    where sale.id = sale_id and public.user_has_branch_access(sale.branch_id)
  ));
create policy "Members can read payments"
  on public.payments for select to authenticated
  using (exists (
    select 1 from public.sales sale
    where sale.id = sale_id and public.user_has_branch_access(sale.branch_id)
  ));
create policy "Members can read branch cash accounts"
  on public.cash_accounts for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Members can read branch cash transactions"
  on public.cash_transactions for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Members can read branch audit history"
  on public.audit_logs for select to authenticated
  using (branch_id is not null and public.user_has_branch_access(branch_id));

comment on table public.stock_movements is
  'Append-only quantity ledger; application workflows must write compensating movements instead of editing history.';
