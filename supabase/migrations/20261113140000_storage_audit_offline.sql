-- Private storage, audit triggers, and offline point-of-sale synchronization.

-- ---------------------------------------------------------------------------
-- Private storage buckets
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'documents', 'documents', false, 10485760,
    array['application/pdf', 'image/jpeg', 'image/png', 'image/webp']
  ),
  (
    'receipts', 'receipts', false, 5242880,
    array['application/pdf', 'image/jpeg', 'image/png', 'text/csv']
  ),
  (
    'exports', 'exports', false, 52428800,
    array['application/json', 'text/csv', 'application/pdf']
  )
on conflict (id) do nothing;

create or replace function public.storage_branch_id(object_name text)
returns uuid
language plpgsql
immutable
as $$
declare
  first_segment text;
begin
  first_segment := split_part(object_name, '/', 1);
  if first_segment ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return first_segment::uuid;
  end if;
  return null;
end;
$$;

create policy "Members can read branch documents"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'documents'
    and public.storage_branch_id(name) is not null
    and public.has_permission(public.storage_branch_id(name), 'documents.read')
  );

create policy "Document staff can upload branch documents"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'documents'
    and public.storage_branch_id(name) is not null
    and public.has_permission(public.storage_branch_id(name), 'documents.write')
  );

create policy "Document staff can update branch documents"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'documents'
    and public.storage_branch_id(name) is not null
    and public.has_permission(public.storage_branch_id(name), 'documents.write')
  )
  with check (
    bucket_id = 'documents'
    and public.storage_branch_id(name) is not null
    and public.has_permission(public.storage_branch_id(name), 'documents.write')
  );

create policy "Document staff can delete branch documents"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'documents'
    and public.storage_branch_id(name) is not null
    and public.has_permission(public.storage_branch_id(name), 'documents.write')
  );

create policy "Sales staff can read branch receipts"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'receipts'
    and public.storage_branch_id(name) is not null
    and public.has_permission(public.storage_branch_id(name), 'sales.read')
  );

create policy "Sales staff can upload branch receipts"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'receipts'
    and public.storage_branch_id(name) is not null
    and public.has_permission(public.storage_branch_id(name), 'sales.write')
  );

create policy "Sales supervisors can delete branch receipts"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'receipts'
    and public.storage_branch_id(name) is not null
    and public.has_permission(public.storage_branch_id(name), 'sales.void')
  );

create policy "Report staff can read branch exports"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'exports'
    and public.storage_branch_id(name) is not null
    and public.has_permission(public.storage_branch_id(name), 'reports.export')
  );

create policy "Report staff can write branch exports"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'exports'
    and public.storage_branch_id(name) is not null
    and public.has_permission(public.storage_branch_id(name), 'reports.export')
  );

revoke all on function public.storage_branch_id(text) from public;
grant execute on function public.storage_branch_id(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Audit triggers
-- ---------------------------------------------------------------------------

create or replace function public.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  row_data jsonb;
  previous_data jsonb;
  branch uuid;
  entity uuid;
  action_name text;
begin
  if tg_op = 'DELETE' then
    row_data := to_jsonb(old);
    previous_data := null;
    action_name := 'delete';
  elsif tg_op = 'UPDATE' then
    row_data := to_jsonb(new);
    previous_data := to_jsonb(old);
    action_name := 'update';
  else
    row_data := to_jsonb(new);
    previous_data := null;
    action_name := 'insert';
  end if;

  branch := nullif(row_data ->> 'branch_id', '')::uuid;
  if branch is null and tg_table_name = 'branches' then
    branch := nullif(row_data ->> 'id', '')::uuid;
  end if;
  entity := nullif(row_data ->> 'id', '')::uuid;

  insert into public.audit_logs (
    branch_id, actor_id, action, entity_table, entity_id, details
  )
  values (
    branch,
    auth.uid(),
    action_name,
    tg_table_name,
    entity,
    jsonb_build_object(
      'new', row_data,
      'old', previous_data
    )
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function public.audit_row_change() from public;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'products', 'inventory_items', 'customers', 'sales', 'expenses', 'bills',
    'suppliers', 'purchase_orders', 'stock_adjustments', 'stock_transfers',
    'employees', 'leave_requests', 'payroll_runs', 'properties', 'leases',
    'rent_invoices', 'maintenance_requests', 'organization_settings',
    'branch_settings', 'branches'
  ]
  loop
    execute format(
      'drop trigger if exists audit_%1$s on public.%1$I', table_name
    );
    execute format(
      'create trigger audit_%1$s after insert or update or delete on public.%1$I
       for each row execute function public.audit_row_change()', table_name
    );
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Offline point-of-sale synchronization
-- ---------------------------------------------------------------------------

create table public.pos_sync_batches (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  device_id text not null,
  client_id uuid not null,
  payload jsonb not null,
  status text not null default 'pending'
    check (status in ('pending', 'synced', 'conflict', 'rejected')),
  sale_id uuid references public.sales (id),
  error_message text,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  unique (branch_id, client_id)
);

create index pos_sync_batches_status_idx
  on public.pos_sync_batches (branch_id, status, received_at);

alter table public.pos_sync_batches enable row level security;

create policy "Sales staff can read sync batches"
  on public.pos_sync_batches for select to authenticated
  using (public.user_has_branch_access(branch_id));

create or replace function public.sync_offline_sale(
  target_branch uuid,
  p_device_id text,
  p_client_id uuid,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  existing public.pos_sync_batches;
  sale_result jsonb;
  batch_id uuid;
begin
  if not public.has_permission(target_branch, 'sales.write') then
    raise exception 'Sales permission required';
  end if;
  if p_client_id is null then
    raise exception 'A client id is required for offline sales';
  end if;

  select * into existing
  from public.pos_sync_batches
  where branch_id = target_branch and client_id = p_client_id;

  if found then
    return jsonb_build_object(
      'status', existing.status,
      'sale_id', existing.sale_id,
      'already_received', true
    );
  end if;

  insert into public.pos_sync_batches (
    branch_id, device_id, client_id, payload
  )
  values (target_branch, p_device_id, p_client_id, p_payload)
  returning id into batch_id;

  begin
    sale_result := public.complete_sale(
      target_branch,
      p_payload -> 'items',
      p_payload -> 'payments',
      nullif(p_payload ->> 'customer_id', '')::uuid,
      coalesce((p_payload ->> 'discount')::numeric, 0),
      coalesce(p_payload ->> 'notes', ''),
      p_client_id
    );

    update public.pos_sync_batches
       set status = 'synced',
           sale_id = (sale_result ->> 'sale_id')::uuid,
           processed_at = now()
     where id = batch_id;

    return sale_result || jsonb_build_object('status', 'synced');
  exception when others then
    update public.pos_sync_batches
       set status = 'rejected',
           error_message = sqlerrm,
           processed_at = now()
     where id = batch_id;
    raise;
  end;
end;
$$;

revoke all on function public.sync_offline_sale(uuid, text, uuid, jsonb)
  from public, anon;
grant execute on function public.sync_offline_sale(uuid, text, uuid, jsonb)
  to authenticated;

comment on table public.pos_sync_batches is
  'Server-side inbox for queued offline sales. client_id is unique per branch, making retries safe.';
