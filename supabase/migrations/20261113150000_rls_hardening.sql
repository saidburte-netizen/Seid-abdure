-- RLS completeness, safe edit/delete policies, bill maintenance functions, and
-- first-owner bootstrap.

-- Draft/catalogue tables may be edited or deleted by their module permission.
create policy "Inventory staff can delete adjustment items"
  on public.stock_adjustment_items for delete to authenticated
  using (
    exists (
      select 1 from public.stock_adjustments adjustment
      where adjustment.id = stock_adjustment_id
        and adjustment.status = 'pending'
        and public.has_permission(adjustment.branch_id, 'inventory.write')
    )
  );

create policy "Inventory staff can delete transfer items"
  on public.stock_transfer_items for delete to authenticated
  using (
    exists (
      select 1 from public.stock_transfers transfer
      where transfer.id = stock_transfer_id
        and transfer.status = 'pending'
        and public.has_permission(transfer.branch_id, 'inventory.write')
    )
  );

create policy "Inventory staff can delete count items"
  on public.stock_count_items for delete to authenticated
  using (
    exists (
      select 1 from public.stock_counts stock_count
      where stock_count.id = stock_count_id
        and stock_count.status in ('draft', 'submitted')
        and public.has_permission(stock_count.branch_id, 'inventory.write')
    )
  );

create policy "HR staff can delete attendance"
  on public.attendance for delete to authenticated
  using (public.has_permission(branch_id, 'people.write'));

create policy "HR staff can delete leave types"
  on public.leave_types for delete to authenticated
  using (public.has_permission(branch_id, 'people.write'));

create policy "Rental staff can delete maintenance"
  on public.maintenance_requests for delete to authenticated
  using (public.has_permission(branch_id, 'rentals.write'));

create policy "Payroll staff can delete components"
  on public.salary_components for delete to authenticated
  using (public.has_permission(branch_id, 'payroll.write'));

create policy "Payroll staff can delete employee components"
  on public.employee_salary_components for delete to authenticated
  using (
    exists (
      select 1 from public.employees employee
      where employee.id = employee_id
        and public.has_permission(employee.branch_id, 'payroll.write')
    )
  );

-- Bills are created and paid through controlled workflows. Details can be
-- corrected while unpaid, and voiding is explicit and audited.
create or replace function public.update_bill_details(
  target_bill uuid,
  new_due_date date default null,
  new_description text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  bill public.bills;
begin
  select * into bill from public.bills where id = target_bill for update;
  if not found then
    raise exception 'Bill not found';
  end if;
  if not public.has_permission(bill.branch_id, 'cash.write') then
    raise exception 'Cash permission required';
  end if;
  if bill.status = 'paid' then
    raise exception 'Paid bills cannot be edited';
  end if;

  update public.bills
     set due_date = coalesce(new_due_date, due_date),
         description = coalesce(new_description, description)
   where id = bill.id;

  return jsonb_build_object('bill_id', bill.id, 'status', bill.status);
end;
$$;

create or replace function public.void_bill(target_bill uuid, reason text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  bill public.bills;
begin
  select * into bill from public.bills where id = target_bill for update;
  if not found then
    raise exception 'Bill not found';
  end if;
  if not public.has_permission(bill.branch_id, 'cash.approve') then
    raise exception 'Approval permission required';
  end if;
  if bill.paid_amount > 0 then
    raise exception 'Bills with payments cannot be voided';
  end if;

  update public.bills set status = 'void' where id = bill.id;

  insert into public.audit_logs (
    branch_id, actor_id, action, entity_table, entity_id, details
  )
  values (
    bill.branch_id, auth.uid(), 'payables.void', 'bills', bill.id,
    jsonb_build_object('reason', reason)
  );

  return jsonb_build_object('bill_id', bill.id, 'status', 'void');
end;
$$;

revoke all on function public.update_bill_details(uuid, date, text)
  from public, anon;
revoke all on function public.void_bill(uuid, text) from public, anon;
grant execute on function public.update_bill_details(uuid, date, text)
  to authenticated;
grant execute on function public.void_bill(uuid, text) to authenticated;

-- The very first authenticated user may claim ownership of the first branch
-- when no membership exists yet. This closes the "chicken and egg" setup gap
-- without allowing later privilege escalation.
create or replace function public.bootstrap_first_owner()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  target_branch uuid;
  owner_role uuid;
  membership uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if exists (select 1 from public.branch_memberships where is_active) then
    raise exception 'An owner already exists; ask an administrator to assign your role';
  end if;

  select id into target_branch from public.branches order by created_at limit 1;
  if target_branch is null then
    insert into public.branches (name, code)
    values ('Main Branch', 'MAIN')
    returning id into target_branch;
  end if;

  select id into owner_role
  from public.roles
  where branch_id = target_branch and slug = 'owner';

  if owner_role is null then
    perform public.provision_branch(target_branch);
    select id into owner_role
    from public.roles
    where branch_id = target_branch and slug = 'owner';
  end if;

  insert into public.branch_memberships (branch_id, user_id, role_id)
  values (target_branch, auth.uid(), owner_role)
  on conflict (branch_id, user_id) do update
    set role_id = excluded.role_id, is_active = true
  returning id into membership;

  insert into public.audit_logs (
    branch_id, actor_id, action, entity_table, entity_id, details
  )
  values (
    target_branch, auth.uid(), 'organization.bootstrap', 'branch_memberships',
    membership, jsonb_build_object('method', 'first_owner_claim')
  );

  return jsonb_build_object(
    'branch_id', target_branch, 'membership_id', membership, 'role', 'owner'
  );
end;
$$;

revoke all on function public.bootstrap_first_owner() from public, anon;
grant execute on function public.bootstrap_first_owner() to authenticated;

-- Coverage helpers used by the database regression suite and operations.
create or replace view public.rls_coverage
as
select
  t.schemaname as table_schema,
  t.tablename as table_name,
  t.rowsecurity as rls_enabled,
  (select count(*) from pg_policies policy
   where policy.schemaname = t.schemaname
     and policy.tablename = t.tablename) as policy_count
from pg_tables t
where t.schemaname = 'public'
  and t.tablename <> 'rls_coverage';

-- Guard against accidental deletion of audit history.
create policy "Audit history is append-only"
  on public.audit_logs for delete to authenticated
  using (false);

grant select on public.rls_coverage to authenticated;

comment on function public.bootstrap_first_owner() is
  'One-time setup claim, available only while no active membership exists.';
comment on view public.rls_coverage is
  'Operational check that every public table has RLS enabled and at least one policy.';
