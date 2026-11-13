-- Properties, units, leases, rent invoicing, rent collection, and maintenance.

create table public.properties (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  name text not null,
  address text not null default '',
  property_type text not null default 'commercial'
    check (property_type in ('commercial', 'residential', 'warehouse', 'land')),
  notes text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (branch_id, name)
);

create table public.units (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  property_id uuid not null references public.properties (id) on delete cascade,
  name text not null,
  bedrooms integer not null default 0 check (bedrooms >= 0),
  size_sqm numeric(10, 2) check (size_sqm is null or size_sqm >= 0),
  rent_amount numeric(14, 2) not null default 0 check (rent_amount >= 0),
  status text not null default 'vacant'
    check (status in ('vacant', 'occupied', 'maintenance', 'inactive')),
  notes text not null default '',
  created_at timestamptz not null default now(),
  unique (property_id, name)
);

create table public.leases (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  unit_id uuid not null references public.units (id),
  tenant_name text not null,
  tenant_phone text,
  tenant_email text,
  start_date date not null,
  end_date date not null,
  rent_amount numeric(14, 2) not null check (rent_amount > 0),
  deposit_amount numeric(14, 2) not null default 0 check (deposit_amount >= 0),
  payment_day integer not null default 1 check (payment_day between 1 and 28),
  status text not null default 'active'
    check (status in ('draft', 'active', 'ended', 'terminated')),
  notes text not null default '',
  created_by uuid not null default auth.uid() references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date > start_date)
);

create table public.rent_invoices (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  lease_id uuid not null references public.leases (id),
  invoice_number text not null,
  period_start date not null,
  period_end date not null,
  amount numeric(14, 2) not null check (amount > 0),
  paid_amount numeric(14, 2) not null default 0
    check (paid_amount >= 0 and paid_amount <= amount),
  due_date date not null,
  status text not null default 'unpaid'
    check (status in ('unpaid', 'partial', 'paid', 'void')),
  notes text not null default '',
  created_at timestamptz not null default now(),
  unique (branch_id, invoice_number),
  unique (lease_id, period_start),
  check (period_end >= period_start)
);

create table public.rent_payments (
  id uuid primary key default gen_random_uuid(),
  rent_invoice_id uuid not null references public.rent_invoices (id) on delete cascade,
  cash_account_id uuid not null references public.cash_accounts (id),
  amount numeric(14, 2) not null check (amount > 0),
  method text not null default 'cash'
    check (method in ('cash', 'telebirr', 'cbe_birr', 'bank', 'other')),
  reference text not null default '',
  paid_at timestamptz not null default now(),
  received_by uuid not null default auth.uid() references public.profiles (id)
);

create table public.maintenance_requests (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  property_id uuid not null references public.properties (id) on delete cascade,
  unit_id uuid references public.units (id) on delete set null,
  title text not null,
  description text not null default '',
  priority text not null default 'normal'
    check (priority in ('low', 'normal', 'high', 'urgent')),
  status text not null default 'open'
    check (status in ('open', 'in_progress', 'resolved', 'cancelled')),
  reported_by uuid not null default auth.uid() references public.profiles (id),
  assigned_to text,
  cost numeric(14, 2) not null default 0 check (cost >= 0),
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index properties_branch_idx on public.properties (branch_id) where is_active;
create index units_property_status_idx on public.units (property_id, status);
create index leases_branch_status_idx on public.leases (branch_id, status, end_date);
create index rent_invoices_branch_status_idx
  on public.rent_invoices (branch_id, status, due_date);
create index rent_payments_invoice_idx on public.rent_payments (rent_invoice_id);
create index maintenance_branch_status_idx
  on public.maintenance_requests (branch_id, status, priority);

create trigger set_properties_updated_at
  before update on public.properties
  for each row execute function public.set_updated_at();
create trigger set_leases_updated_at
  before update on public.leases
  for each row execute function public.set_updated_at();
create trigger set_maintenance_updated_at
  before update on public.maintenance_requests
  for each row execute function public.set_updated_at();

alter table public.properties enable row level security;
alter table public.units enable row level security;
alter table public.leases enable row level security;
alter table public.rent_invoices enable row level security;
alter table public.rent_payments enable row level security;
alter table public.maintenance_requests enable row level security;

create policy "Rental staff can read properties"
  on public.properties for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Rental staff can write properties"
  on public.properties for insert to authenticated
  with check (public.has_permission(branch_id, 'rentals.write'));
create policy "Rental staff can update properties"
  on public.properties for update to authenticated
  using (public.has_permission(branch_id, 'rentals.write'))
  with check (public.has_permission(branch_id, 'rentals.write'));
create policy "Rental staff can delete properties"
  on public.properties for delete to authenticated
  using (public.has_permission(branch_id, 'rentals.write'));

create policy "Rental staff can read units"
  on public.units for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Rental staff can write units"
  on public.units for insert to authenticated
  with check (public.has_permission(branch_id, 'rentals.write'));
create policy "Rental staff can update units"
  on public.units for update to authenticated
  using (public.has_permission(branch_id, 'rentals.write'))
  with check (public.has_permission(branch_id, 'rentals.write'));
create policy "Rental staff can delete units"
  on public.units for delete to authenticated
  using (public.has_permission(branch_id, 'rentals.write'));

create policy "Rental staff can read leases"
  on public.leases for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Rental staff can write leases"
  on public.leases for insert to authenticated
  with check (public.has_permission(branch_id, 'rentals.write'));
create policy "Rental staff can update leases"
  on public.leases for update to authenticated
  using (public.has_permission(branch_id, 'rentals.write'))
  with check (public.has_permission(branch_id, 'rentals.write'));

create policy "Rental staff can read rent invoices"
  on public.rent_invoices for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Rental staff can read rent payments"
  on public.rent_payments for select to authenticated
  using (
    exists (
      select 1 from public.rent_invoices invoice
      where invoice.id = rent_invoice_id
        and public.user_has_branch_access(invoice.branch_id)
    )
  );

create policy "Rental staff can read maintenance"
  on public.maintenance_requests for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Rental staff can write maintenance"
  on public.maintenance_requests for insert to authenticated
  with check (public.has_permission(branch_id, 'rentals.write'));
create policy "Rental staff can update maintenance"
  on public.maintenance_requests for update to authenticated
  using (public.has_permission(branch_id, 'rentals.write'))
  with check (public.has_permission(branch_id, 'rentals.write'));

create or replace view public.rent_roll
with (security_invoker = true)
as
select
  lease.branch_id,
  property.name as property_name,
  unit.name as unit_name,
  lease.id as lease_id,
  lease.tenant_name,
  lease.tenant_phone,
  lease.start_date,
  lease.end_date,
  lease.rent_amount,
  lease.status,
  coalesce(sum(invoice.amount), 0) as invoiced_total,
  coalesce(sum(invoice.paid_amount), 0) as collected_total,
  coalesce(sum(invoice.amount - invoice.paid_amount)
    filter (where invoice.status in ('unpaid', 'partial')), 0) as outstanding
from public.leases lease
join public.units unit on unit.id = lease.unit_id
join public.properties property on property.id = unit.property_id
left join public.rent_invoices invoice on invoice.lease_id = lease.id
group by
  lease.branch_id, property.name, unit.name, lease.id, lease.tenant_name,
  lease.tenant_phone, lease.start_date, lease.end_date, lease.rent_amount,
  lease.status;

create or replace function public.generate_rent_invoices(
  target_branch uuid,
  target_period_start date
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  lease_row record;
  period_end date;
  invoice_count integer := 0;
  invoice_id uuid;
begin
  if not public.has_permission(target_branch, 'rentals.write') then
    raise exception 'Rentals permission required';
  end if;

  target_period_start := date_trunc('month', target_period_start)::date;
  period_end := (target_period_start + interval '1 month - 1 day')::date;

  for lease_row in
    select * from public.leases
    where branch_id = target_branch
      and status = 'active'
      and start_date <= period_end
      and end_date >= target_period_start
  loop
    insert into public.rent_invoices (
      branch_id, lease_id, invoice_number, period_start, period_end,
      amount, due_date
    )
    values (
      target_branch, lease_row.id,
      public.next_document_number(target_branch, 'rent_invoice'),
      target_period_start, period_end, lease_row.rent_amount,
      make_date(
        extract(year from target_period_start)::int,
        extract(month from target_period_start)::int,
        lease_row.payment_day
      )
    )
    on conflict (lease_id, period_start) do nothing
    returning id into invoice_id;

    if invoice_id is not null then
      invoice_count := invoice_count + 1;
    end if;
  end loop;

  insert into public.audit_logs (
    branch_id, actor_id, action, entity_table, details
  )
  values (
    target_branch, auth.uid(), 'rentals.invoices.generate', 'rent_invoices',
    jsonb_build_object('period_start', target_period_start, 'invoices', invoice_count)
  );

  return jsonb_build_object(
    'period_start', target_period_start,
    'period_end', period_end,
    'invoices_created', invoice_count
  );
end;
$$;

create or replace function public.record_rent_payment(
  target_invoice uuid,
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
  invoice public.rent_invoices;
  account public.cash_accounts;
  new_paid numeric(14, 2);
  new_status text;
  payment_id uuid;
begin
  select * into invoice
  from public.rent_invoices where id = target_invoice for update;
  if not found then
    raise exception 'Rent invoice not found';
  end if;
  if not public.has_permission(invoice.branch_id, 'rentals.write') then
    raise exception 'Rentals permission required';
  end if;
  if invoice.status in ('paid', 'void') then
    raise exception 'Invoice is already %', invoice.status;
  end if;
  if payment_amount is null or payment_amount <= 0 then
    raise exception 'Payment must be positive';
  end if;
  if invoice.paid_amount + payment_amount > invoice.amount then
    raise exception 'Payment exceeds the outstanding rent';
  end if;

  select * into account
  from public.cash_accounts
  where id = target_account and branch_id = invoice.branch_id;
  if not found then
    raise exception 'Cash account does not belong to this branch';
  end if;

  insert into public.rent_payments (
    rent_invoice_id, cash_account_id, amount, method, reference, received_by
  )
  values (
    invoice.id, account.id, payment_amount, payment_method,
    coalesce(payment_reference, ''), auth.uid()
  )
  returning id into payment_id;

  new_paid := invoice.paid_amount + payment_amount;
  new_status := case when new_paid >= invoice.amount then 'paid' else 'partial' end;

  update public.rent_invoices
     set paid_amount = new_paid, status = new_status
   where id = invoice.id;

  insert into public.cash_transactions (
    branch_id, cash_account_id, direction, category, amount, method,
    reference_id, notes, actor_id
  )
  values (
    invoice.branch_id, account.id, 'in', 'rent', payment_amount,
    payment_method, invoice.id, 'Rent ' || invoice.invoice_number, auth.uid()
  );

  insert into public.audit_logs (
    branch_id, actor_id, action, entity_table, entity_id, details
  )
  values (
    invoice.branch_id, auth.uid(), 'rentals.payment', 'rent_invoices',
    invoice.id, jsonb_build_object(
      'amount', payment_amount,
      'balance', invoice.amount - new_paid
    )
  );

  return jsonb_build_object(
    'invoice_id', invoice.id, 'payment_id', payment_id,
    'paid_amount', new_paid, 'status', new_status
  );
end;
$$;

revoke all on function public.generate_rent_invoices(uuid, date)
  from public, anon;
revoke all on function public.record_rent_payment(uuid, uuid, numeric, text, text)
  from public, anon;
grant execute on function public.generate_rent_invoices(uuid, date)
  to authenticated;
grant execute on function public.record_rent_payment(uuid, uuid, numeric, text, text)
  to authenticated;

comment on table public.rent_invoices is
  'One invoice per lease per month. generate_rent_invoices is idempotent for a period.';
