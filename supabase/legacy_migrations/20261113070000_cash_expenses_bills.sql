-- Cash expenses, bills, approvals, and inter-account transfers.

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  cash_account_id uuid not null references public.cash_accounts (id),
  category text not null,
  description text not null,
  amount numeric(14, 2) not null check (amount > 0),
  expense_date date not null default current_date,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'paid')),
  requested_by uuid not null default auth.uid() references public.profiles (id),
  approved_by uuid references public.profiles (id),
  approved_at timestamptz,
  rejection_reason text,
  receipt_path text,
  created_at timestamptz not null default now()
);

create table public.bills (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  supplier_id uuid references public.suppliers (id),
  bill_number text not null,
  description text not null default '',
  issue_date date not null default current_date,
  due_date date not null default current_date,
  amount numeric(14, 2) not null check (amount > 0),
  paid_amount numeric(14, 2) not null default 0
    check (paid_amount >= 0 and paid_amount <= amount),
  status text not null default 'unpaid'
    check (status in ('unpaid', 'partial', 'paid', 'void')),
  created_by uuid not null default auth.uid() references public.profiles (id),
  approved_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  unique (branch_id, bill_number)
);

create table public.bill_payments (
  id uuid primary key default gen_random_uuid(),
  bill_id uuid not null references public.bills (id) on delete cascade,
  cash_account_id uuid not null references public.cash_accounts (id),
  amount numeric(14, 2) not null check (amount > 0),
  method text not null default 'cash'
    check (method in ('cash', 'telebirr', 'cbe_birr', 'bank', 'other')),
  reference text not null default '',
  paid_at timestamptz not null default now(),
  paid_by uuid not null default auth.uid() references public.profiles (id)
);

create table public.cash_transfers (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  from_account_id uuid not null references public.cash_accounts (id),
  to_account_id uuid not null references public.cash_accounts (id),
  amount numeric(14, 2) not null check (amount > 0),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  notes text not null default '',
  requested_by uuid not null default auth.uid() references public.profiles (id),
  approved_by uuid references public.profiles (id),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  check (from_account_id <> to_account_id)
);

create index expenses_branch_status_idx
  on public.expenses (branch_id, status, expense_date desc);
create index bills_branch_due_idx
  on public.bills (branch_id, status, due_date);
create index bill_payments_bill_idx on public.bill_payments (bill_id);
create index cash_transfers_branch_status_idx
  on public.cash_transfers (branch_id, status, created_at desc);

alter table public.expenses enable row level security;
alter table public.bills enable row level security;
alter table public.bill_payments enable row level security;
alter table public.cash_transfers enable row level security;

create policy "Cash staff can read expenses"
  on public.expenses for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Cash staff can request expenses"
  on public.expenses for insert to authenticated
  with check (
    public.has_permission(branch_id, 'cash.write')
    and requested_by = auth.uid()
  );

create policy "Cash staff can read bills"
  on public.bills for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Cash staff can create bills"
  on public.bills for insert to authenticated
  with check (
    public.has_permission(branch_id, 'cash.write')
    and created_by = auth.uid()
  );
create policy "Cash staff can read bill payments"
  on public.bill_payments for select to authenticated
  using (
    exists (
      select 1 from public.bills bill
      where bill.id = bill_id
        and public.user_has_branch_access(bill.branch_id)
    )
  );

create policy "Cash staff can read transfers"
  on public.cash_transfers for select to authenticated
  using (public.user_has_branch_access(branch_id));
create policy "Cash staff can request transfers"
  on public.cash_transfers for insert to authenticated
  with check (
    public.has_permission(branch_id, 'cash.write')
    and requested_by = auth.uid()
  );

create or replace function public.approve_expense(
  target_expense uuid,
  approve boolean default true,
  review_reason text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  expense public.expenses;
begin
  select * into expense from public.expenses where id = target_expense for update;
  if not found then
    raise exception 'Expense not found';
  end if;
  if not public.has_permission(expense.branch_id, 'cash.approve') then
    raise exception 'Approval permission required';
  end if;
  if expense.status <> 'pending' then
    raise exception 'Expense is already %', expense.status;
  end if;

  if not approve then
    update public.expenses
       set status = 'rejected', approved_by = auth.uid(),
           approved_at = now(), rejection_reason = review_reason
     where id = expense.id;
    return jsonb_build_object('expense_id', expense.id, 'status', 'rejected');
  end if;

  if not exists (
    select 1 from public.cash_accounts account
    where account.id = expense.cash_account_id
      and account.branch_id = expense.branch_id
  ) then
    raise exception 'Expense cash account is invalid';
  end if;

  insert into public.cash_transactions (
    branch_id, cash_account_id, direction, category, amount, method,
    reference_id, notes, actor_id
  )
  values (
    expense.branch_id, expense.cash_account_id, 'out', 'expense',
    expense.amount, 'cash', expense.id, expense.description, auth.uid()
  );

  update public.expenses
     set status = 'paid', approved_by = auth.uid(), approved_at = now()
   where id = expense.id;

  insert into public.audit_logs (
    branch_id, actor_id, action, entity_table, entity_id, details
  )
  values (
    expense.branch_id, auth.uid(), 'cash.expense.approve', 'expenses',
    expense.id, jsonb_build_object('amount', expense.amount)
  );

  return jsonb_build_object('expense_id', expense.id, 'status', 'paid');
end;
$$;

create or replace function public.pay_bill(
  target_bill uuid,
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
  bill public.bills;
  account public.cash_accounts;
  new_paid numeric(14, 2);
  new_status text;
  payment_id uuid;
begin
  select * into bill from public.bills where id = target_bill for update;
  if not found then
    raise exception 'Bill not found';
  end if;
  if not public.has_permission(bill.branch_id, 'cash.write') then
    raise exception 'Cash permission required';
  end if;
  if bill.status in ('paid', 'void') then
    raise exception 'Bill is already %', bill.status;
  end if;
  if payment_amount is null or payment_amount <= 0 then
    raise exception 'Payment must be positive';
  end if;
  if bill.paid_amount + payment_amount > bill.amount then
    raise exception 'Payment exceeds the outstanding balance';
  end if;

  select * into account
  from public.cash_accounts
  where id = target_account and branch_id = bill.branch_id;
  if not found then
    raise exception 'Cash account does not belong to this branch';
  end if;

  insert into public.bill_payments (
    bill_id, cash_account_id, amount, method, reference, paid_by
  )
  values (
    bill.id, account.id, payment_amount, payment_method,
    coalesce(payment_reference, ''), auth.uid()
  )
  returning id into payment_id;

  new_paid := bill.paid_amount + payment_amount;
  new_status := case when new_paid >= bill.amount then 'paid' else 'partial' end;

  update public.bills
     set paid_amount = new_paid, status = new_status
   where id = bill.id;

  insert into public.cash_transactions (
    branch_id, cash_account_id, direction, category, amount, method,
    reference_id, notes, actor_id
  )
  values (
    bill.branch_id, account.id, 'out', 'bill_payment', payment_amount,
    payment_method, bill.id, 'Payment for bill ' || bill.bill_number,
    auth.uid()
  );

  insert into public.audit_logs (
    branch_id, actor_id, action, entity_table, entity_id, details
  )
  values (
    bill.branch_id, auth.uid(), 'payables.pay', 'bills', bill.id,
    jsonb_build_object('amount', payment_amount, 'balance', bill.amount - new_paid)
  );

  return jsonb_build_object(
    'bill_id', bill.id, 'payment_id', payment_id,
    'paid_amount', new_paid, 'status', new_status
  );
end;
$$;

create or replace function public.approve_cash_transfer(
  target_transfer uuid,
  approve boolean default true,
  review_reason text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
set row_security = off
as $$
declare
  transfer public.cash_transfers;
begin
  select * into transfer
  from public.cash_transfers where id = target_transfer for update;
  if not found then
    raise exception 'Cash transfer not found';
  end if;
  if not public.has_permission(transfer.branch_id, 'cash.approve') then
    raise exception 'Approval permission required';
  end if;
  if transfer.status <> 'pending' then
    raise exception 'Transfer is already %', transfer.status;
  end if;

  if not approve then
    update public.cash_transfers
       set status = 'rejected', approved_by = auth.uid(), approved_at = now()
     where id = transfer.id;
    return jsonb_build_object('transfer_id', transfer.id, 'status', 'rejected');
  end if;

  insert into public.cash_transactions (
    branch_id, cash_account_id, direction, category, amount, method,
    reference_id, notes, actor_id
  )
  values
    (
      transfer.branch_id, transfer.from_account_id, 'out', 'transfer',
      transfer.amount, 'cash', transfer.id,
      coalesce(nullif(transfer.notes, ''), 'Cash transfer out'), auth.uid()
    ),
    (
      transfer.branch_id, transfer.to_account_id, 'in', 'transfer',
      transfer.amount, 'cash', transfer.id,
      coalesce(nullif(transfer.notes, ''), 'Cash transfer in'), auth.uid()
    );

  update public.cash_transfers
     set status = 'approved', approved_by = auth.uid(), approved_at = now()
   where id = transfer.id;

  insert into public.audit_logs (
    branch_id, actor_id, action, entity_table, entity_id, details
  )
  values (
    transfer.branch_id, auth.uid(), 'cash.transfer.approve', 'cash_transfers',
    transfer.id, jsonb_build_object('amount', transfer.amount)
  );

  return jsonb_build_object('transfer_id', transfer.id, 'status', 'approved');
end;
$$;

create or replace view public.cash_flow_daily
with (security_invoker = true)
as
select
  branch_id,
  created_at::date as business_date,
  coalesce(sum(amount) filter (where direction = 'in'), 0) as cash_in,
  coalesce(sum(amount) filter (where direction = 'out'), 0) as cash_out,
  coalesce(sum(
    case when direction = 'in' then amount else -amount end
  ), 0) as net
from public.cash_transactions
group by branch_id, created_at::date;

revoke all on function public.approve_expense(uuid, boolean, text)
  from public, anon;
revoke all on function public.pay_bill(uuid, uuid, numeric, text, text)
  from public, anon;
revoke all on function public.approve_cash_transfer(uuid, boolean, text)
  from public, anon;
grant execute on function public.approve_expense(uuid, boolean, text)
  to authenticated;
grant execute on function public.pay_bill(uuid, uuid, numeric, text, text)
  to authenticated;
grant execute on function public.approve_cash_transfer(uuid, boolean, text)
  to authenticated;

comment on table public.bills is
  'Supplier and other payables. bill_payments are the only way to settle a bill so the paid amount stays consistent.';
