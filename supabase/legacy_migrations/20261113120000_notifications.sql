-- In-app notifications, per-user preferences, read tracking, and alert
-- generation for stock, receivables, payables, rentals, and approvals.

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  category text not null check (
    category in ('stock', 'sales', 'cash', 'payables', 'rentals', 'people', 'system')
  ),
  severity text not null default 'info'
    check (severity in ('info', 'warning', 'critical')),
  title text not null,
  body text not null default '',
  entity_table text,
  entity_id uuid,
  dedupe_key text not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  unique (branch_id, dedupe_key)
);

create table public.notification_reads (
  notification_id uuid not null references public.notifications (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (notification_id, user_id)
);

create table public.notification_preferences (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  in_app boolean not null default true,
  email_digest boolean not null default true,
  stock_alerts boolean not null default true,
  payable_alerts boolean not null default true,
  rent_alerts boolean not null default true,
  approval_alerts boolean not null default true,
  updated_at timestamptz not null default now()
);

create index notifications_branch_created_idx
  on public.notifications (branch_id, created_at desc);
create index notifications_category_idx
  on public.notifications (branch_id, category, created_at desc);

alter table public.notifications enable row level security;
alter table public.notification_reads enable row level security;
alter table public.notification_preferences enable row level security;

create policy "Members can read branch notifications"
  on public.notifications for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Members can read their notification markers"
  on public.notification_reads for select to authenticated
  using (user_id = auth.uid());
create policy "Members can mark notifications read"
  on public.notification_reads for insert to authenticated
  with check (user_id = auth.uid());
create policy "Members can clear their notification markers"
  on public.notification_reads for delete to authenticated
  using (user_id = auth.uid());

create policy "Users can read their notification preferences"
  on public.notification_preferences for select to authenticated
  using (user_id = auth.uid());
create policy "Users can create their notification preferences"
  on public.notification_preferences for insert to authenticated
  with check (user_id = auth.uid());
create policy "Users can update their notification preferences"
  on public.notification_preferences for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

insert into public.notification_preferences (user_id)
select id from public.profiles
on conflict (user_id) do nothing;

create or replace function public.handle_new_profile_preferences()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.notification_preferences (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

create trigger on_profile_created_preferences
  after insert on public.profiles
  for each row execute function public.handle_new_profile_preferences();

create or replace function public.refresh_branch_alerts(target_branch uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  created integer := 0;
  item_row record;
begin
  if not public.user_has_branch_access(target_branch) then
    raise exception 'Branch access denied';
  end if;

  for item_row in
    select
      item.id,
      item.name,
      coalesce(sum(movement.quantity_delta), 0) as on_hand,
      item.minimum_quantity
    from public.inventory_items item
    left join public.stock_movements movement
      on movement.inventory_item_id = item.id
      and movement.branch_id = item.branch_id
    where item.branch_id = target_branch
      and item.is_active
      and item.minimum_quantity > 0
    group by item.id, item.name, item.minimum_quantity
    having coalesce(sum(movement.quantity_delta), 0) <= item.minimum_quantity
  loop
    insert into public.notifications (
      branch_id, category, severity, title, body, entity_table, entity_id,
      dedupe_key
    )
    values (
      target_branch, 'stock', 'warning',
      'Low stock: ' || item_row.name,
      'On hand ' || item_row.on_hand || ', minimum ' || item_row.minimum_quantity,
      'inventory_items', item_row.id,
      'low-stock:' || item_row.id::text
    )
    on conflict (branch_id, dedupe_key) do nothing;
    created := created + 1;
  end loop;

  for item_row in
    select invoice.id, invoice.invoice_number, invoice.due_date,
      invoice.amount - invoice.paid_amount as balance
    from public.rent_invoices invoice
    where invoice.branch_id = target_branch
      and invoice.status in ('unpaid', 'partial')
      and invoice.due_date < current_date
  loop
    insert into public.notifications (
      branch_id, category, severity, title, body, entity_table, entity_id,
      dedupe_key
    )
    values (
      target_branch, 'rentals', 'warning',
      'Overdue rent invoice ' || item_row.invoice_number,
      'Outstanding ' || item_row.balance || ' ETB, due ' || item_row.due_date,
      'rent_invoices', item_row.id,
      'rent-overdue:' || item_row.id::text
    )
    on conflict (branch_id, dedupe_key) do nothing;
    created := created + 1;
  end loop;

  for item_row in
    select bill.id, bill.bill_number, bill.due_date,
      bill.amount - bill.paid_amount as balance
    from public.bills bill
    where bill.branch_id = target_branch
      and bill.status in ('unpaid', 'partial')
      and bill.due_date < current_date
  loop
    insert into public.notifications (
      branch_id, category, severity, title, body, entity_table, entity_id,
      dedupe_key
    )
    values (
      target_branch, 'payables', 'warning',
      'Supplier bill overdue: ' || item_row.bill_number,
      'Outstanding ' || item_row.balance || ' ETB, due ' || item_row.due_date,
      'bills', item_row.id,
      'bill-overdue:' || item_row.id::text
    )
    on conflict (branch_id, dedupe_key) do nothing;
    created := created + 1;
  end loop;

  for item_row in
    select lease.id, lease.tenant_name, unit.name as unit_name, lease.end_date
    from public.leases lease
    join public.units unit on unit.id = lease.unit_id
    where lease.branch_id = target_branch
      and lease.status = 'active'
      and lease.end_date between current_date and current_date + 30
  loop
    insert into public.notifications (
      branch_id, category, severity, title, body, entity_table, entity_id,
      dedupe_key
    )
    values (
      target_branch, 'rentals', 'info',
      'Lease ending soon: ' || item_row.tenant_name,
      'Unit ' || item_row.unit_name || ', ends ' || item_row.end_date,
      'leases', item_row.id,
      'lease-expiring:' || item_row.id::text
    )
    on conflict (branch_id, dedupe_key) do nothing;
    created := created + 1;
  end loop;

  for item_row in
    select expense.id, expense.description, expense.amount
    from public.expenses expense
    where expense.branch_id = target_branch and expense.status = 'pending'
  loop
    insert into public.notifications (
      branch_id, category, severity, title, body, entity_table, entity_id,
      dedupe_key
    )
    values (
      target_branch, 'cash', 'info',
      'Expense awaiting approval',
      item_row.description || ' for ' || item_row.amount || ' ETB',
      'expenses', item_row.id,
      'expense-pending:' || item_row.id::text
    )
    on conflict (branch_id, dedupe_key) do nothing;
    created := created + 1;
  end loop;

  for item_row in
    select leave_request.id, employee.full_name, leave_request.start_date
    from public.leave_requests leave_request
    join public.employees employee on employee.id = leave_request.employee_id
    where leave_request.branch_id = target_branch
      and leave_request.status = 'pending'
  loop
    insert into public.notifications (
      branch_id, category, severity, title, body, entity_table, entity_id,
      dedupe_key
    )
    values (
      target_branch, 'people', 'info',
      'Leave request awaiting review',
      item_row.full_name || ' from ' || item_row.start_date,
      'leave_requests', item_row.id,
      'leave-pending:' || item_row.id::text
    )
    on conflict (branch_id, dedupe_key) do nothing;
    created := created + 1;
  end loop;

  delete from public.notifications notification
  where notification.branch_id = target_branch
    and notification.dedupe_key like 'low-stock:%'
    and notification.entity_id is not null
    and not exists (
      select 1
      from public.inventory_items item
      where item.id = notification.entity_id
        and item.is_active
        and coalesce((
          select sum(movement.quantity_delta)
          from public.stock_movements movement
          where movement.inventory_item_id = item.id
            and movement.branch_id = item.branch_id
        ), 0) <= item.minimum_quantity
    );

  return jsonb_build_object('branch_id', target_branch, 'processed', created);
end;
$$;

revoke all on function public.refresh_branch_alerts(uuid) from public, anon;
grant execute on function public.refresh_branch_alerts(uuid) to authenticated;

comment on table public.notifications is
  'Branch-wide alerts deduplicated by dedupe_key. Per-user read state lives in notification_reads.';
