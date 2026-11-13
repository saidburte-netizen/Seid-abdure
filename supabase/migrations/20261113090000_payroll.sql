-- Payroll runs, configurable earnings/deductions, advances, and payslips.

create table public.payroll_settings (
  branch_id uuid primary key references public.branches (id) on delete cascade,
  pension_employee_rate numeric(7, 4) not null default 0.07
    check (pension_employee_rate >= 0 and pension_employee_rate <= 1),
  pension_employer_rate numeric(7, 4) not null default 0.11
    check (pension_employer_rate >= 0 and pension_employer_rate <= 1),
  income_tax_rate numeric(7, 4) not null default 0.15
    check (income_tax_rate >= 0 and income_tax_rate <= 1),
  overtime_multiplier numeric(5, 2) not null default 1.5
    check (overtime_multiplier >= 1),
  standard_monthly_hours numeric(6, 2) not null default 208
    check (standard_monthly_hours > 0),
  updated_at timestamptz not null default now()
);

create table public.salary_components (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  name text not null,
  component_type text not null check (component_type in ('earning', 'deduction')),
  calc_type text not null default 'fixed' check (calc_type in ('fixed', 'percent')),
  amount numeric(14, 2) not null default 0 check (amount >= 0),
  rate numeric(7, 4) not null default 0 check (rate >= 0 and rate <= 1),
  is_statutory boolean not null default false,
  is_active boolean not null default true,
  unique (branch_id, name)
);

create table public.employee_salary_components (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees (id) on delete cascade,
  component_id uuid not null references public.salary_components (id) on delete cascade,
  amount_override numeric(14, 2),
  rate_override numeric(7, 4)
    check (rate_override is null or (rate_override >= 0 and rate_override <= 1)),
  unique (employee_id, component_id)
);

create table public.payroll_advances (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  employee_id uuid not null references public.employees (id) on delete cascade,
  amount numeric(14, 2) not null check (amount > 0),
  balance numeric(14, 2) not null check (balance >= 0),
  repayment_amount numeric(14, 2) not null default 0
    check (repayment_amount >= 0),
  status text not null default 'active'
    check (status in ('active', 'settled', 'cancelled')),
  issued_at date not null default current_date,
  notes text not null default '',
  created_by uuid not null default auth.uid() references public.profiles (id),
  created_at timestamptz not null default now(),
  check (balance <= amount)
);

create table public.payroll_runs (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  period_start date not null,
  period_end date not null,
  status text not null default 'draft'
    check (status in ('draft', 'approved', 'paid', 'cancelled')),
  gross_total numeric(14, 2) not null default 0 check (gross_total >= 0),
  deduction_total numeric(14, 2) not null default 0
    check (deduction_total >= 0),
  net_total numeric(14, 2) not null default 0 check (net_total >= 0),
  notes text not null default '',
  created_by uuid not null default auth.uid() references public.profiles (id),
  approved_by uuid references public.profiles (id),
  approved_at timestamptz,
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  unique (branch_id, period_start, period_end),
  check (period_end >= period_start)
);

create table public.payslips (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  payroll_run_id uuid not null references public.payroll_runs (id) on delete cascade,
  employee_id uuid not null references public.employees (id),
  payslip_number text not null,
  gross_pay numeric(14, 2) not null default 0 check (gross_pay >= 0),
  total_deductions numeric(14, 2) not null default 0 check (total_deductions >= 0),
  net_pay numeric(14, 2) not null default 0 check (net_pay >= 0),
  days_worked numeric(6, 2) not null default 0,
  overtime_hours numeric(6, 2) not null default 0,
  generated_at timestamptz not null default now(),
  unique (payroll_run_id, employee_id),
  unique (branch_id, payslip_number)
);

create table public.payslip_lines (
  id uuid primary key default gen_random_uuid(),
  payslip_id uuid not null references public.payslips (id) on delete cascade,
  component_id uuid references public.salary_components (id),
  name text not null,
  line_type text not null check (line_type in ('earning', 'deduction')),
  amount numeric(14, 2) not null check (amount >= 0)
);

create index payroll_runs_branch_period_idx
  on public.payroll_runs (branch_id, period_start desc);
create index payslips_run_idx on public.payslips (payroll_run_id);
create index payroll_advances_employee_idx
  on public.payroll_advances (employee_id, status);

alter table public.payroll_settings enable row level security;
alter table public.salary_components enable row level security;
alter table public.employee_salary_components enable row level security;
alter table public.payroll_advances enable row level security;
alter table public.payroll_runs enable row level security;
alter table public.payslips enable row level security;
alter table public.payslip_lines enable row level security;

create policy "Payroll staff can read settings"
  on public.payroll_settings for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Payroll staff can write settings"
  on public.payroll_settings for insert to authenticated
  with check (public.has_permission(branch_id, 'payroll.write'));
create policy "Payroll staff can update settings"
  on public.payroll_settings for update to authenticated
  using (public.has_permission(branch_id, 'payroll.write'))
  with check (public.has_permission(branch_id, 'payroll.write'));

create policy "Payroll staff can read components"
  on public.salary_components for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Payroll staff can write components"
  on public.salary_components for insert to authenticated
  with check (public.has_permission(branch_id, 'payroll.write'));
create policy "Payroll staff can update components"
  on public.salary_components for update to authenticated
  using (public.has_permission(branch_id, 'payroll.write'))
  with check (public.has_permission(branch_id, 'payroll.write'));

create policy "Payroll staff can read employee components"
  on public.employee_salary_components for select to authenticated
  using (
    exists (
      select 1 from public.employees employee
      where employee.id = employee_id
        and public.user_has_branch_access(employee.branch_id)
    )
  );
create policy "Payroll staff can write employee components"
  on public.employee_salary_components for insert to authenticated
  with check (
    exists (
      select 1 from public.employees employee
      where employee.id = employee_id
        and public.has_permission(employee.branch_id, 'payroll.write')
    )
  );
create policy "Payroll staff can update employee components"
  on public.employee_salary_components for update to authenticated
  using (
    exists (
      select 1 from public.employees employee
      where employee.id = employee_id
        and public.has_permission(employee.branch_id, 'payroll.write')
    )
  )
  with check (
    exists (
      select 1 from public.employees employee
      where employee.id = employee_id
        and public.has_permission(employee.branch_id, 'payroll.write')
    )
  );

create policy "Payroll staff can read advances"
  on public.payroll_advances for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Payroll staff can issue advances"
  on public.payroll_advances for insert to authenticated
  with check (public.has_permission(branch_id, 'payroll.write'));
create policy "Payroll staff can update advances"
  on public.payroll_advances for update to authenticated
  using (public.has_permission(branch_id, 'payroll.write'))
  with check (public.has_permission(branch_id, 'payroll.write'));

create policy "Payroll staff can read runs"
  on public.payroll_runs for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Payroll staff can read payslips"
  on public.payslips for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Payroll staff can read payslip lines"
  on public.payslip_lines for select to authenticated
  using (
    exists (
      select 1 from public.payslips payslip
      where payslip.id = payslip_id
        and public.user_has_branch_access(payslip.branch_id)
    )
  );

insert into public.payroll_settings (branch_id)
select id from public.branches
on conflict (branch_id) do nothing;

create or replace function public.seed_payroll_defaults()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.payroll_settings (branch_id)
  values (new.id)
  on conflict (branch_id) do nothing;

  insert into public.salary_components (
    branch_id, name, component_type, calc_type, rate, is_statutory
  )
  values
    (new.id, 'Pension (employee)', 'deduction', 'percent', 0.07, true),
    (new.id, 'Income tax', 'deduction', 'percent', 0.15, true)
  on conflict (branch_id, name) do nothing;

  return new;
end;
$$;

create trigger on_branch_payroll_defaults
  after insert on public.branches
  for each row execute function public.seed_payroll_defaults();

do $$
declare
  branch_row record;
begin
  for branch_row in select id from public.branches loop
    insert into public.payroll_settings (branch_id)
    values (branch_row.id)
    on conflict (branch_id) do nothing;

    insert into public.salary_components (
      branch_id, name, component_type, calc_type, rate, is_statutory
    )
    values
      (branch_row.id, 'Pension (employee)', 'deduction', 'percent', 0.07, true),
      (branch_row.id, 'Income tax', 'deduction', 'percent', 0.15, true)
    on conflict (branch_id, name) do nothing;
  end loop;
end;
$$;

create or replace function public.run_payroll(
  target_branch uuid,
  target_period_start date,
  target_period_end date,
  payroll_notes text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  settings public.payroll_settings;
  run public.payroll_runs;
  employee_row record;
  component_row record;
  advance_row public.payroll_advances;
  gross numeric(14, 2);
  deductions numeric(14, 2);
  net numeric(14, 2);
  earning numeric(14, 2);
  deduction numeric(14, 2);
  overtime_pay numeric(14, 2);
  payslip public.payslips;
  generated_number text;
  days_worked numeric(6, 2);
  overtime numeric(6, 2);
  gross_sum numeric(14, 2) := 0;
  deduction_sum numeric(14, 2) := 0;
  advance_deduction numeric(14, 2);
  employee_count integer := 0;
begin
  if not public.has_permission(target_branch, 'payroll.write') then
    raise exception 'Payroll permission required';
  end if;
  if target_period_end < target_period_start then
    raise exception 'Payroll period end must be after its start';
  end if;
  if target_period_end > current_date + 31 then
    raise exception 'Payroll period cannot be far in the future';
  end if;

  insert into public.payroll_settings (branch_id)
  values (target_branch)
  on conflict (branch_id) do nothing;
  select * into settings
  from public.payroll_settings where branch_id = target_branch;

  insert into public.payroll_runs (
    branch_id, period_start, period_end, notes, created_by
  )
  values (
    target_branch, target_period_start, target_period_end,
    coalesce(payroll_notes, ''), auth.uid()
  )
  returning * into run;

  for employee_row in
    select * from public.employees
    where branch_id = target_branch and status in ('active', 'on_leave')
    order by employee_number
  loop
    gross := employee_row.basic_salary;
    deductions := 0;

    select
      coalesce(count(*) filter (where status in ('present', 'late', 'half_day')), 0),
      coalesce(sum(overtime_hours), 0)
      into days_worked, overtime
    from public.attendance
    where employee_id = employee_row.id
      and work_date between target_period_start and target_period_end;

    overtime_pay := round(
      employee_row.basic_salary / settings.standard_monthly_hours *
      overtime * settings.overtime_multiplier,
      2
    );

    insert into public.payslips (
      branch_id, payroll_run_id, employee_id, payslip_number,
      days_worked, overtime_hours
    )
    values (
      target_branch, run.id, employee_row.id, 'TEMP',
      days_worked, overtime
    )
    returning * into payslip;

    if employee_row.basic_salary > 0 then
      insert into public.payslip_lines (payslip_id, name, line_type, amount)
      values (payslip.id, 'Basic salary', 'earning', employee_row.basic_salary);
    end if;
    if overtime_pay > 0 then
      insert into public.payslip_lines (payslip_id, name, line_type, amount)
      values (payslip.id, 'Overtime', 'earning', overtime_pay);
      gross := gross + overtime_pay;
    end if;

    for component_row in
      select
        component.*,
        coalesce(employee_component.amount_override, component.amount) as effective_amount,
        coalesce(employee_component.rate_override, component.rate) as effective_rate
      from public.salary_components component
      left join public.employee_salary_components employee_component
        on employee_component.component_id = component.id
        and employee_component.employee_id = employee_row.id
      where component.branch_id = target_branch and component.is_active
      order by component.component_type, component.name
    loop
      earning := case
        when component_row.calc_type = 'percent'
          then round(employee_row.basic_salary * component_row.effective_rate, 2)
        else component_row.effective_amount
      end;

      if earning <= 0 then
        continue;
      end if;

      insert into public.payslip_lines (
        payslip_id, component_id, name, line_type, amount
      )
      values (
        payslip.id, component_row.id, component_row.name,
        component_row.component_type, earning
      );

      if component_row.component_type = 'earning' then
        gross := gross + earning;
      else
        deductions := deductions + earning;
      end if;
    end loop;

    for advance_row in
      select * from public.payroll_advances
      where employee_id = employee_row.id and status = 'active' and balance > 0
      order by issued_at
    loop
      advance_deduction := least(
        advance_row.balance,
        case when advance_row.repayment_amount > 0
          then advance_row.repayment_amount
          else advance_row.balance
        end
      );
      if advance_deduction <= 0 then
        continue;
      end if;

      insert into public.payslip_lines (
        payslip_id, name, line_type, amount
      )
      values (
        payslip.id, 'Salary advance recovery', 'deduction', advance_deduction
      );
      deductions := deductions + advance_deduction;

      update public.payroll_advances
         set balance = balance - advance_deduction,
             status = case when balance - advance_deduction = 0
               then 'settled' else 'active' end
       where id = advance_row.id;
    end loop;

    net := greatest(gross - deductions, 0);
    generated_number := public.next_document_number(target_branch, 'payslip');

    update public.payslips
       set payslip_number = generated_number,
           gross_pay = gross,
           total_deductions = deductions,
           net_pay = net
     where id = payslip.id;

    gross_sum := gross_sum + gross;
    deduction_sum := deduction_sum + deductions;
    employee_count := employee_count + 1;
  end loop;

  update public.payroll_runs
     set gross_total = gross_sum,
         deduction_total = deduction_sum,
         net_total = gross_sum - deduction_sum
   where id = run.id
  returning * into run;

  insert into public.audit_logs (
    branch_id, actor_id, action, entity_table, entity_id, details
  )
  values (
    target_branch, auth.uid(), 'payroll.run', 'payroll_runs', run.id,
    jsonb_build_object(
      'period_start', target_period_start,
      'period_end', target_period_end,
      'employees', employee_count,
      'net_total', run.net_total
    )
  );

  return jsonb_build_object(
    'payroll_run_id', run.id,
    'employees', employee_count,
    'gross_total', run.gross_total,
    'deduction_total', run.deduction_total,
    'net_total', run.net_total
  );
end;
$$;

create or replace function public.approve_payroll(
  target_run uuid,
  target_account uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  run public.payroll_runs;
  account public.cash_accounts;
begin
  select * into run from public.payroll_runs where id = target_run for update;
  if not found then
    raise exception 'Payroll run not found';
  end if;
  if not public.has_permission(run.branch_id, 'payroll.write') then
    raise exception 'Payroll permission required';
  end if;
  if run.status <> 'draft' then
    raise exception 'Payroll run is already %', run.status;
  end if;

  update public.payroll_runs
     set status = 'approved', approved_by = auth.uid(), approved_at = now()
   where id = run.id;

  if target_account is not null then
    select * into account
    from public.cash_accounts
    where id = target_account and branch_id = run.branch_id;
    if not found then
      raise exception 'Cash account does not belong to this branch';
    end if;

    insert into public.cash_transactions (
      branch_id, cash_account_id, direction, category, amount, method,
      reference_id, notes, actor_id
    )
    values (
      run.branch_id, account.id, 'out', 'payroll', run.net_total, 'cash',
      run.id, 'Payroll ' || run.period_start || ' to ' || run.period_end,
      auth.uid()
    );

    update public.payroll_runs
       set status = 'paid', paid_at = now()
     where id = run.id;
  end if;

  insert into public.audit_logs (
    branch_id, actor_id, action, entity_table, entity_id, details
  )
  values (
    run.branch_id, auth.uid(), 'payroll.approve', 'payroll_runs', run.id,
    jsonb_build_object('net_total', run.net_total, 'paid', target_account is not null)
  );

  return jsonb_build_object(
    'payroll_run_id', run.id,
    'status', case when target_account is null then 'approved' else 'paid' end
  );
end;
$$;

revoke all on function public.run_payroll(uuid, date, date, text)
  from public, anon;
revoke all on function public.approve_payroll(uuid, uuid) from public, anon;
grant execute on function public.run_payroll(uuid, date, date, text)
  to authenticated;
grant execute on function public.approve_payroll(uuid, uuid) to authenticated;

comment on table public.payroll_advances is
  'Outstanding salary advances. Payroll recovers repayment_amount per run and settles the advance at zero.';
