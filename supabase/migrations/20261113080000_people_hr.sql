-- Employee records, shifts, attendance, leave types, and leave workflows.

create table public.employees (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  profile_id uuid references public.profiles (id) on delete set null,
  employee_number text not null,
  full_name text not null,
  phone text,
  email text,
  position text not null default '',
  department text not null default '',
  employment_type text not null default 'full_time'
    check (employment_type in ('full_time', 'part_time', 'contract', 'daily')),
  hire_date date not null default current_date,
  end_date date,
  basic_salary numeric(14, 2) not null default 0 check (basic_salary >= 0),
  status text not null default 'active'
    check (status in ('active', 'on_leave', 'suspended', 'terminated')),
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (branch_id, employee_number),
  check (end_date is null or end_date >= hire_date)
);

create table public.shifts (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  name text not null,
  start_time time not null,
  end_time time not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (branch_id, name)
);

create table public.leave_types (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  name text not null,
  is_paid boolean not null default true,
  annual_days numeric(6, 2) not null default 0 check (annual_days >= 0),
  requires_approval boolean not null default true,
  is_active boolean not null default true,
  unique (branch_id, name)
);

create table public.attendance (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  employee_id uuid not null references public.employees (id) on delete cascade,
  work_date date not null default current_date,
  shift_id uuid references public.shifts (id),
  check_in timestamptz,
  check_out timestamptz,
  status text not null default 'present'
    check (status in ('present', 'late', 'absent', 'half_day', 'leave', 'holiday')),
  overtime_hours numeric(5, 2) not null default 0 check (overtime_hours >= 0),
  notes text not null default '',
  recorded_by uuid not null default auth.uid() references public.profiles (id),
  created_at timestamptz not null default now(),
  unique (employee_id, work_date),
  check (check_out is null or check_in is null or check_out >= check_in)
);

create table public.leave_requests (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  employee_id uuid not null references public.employees (id) on delete cascade,
  leave_type_id uuid not null references public.leave_types (id),
  start_date date not null,
  end_date date not null,
  days numeric(6, 2) not null check (days > 0),
  reason text not null default '',
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  requested_by uuid not null default auth.uid() references public.profiles (id),
  reviewed_by uuid references public.profiles (id),
  reviewed_at timestamptz,
  review_note text not null default '',
  created_at timestamptz not null default now(),
  check (end_date >= start_date)
);

create index employees_branch_status_idx
  on public.employees (branch_id, status);
create index attendance_branch_date_idx
  on public.attendance (branch_id, work_date desc);
create index leave_requests_branch_status_idx
  on public.leave_requests (branch_id, status, start_date);

create trigger set_employees_updated_at
  before update on public.employees
  for each row execute function public.set_updated_at();

alter table public.employees enable row level security;
alter table public.shifts enable row level security;
alter table public.leave_types enable row level security;
alter table public.attendance enable row level security;
alter table public.leave_requests enable row level security;

create policy "HR staff can read employees"
  on public.employees for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "HR staff can create employees"
  on public.employees for insert to authenticated
  with check (public.has_permission(branch_id, 'people.write'));
create policy "HR staff can update employees"
  on public.employees for update to authenticated
  using (public.has_permission(branch_id, 'people.write'))
  with check (public.has_permission(branch_id, 'people.write'));
create policy "HR staff can delete employees"
  on public.employees for delete to authenticated
  using (public.has_permission(branch_id, 'people.write'));

create policy "HR staff can read shifts"
  on public.shifts for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "HR staff can write shifts"
  on public.shifts for insert to authenticated
  with check (public.has_permission(branch_id, 'people.write'));
create policy "HR staff can update shifts"
  on public.shifts for update to authenticated
  using (public.has_permission(branch_id, 'people.write'))
  with check (public.has_permission(branch_id, 'people.write'));

create policy "HR staff can read leave types"
  on public.leave_types for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "HR staff can write leave types"
  on public.leave_types for insert to authenticated
  with check (public.has_permission(branch_id, 'people.write'));
create policy "HR staff can update leave types"
  on public.leave_types for update to authenticated
  using (public.has_permission(branch_id, 'people.write'))
  with check (public.has_permission(branch_id, 'people.write'));

create policy "HR staff can read attendance"
  on public.attendance for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "HR staff can record attendance"
  on public.attendance for insert to authenticated
  with check (
    public.has_permission(branch_id, 'people.write')
    and recorded_by = auth.uid()
  );
create policy "HR staff can update attendance"
  on public.attendance for update to authenticated
  using (public.has_permission(branch_id, 'people.write'))
  with check (public.has_permission(branch_id, 'people.write'));

create policy "HR staff can read leave requests"
  on public.leave_requests for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "HR staff can request leave"
  on public.leave_requests for insert to authenticated
  with check (
    public.has_permission(branch_id, 'people.write')
    and requested_by = auth.uid()
  );

create or replace function public.review_leave_request(
  target_request uuid,
  approve boolean,
  note text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  leave_request public.leave_requests;
  day_cursor date;
begin
  select * into leave_request
  from public.leave_requests where id = target_request for update;
  if not found then
    raise exception 'Leave request not found';
  end if;
  if not public.has_permission(leave_request.branch_id, 'people.write') then
    raise exception 'HR permission required';
  end if;
  if leave_request.status <> 'pending' then
    raise exception 'Leave request is already %', leave_request.status;
  end if;

  update public.leave_requests
     set status = case when approve then 'approved' else 'rejected' end,
         reviewed_by = auth.uid(),
         reviewed_at = now(),
         review_note = coalesce(note, '')
   where id = leave_request.id;

  if approve then
    day_cursor := leave_request.start_date;
    while day_cursor <= leave_request.end_date loop
      insert into public.attendance (
        branch_id, employee_id, work_date, status, notes
      )
      values (
        leave_request.branch_id, leave_request.employee_id, day_cursor,
        'leave', 'Approved leave request'
      )
      on conflict (employee_id, work_date) do update
        set status = 'leave', notes = excluded.notes;
      day_cursor := day_cursor + 1;
    end loop;

    update public.employees
       set status = 'on_leave'
     where id = leave_request.employee_id
       and status = 'active'
       and leave_request.start_date <= current_date
       and leave_request.end_date >= current_date;
  end if;

  insert into public.audit_logs (
    branch_id, actor_id, action, entity_table, entity_id, details
  )
  values (
    leave_request.branch_id, auth.uid(), 'people.leave.review',
    'leave_requests', leave_request.id,
    jsonb_build_object('approved', approve, 'days', leave_request.days)
  );

  return jsonb_build_object(
    'leave_request_id', leave_request.id,
    'status', case when approve then 'approved' else 'rejected' end
  );
end;
$$;

revoke all on function public.review_leave_request(uuid, boolean, text)
  from public, anon;
grant execute on function public.review_leave_request(uuid, boolean, text)
  to authenticated;

create or replace view public.attendance_monthly
with (security_invoker = true)
as
select
  branch_id,
  employee_id,
  date_trunc('month', work_date)::date as month,
  count(*) filter (where status in ('present', 'late', 'half_day')) as days_worked,
  count(*) filter (where status = 'absent') as days_absent,
  count(*) filter (where status = 'leave') as days_leave,
  coalesce(sum(overtime_hours), 0) as overtime_hours
from public.attendance
group by branch_id, employee_id, date_trunc('month', work_date)::date;

-- Default HR catalogue for new and existing branches.
create or replace function public.seed_hr_defaults()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.leave_types (branch_id, name, is_paid, annual_days)
  values
    (new.id, 'Annual leave', true, 16),
    (new.id, 'Sick leave', true, 10),
    (new.id, 'Unpaid leave', false, 0),
    (new.id, 'Maternity leave', true, 90)
  on conflict (branch_id, name) do nothing;

  insert into public.shifts (branch_id, name, start_time, end_time)
  values
    (new.id, 'Morning', time '06:00', time '14:00'),
    (new.id, 'Evening', time '14:00', time '22:00')
  on conflict (branch_id, name) do nothing;

  return new;
end;
$$;

create trigger on_branch_hr_defaults
  after insert on public.branches
  for each row execute function public.seed_hr_defaults();

do $$
declare
  branch_row record;
begin
  for branch_row in select id from public.branches loop
    insert into public.leave_types (branch_id, name, is_paid, annual_days)
    values
      (branch_row.id, 'Annual leave', true, 16),
      (branch_row.id, 'Sick leave', true, 10),
      (branch_row.id, 'Unpaid leave', false, 0),
      (branch_row.id, 'Maternity leave', true, 90)
    on conflict (branch_id, name) do nothing;

    insert into public.shifts (branch_id, name, start_time, end_time)
    values
      (branch_row.id, 'Morning', time '06:00', time '14:00'),
      (branch_row.id, 'Evening', time '14:00', time '22:00')
    on conflict (branch_id, name) do nothing;
  end loop;
end;
$$;

comment on table public.attendance is
  'One row per employee per day. Approving leave keeps attendance and leave records aligned.';
