-- Organization settings, default branch provisioning, granular permissions,
-- document numbering, and write-side row-level security.
--
-- This migration is forward-only. It is safe to apply on a database that has
-- already run the foundation and auth migrations.

-- ---------------------------------------------------------------------------
-- Shared helpers
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_branch_admin(target_branch uuid)
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
    join public.roles role on role.id = membership.role_id
    where membership.branch_id = target_branch
      and membership.user_id = auth.uid()
      and membership.is_active
      and role.slug in ('owner', 'admin')
  );
$$;

create or replace function public.has_permission(
  target_branch uuid,
  required_permission text
)
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
    join public.roles role on role.id = membership.role_id
    where membership.branch_id = target_branch
      and membership.user_id = auth.uid()
      and membership.is_active
      and (
        role.slug in ('owner', 'admin')
        or exists (
          select 1
          from public.role_permissions role_permission
          join public.permissions permission
            on permission.id = role_permission.permission_id
          where role_permission.role_id = role.id
            and permission.permission_key = required_permission
        )
      )
  );
$$;

create or replace function public.shares_branch_with(target_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
set row_security = off
as $$
  select exists (
    select 1
    from public.branch_memberships mine
    join public.branch_memberships theirs
      on theirs.branch_id = mine.branch_id
    where mine.user_id = auth.uid()
      and mine.is_active
      and theirs.user_id = target_user
  );
$$;

revoke all on function public.is_branch_admin(uuid) from public;
revoke all on function public.has_permission(uuid, text) from public;
revoke all on function public.shares_branch_with(uuid) from public;
grant execute on function public.is_branch_admin(uuid) to authenticated;
grant execute on function public.has_permission(uuid, text) to authenticated;
grant execute on function public.shares_branch_with(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------------

insert into public.permissions (permission_key, description)
values
  ('production.read', 'View recipes and production batches'),
  ('production.write', 'Manage recipes and production batches'),
  ('sales.read', 'View sales, receipts, and daily closes'),
  ('sales.write', 'Record sales and take payments'),
  ('sales.void', 'Void sales and process refunds'),
  ('customers.read', 'View customers and receivables'),
  ('customers.write', 'Manage customers, credit, and returns'),
  ('inventory.read', 'View stock, items, and purchasing'),
  ('inventory.write', 'Manage items, stock counts, and adjustments'),
  ('purchasing.read', 'View suppliers and purchase orders'),
  ('purchasing.write', 'Manage suppliers, purchase orders, and goods receipts'),
  ('cash.read', 'View cash accounts, transactions, and expenses'),
  ('cash.write', 'Record cash transactions, expenses, and bills'),
  ('cash.approve', 'Approve expenses, bills, and cash transfers'),
  ('people.read', 'View employees, attendance, and leave'),
  ('people.write', 'Manage employees, attendance, shifts, and leave'),
  ('payroll.read', 'View payroll runs, advances, and payslips'),
  ('payroll.write', 'Run payroll and manage advances'),
  ('rentals.read', 'View properties, leases, and rent invoices'),
  ('rentals.write', 'Manage properties, leases, invoices, and maintenance'),
  ('payables.read', 'View supplier bills, payments, and aging'),
  ('payables.write', 'Manage supplier bills and payments'),
  ('documents.read', 'View private branch documents'),
  ('documents.write', 'Upload and archive private branch documents'),
  ('notifications.read', 'View notifications and manage preferences'),
  ('audit.read', 'View audit history'),
  ('reports.read', 'View dashboards and reports'),
  ('reports.export', 'Export reports and data extracts'),
  ('settings.manage', 'Manage organization, branches, roles, and settings')
on conflict (permission_key) do update
  set description = excluded.description;

-- ---------------------------------------------------------------------------
-- Organization and branch settings
-- ---------------------------------------------------------------------------

create table public.organization_settings (
  id boolean primary key default true check (id),
  legal_name text not null default 'Bread & Cake',
  trade_name text not null default 'Bread & Cake',
  tin text not null default '',
  phone text not null default '',
  email text not null default '',
  address text not null default '',
  default_currency text not null default 'ETB' check (default_currency = 'ETB'),
  timezone text not null default 'Africa/Addis_Ababa',
  default_locale text not null default 'en'
    check (default_locale in ('en', 'am', 'om')),
  default_tax_rate numeric(7, 4) not null default 0.15
    check (default_tax_rate >= 0 and default_tax_rate <= 1),
  fiscal_year_start_month integer not null default 7
    check (fiscal_year_start_month between 1 and 12),
  receipt_footer text not null default 'Thank you for your business.',
  low_stock_alerts boolean not null default true,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles (id) on delete set null
);

insert into public.organization_settings (id)
values (true)
on conflict (id) do nothing;

create table public.branch_settings (
  branch_id uuid primary key references public.branches (id) on delete cascade,
  receipt_prefix text not null default 'RCPT',
  sale_prefix text not null default 'SALE',
  tax_rate numeric(7, 4) not null default 0.15
    check (tax_rate >= 0 and tax_rate <= 1),
  tax_inclusive boolean not null default false,
  service_charge_rate numeric(7, 4) not null default 0
    check (service_charge_rate >= 0 and service_charge_rate <= 1),
  daily_close_required boolean not null default true,
  updated_at timestamptz not null default now()
);

create table public.document_sequences (
  branch_id uuid not null references public.branches (id) on delete cascade,
  document_type text not null,
  prefix text not null,
  next_number bigint not null default 1 check (next_number > 0),
  updated_at timestamptz not null default now(),
  primary key (branch_id, document_type)
);

create or replace function public.next_document_number(
  target_branch uuid,
  target_type text
)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  sequence_row public.document_sequences;
begin
  if not public.user_has_branch_access(target_branch) then
    raise exception 'Branch access denied';
  end if;

  update public.document_sequences
     set next_number = next_number + 1,
         updated_at = now()
   where branch_id = target_branch
     and document_type = target_type
  returning * into sequence_row;

  if not found then
    insert into public.document_sequences (branch_id, document_type, prefix)
    values (target_branch, target_type, upper(left(target_type, 4)))
    on conflict (branch_id, document_type) do update
      set next_number = public.document_sequences.next_number + 1
    returning * into sequence_row;
  end if;

  return sequence_row.prefix || '-' ||
    lpad((sequence_row.next_number - 1)::text, 6, '0');
end;
$$;

revoke all on function public.next_document_number(uuid, text) from public;
grant execute on function public.next_document_number(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Default provisioning for a new branch
-- ---------------------------------------------------------------------------

create or replace function public.provision_branch(target_branch uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  role_row record;
  permission_row record;
  all_permissions text[] := array[
    'production.read', 'production.write',
    'sales.read', 'sales.write', 'sales.void',
    'customers.read', 'customers.write',
    'inventory.read', 'inventory.write',
    'purchasing.read', 'purchasing.write',
    'cash.read', 'cash.write', 'cash.approve',
    'people.read', 'people.write',
    'payroll.read', 'payroll.write',
    'rentals.read', 'rentals.write',
    'payables.read', 'payables.write',
    'documents.read', 'documents.write',
    'notifications.read', 'audit.read',
    'reports.read', 'reports.export',
    'settings.manage'
  ];
  role_matrix jsonb := jsonb_build_object(
    'owner', to_jsonb(all_permissions),
    'manager', to_jsonb(array[
      'production.read', 'production.write', 'sales.read', 'sales.write',
      'sales.void', 'customers.read', 'customers.write', 'inventory.read',
      'inventory.write', 'purchasing.read', 'purchasing.write', 'cash.read',
      'cash.write', 'cash.approve', 'people.read', 'people.write',
      'payroll.read', 'rentals.read', 'rentals.write', 'payables.read',
      'payables.write', 'documents.read', 'documents.write',
      'notifications.read', 'reports.read', 'reports.export'
    ]),
    'cashier', to_jsonb(array[
      'sales.read', 'sales.write', 'customers.read', 'customers.write',
      'inventory.read', 'cash.read', 'notifications.read', 'reports.read'
    ]),
    'storekeeper', to_jsonb(array[
      'production.read', 'inventory.read', 'inventory.write',
      'purchasing.read', 'purchasing.write', 'documents.read',
      'documents.write', 'notifications.read', 'reports.read'
    ]),
    'production', to_jsonb(array[
      'production.read', 'production.write', 'inventory.read',
      'notifications.read', 'reports.read'
    ]),
    'accountant', to_jsonb(array[
      'cash.read', 'cash.write', 'cash.approve', 'payables.read',
      'payables.write', 'customers.read', 'payroll.read', 'reports.read',
      'reports.export', 'audit.read', 'settings.manage'
    ]),
    'hr', to_jsonb(array[
      'people.read', 'people.write', 'payroll.read', 'payroll.write',
      'notifications.read', 'reports.read'
    ])
  );
begin
  insert into public.roles (branch_id, name, slug)
  select target_branch, initcap(key), key
  from jsonb_object_keys(role_matrix) as key
  on conflict (branch_id, slug) do nothing;

  for role_row in
    select id, slug from public.roles where branch_id = target_branch
  loop
    for permission_row in
      select id, permission_key
      from public.permissions
      where permission_key in (
        select jsonb_array_elements_text(role_matrix -> role_row.slug)
      )
    loop
      insert into public.role_permissions (role_id, permission_id)
      values (role_row.id, permission_row.id)
      on conflict do nothing;
    end loop;
  end loop;

  insert into public.branch_settings (branch_id)
  values (target_branch)
  on conflict (branch_id) do nothing;

  insert into public.document_sequences (branch_id, document_type, prefix)
  values
    (target_branch, 'sale', 'SALE'),
    (target_branch, 'receipt', 'RCPT'),
    (target_branch, 'return', 'RET'),
    (target_branch, 'purchase_order', 'PO'),
    (target_branch, 'goods_receipt', 'GRN'),
    (target_branch, 'bill', 'BILL'),
    (target_branch, 'rent_invoice', 'RENT'),
    (target_branch, 'payslip', 'PAY'),
    (target_branch, 'production_batch', 'BATCH')
  on conflict (branch_id, document_type) do nothing;

  insert into public.cash_accounts (branch_id, name, account_type)
  values (target_branch, 'Main Cash', 'cash')
  on conflict (branch_id, name) do nothing;

  insert into public.stores (branch_id, name)
  values (target_branch, 'Main Store')
  on conflict (branch_id, name) do nothing;

  -- The administrator who creates a branch becomes its owner so that a new
  -- branch is immediately usable. Provisioning during migrations has no
  -- authenticated user and therefore assigns nobody.
  if auth.uid() is not null then
    insert into public.branch_memberships (branch_id, user_id, role_id)
    select target_branch, auth.uid(), role.id
    from public.roles role
    where role.branch_id = target_branch and role.slug = 'owner'
    on conflict (branch_id, user_id) do nothing;
  end if;
end;
$$;

revoke all on function public.provision_branch(uuid) from public;
grant execute on function public.provision_branch(uuid) to authenticated;

create or replace function public.handle_new_branch()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.provision_branch(new.id);
  return new;
end;
$$;

create trigger on_branch_created
  after insert on public.branches
  for each row execute function public.handle_new_branch();

drop trigger if exists set_branches_updated_at on public.branches;
create trigger set_branches_updated_at
  before update on public.branches
  for each row execute function public.set_updated_at();

-- Existing databases created before this migration need provisioning applied
-- explicitly by an administrator. The function is idempotent.
do $$
declare
  branch_row record;
begin
  for branch_row in select id from public.branches loop
    perform public.provision_branch(branch_row.id);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Profile and membership administration
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, preferred_locale)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    case
      when new.raw_user_meta_data ->> 'locale' in ('en', 'am', 'om')
        then new.raw_user_meta_data ->> 'locale'
      else 'en'
    end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;

create or replace function public.assign_branch_membership(
  target_branch uuid,
  member_email text,
  role_slug text
)
returns uuid
language plpgsql
security definer
set search_path = public, auth, pg_temp
set row_security = off
as $$
declare
  target_user uuid;
  target_role uuid;
  membership_id uuid;
begin
  if not public.has_permission(target_branch, 'settings.manage') then
    raise exception 'You do not have permission to manage memberships';
  end if;

  select id into target_user
  from auth.users
  where lower(email) = lower(trim(member_email))
  limit 1;

  if target_user is null then
    raise exception 'No account exists for %', member_email;
  end if;

  insert into public.profiles (id)
  values (target_user)
  on conflict (id) do nothing;

  select id into target_role
  from public.roles
  where branch_id = target_branch and slug = role_slug;

  if target_role is null then
    raise exception 'Unknown role % for this branch', role_slug;
  end if;

  insert into public.branch_memberships (branch_id, user_id, role_id)
  values (target_branch, target_user, target_role)
  on conflict (branch_id, user_id) do update
    set role_id = excluded.role_id,
        is_active = true
  returning id into membership_id;

  insert into public.audit_logs (
    branch_id, actor_id, action, entity_table, entity_id, details
  )
  values (
    target_branch, auth.uid(), 'membership.assign', 'branch_memberships',
    membership_id, jsonb_build_object('email', member_email, 'role', role_slug)
  );

  return membership_id;
end;
$$;

revoke all on function public.assign_branch_membership(uuid, text, text)
  from public, anon;
grant execute on function public.assign_branch_membership(uuid, text, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Write policies for existing foundation tables
-- ---------------------------------------------------------------------------

-- Branch creation is a platform-owner operation. The first organization owner
-- is provisioned through the Supabase dashboard; subsequent branch creation is
-- limited to users who administer at least one existing branch.
create policy "Organization administrators can create branches"
  on public.branches for insert to authenticated
  with check (
    exists (
      select 1
      from public.branch_memberships membership
      join public.roles role on role.id = membership.role_id
      where membership.user_id = auth.uid()
        and membership.is_active
        and role.slug in ('owner', 'admin')
    )
  );
create policy "Branch administrators can update branches"
  on public.branches for update to authenticated
  using (public.is_branch_admin(id))
  with check (public.is_branch_admin(id));
create policy "Branch administrators can delete branches"
  on public.branches for delete to authenticated
  using (public.is_branch_admin(id));

drop policy "Profiles are readable by their owner" on public.profiles;
create policy "Profiles are readable by their owner"
  on public.profiles for select to authenticated
  using (id = auth.uid() or public.shares_branch_with(id));
create policy "Administrators can update branch profiles"
  on public.profiles for update to authenticated
  using (
    id = auth.uid()
    or exists (
      select 1 from public.branch_memberships membership
      where membership.user_id = profiles.id
        and membership.is_active
        and public.has_permission(membership.branch_id, 'settings.manage')
    )
  )
  with check (
    id = auth.uid()
    or exists (
      select 1 from public.branch_memberships membership
      where membership.user_id = profiles.id
        and membership.is_active
        and public.has_permission(membership.branch_id, 'settings.manage')
    )
  );

create policy "Settings managers can write roles"
  on public.roles for insert to authenticated
  with check (
    branch_id is not null and public.has_permission(branch_id, 'settings.manage')
  );
create policy "Settings managers can update roles"
  on public.roles for update to authenticated
  using (branch_id is not null and public.has_permission(branch_id, 'settings.manage'))
  with check (branch_id is not null and public.has_permission(branch_id, 'settings.manage'));
create policy "Settings managers can delete roles"
  on public.roles for delete to authenticated
  using (branch_id is not null and public.has_permission(branch_id, 'settings.manage'));

create policy "Settings managers can grant permissions"
  on public.role_permissions for insert to authenticated
  with check (
    exists (
      select 1 from public.roles role
      where role.id = role_id
        and role.branch_id is not null
        and public.has_permission(role.branch_id, 'settings.manage')
    )
  );
create policy "Settings managers can revoke permissions"
  on public.role_permissions for delete to authenticated
  using (
    exists (
      select 1 from public.roles role
      where role.id = role_id
        and role.branch_id is not null
        and public.has_permission(role.branch_id, 'settings.manage')
    )
  );

create policy "Settings managers can add memberships"
  on public.branch_memberships for insert to authenticated
  with check (public.has_permission(branch_id, 'settings.manage'));
create policy "Settings managers can update memberships"
  on public.branch_memberships for update to authenticated
  using (public.has_permission(branch_id, 'settings.manage'))
  with check (public.has_permission(branch_id, 'settings.manage'));
create policy "Settings managers can remove memberships"
  on public.branch_memberships for delete to authenticated
  using (public.has_permission(branch_id, 'settings.manage'));

create policy "Inventory staff can write categories"
  on public.categories for insert to authenticated
  with check (public.has_permission(branch_id, 'inventory.write'));
create policy "Inventory staff can update categories"
  on public.categories for update to authenticated
  using (public.has_permission(branch_id, 'inventory.write'))
  with check (public.has_permission(branch_id, 'inventory.write'));
create policy "Inventory staff can delete categories"
  on public.categories for delete to authenticated
  using (public.has_permission(branch_id, 'inventory.write'));

create policy "Production staff can write products"
  on public.products for insert to authenticated
  with check (public.has_permission(branch_id, 'production.write'));
create policy "Production staff can update products"
  on public.products for update to authenticated
  using (public.has_permission(branch_id, 'production.write'))
  with check (public.has_permission(branch_id, 'production.write'));
create policy "Production staff can delete products"
  on public.products for delete to authenticated
  using (public.has_permission(branch_id, 'production.write'));

create policy "Inventory staff can write stores"
  on public.stores for insert to authenticated
  with check (public.has_permission(branch_id, 'inventory.write'));
create policy "Inventory staff can update stores"
  on public.stores for update to authenticated
  using (public.has_permission(branch_id, 'inventory.write'))
  with check (public.has_permission(branch_id, 'inventory.write'));
create policy "Inventory staff can delete stores"
  on public.stores for delete to authenticated
  using (public.has_permission(branch_id, 'inventory.write'));

create policy "Inventory staff can write items"
  on public.inventory_items for insert to authenticated
  with check (public.has_permission(branch_id, 'inventory.write'));
create policy "Inventory staff can update items"
  on public.inventory_items for update to authenticated
  using (public.has_permission(branch_id, 'inventory.write'))
  with check (public.has_permission(branch_id, 'inventory.write'));
create policy "Inventory staff can delete items"
  on public.inventory_items for delete to authenticated
  using (public.has_permission(branch_id, 'inventory.write'));

create policy "Inventory staff can append stock movements"
  on public.stock_movements for insert to authenticated
  with check (
    public.has_permission(branch_id, 'inventory.write')
    and actor_id = auth.uid()
  );

create policy "Sales staff can write customers"
  on public.customers for insert to authenticated
  with check (public.has_permission(branch_id, 'customers.write'));
create policy "Sales staff can update customers"
  on public.customers for update to authenticated
  using (public.has_permission(branch_id, 'customers.write'))
  with check (public.has_permission(branch_id, 'customers.write'));
create policy "Sales staff can delete customers"
  on public.customers for delete to authenticated
  using (public.has_permission(branch_id, 'customers.write'));

create policy "Sales staff can record sales"
  on public.sales for insert to authenticated
  with check (
    public.has_permission(branch_id, 'sales.write') and cashier_id = auth.uid()
  );
-- Sales are never updated directly by clients: voiding is performed by the
-- void_sale function, which restores stock, cash, and credit atomically.

create policy "Sales staff can add sale items"
  on public.sale_items for insert to authenticated
  with check (
    exists (
      select 1 from public.sales sale
      where sale.id = sale_id
        and public.has_permission(sale.branch_id, 'sales.write')
    )
  );
create policy "Sales staff can take payments"
  on public.payments for insert to authenticated
  with check (
    exists (
      select 1 from public.sales sale
      where sale.id = sale_id
        and public.has_permission(sale.branch_id, 'sales.write')
    )
  );

create policy "Cash staff can write accounts"
  on public.cash_accounts for insert to authenticated
  with check (public.has_permission(branch_id, 'cash.write'));
create policy "Cash staff can update accounts"
  on public.cash_accounts for update to authenticated
  using (public.has_permission(branch_id, 'cash.write'))
  with check (public.has_permission(branch_id, 'cash.write'));
create policy "Cash staff can delete accounts"
  on public.cash_accounts for delete to authenticated
  using (public.has_permission(branch_id, 'cash.write'));

create policy "Cash staff can append transactions"
  on public.cash_transactions for insert to authenticated
  with check (
    public.has_permission(branch_id, 'cash.write') and actor_id = auth.uid()
  );

drop policy "Members can read branch audit history" on public.audit_logs;
create policy "Auditors can read branch audit history"
  on public.audit_logs for select to authenticated
  using (
    branch_id is not null and public.has_permission(branch_id, 'audit.read')
  );

alter table public.organization_settings enable row level security;
create policy "Authenticated users can read organization settings"
  on public.organization_settings for select to authenticated using (true);
create policy "Settings managers can update organization settings"
  on public.organization_settings for update to authenticated
  using (
    exists (
      select 1 from public.branch_memberships membership
      join public.roles role on role.id = membership.role_id
      where membership.user_id = auth.uid()
        and membership.is_active
        and role.slug in ('owner', 'admin')
    )
  )
  with check (
    exists (
      select 1 from public.branch_memberships membership
      join public.roles role on role.id = membership.role_id
      where membership.user_id = auth.uid()
        and membership.is_active
        and role.slug in ('owner', 'admin')
    )
  );

alter table public.branch_settings enable row level security;
create policy "Members can read branch settings"
  on public.branch_settings for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Settings managers can write branch settings"
  on public.branch_settings for insert to authenticated
  with check (public.has_permission(branch_id, 'settings.manage'));
create policy "Settings managers can update branch settings"
  on public.branch_settings for update to authenticated
  using (public.has_permission(branch_id, 'settings.manage'))
  with check (public.has_permission(branch_id, 'settings.manage'));

alter table public.document_sequences enable row level security;
create policy "Members can read document sequences"
  on public.document_sequences for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Settings managers can manage document sequences"
  on public.document_sequences for insert to authenticated
  with check (public.has_permission(branch_id, 'settings.manage'));
create policy "Settings managers can update document sequences"
  on public.document_sequences for update to authenticated
  using (public.has_permission(branch_id, 'settings.manage'))
  with check (public.has_permission(branch_id, 'settings.manage'));

-- Actor columns default to the calling user, which keeps append-only tables
-- honest even if a client forgets to include the actor.
alter table public.stock_movements
  alter column actor_id set default auth.uid();
alter table public.sales
  alter column cashier_id set default auth.uid();
alter table public.cash_transactions
  alter column actor_id set default auth.uid();

comment on function public.has_permission(uuid, text) is
  'Returns true when the current user holds the permission in the branch. Owners and admins implicitly hold every permission.';
comment on table public.document_sequences is
  'Monotonic per-branch counters used for human-readable document numbers.';
