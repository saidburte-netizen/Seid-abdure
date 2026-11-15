# SQL to run in Supabase

The owner confirmed this corrected function was applied in the Supabase SQL Editor on 2026-11-15. Keep this file as the source of truth and re-run it only for a fresh project, a restored database, or if the `void_sale` function is missing.

- Safe to run more than once: the function uses `create or replace`.
- It does **not** insert stock movements. The existing `trg_sales_void` trigger restores stock exactly once.
- It reverses cash payments, writes off linked receivables, posts the matching customer ledger credit, and records the reason.
- It rejects a sale that already has any return, so a partially returned sale cannot be voided.
- Execute is revoked from `public` and `anon`, and granted only to `authenticated`.

```sql
-- Void a completed sale and reverse the cash and credit it created.
--
-- The live schema snapshot does not expose a void_sale RPC even though the
-- Flutter app calls one. This migration adds the missing RPC without editing
-- the fifteen earlier migrations. It relies on the existing trg_sales_void
-- trigger to restore finished-goods stock exactly once and on trg_sales_audit
-- to record the status change. This function must never insert stock movements
-- itself, otherwise stock would be restored twice.

create or replace function public.void_sale(
  target_sale uuid,
  reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sale record;
  v_payment record;
  v_receivable record;
  v_category uuid;
  v_balance numeric;
begin
  if auth.uid() is not null
     and not public.has_any_role(
       array['admin', 'manager', 'accountant', 'cashier']
     ) then
    raise exception 'You do not have permission to void sales.';
  end if;

  select * into v_sale
  from public.sales
  where id = target_sale
  for update;

  if not found then
    raise exception 'Sale not found.';
  end if;

  if v_sale.status = 'void' then
    raise exception 'This sale has already been voided.';
  end if;

  if v_sale.status <> 'completed' then
    raise exception 'Only completed sales can be voided.';
  end if;

  if exists (
    select 1 from public.sale_returns where sale_id = target_sale
  ) then
    raise exception 'This sale already has returns and cannot be voided.';
  end if;

  -- Reverse cash received directly against the sale.
  for v_payment in
    select id, cash_account_id, amount, method
    from public.sale_payments
    where sale_id = target_sale
      and method <> 'credit'
      and cash_account_id is not null
  loop
    select category_id into v_category
    from public.cash_transactions
    where reference_type = 'sale_payment'
      and reference_id = v_payment.id
    limit 1;

    insert into public.cash_transactions (
      branch_id, cash_account_id, txn_type, category_id, amount, txn_date,
      description, method, reference_type, reference_id, created_by
    ) values (
      v_sale.branch_id, v_payment.cash_account_id, 'out', v_category,
      v_payment.amount, current_date,
      'Void sale ' || v_sale.receipt_no, v_payment.method,
      'sale_void', target_sale, auth.uid()
    );
  end loop;

  -- Reverse customer credit and refund any credit payments already received.
  for v_receivable in
    select id, customer_id, amount, paid_amount
    from public.receivables
    where sale_id = target_sale
      and status in ('open', 'partial', 'paid')
    for update
  loop
    for v_payment in
      select id, cash_account_id, amount, method
      from public.receivable_payments
      where receivable_id = v_receivable.id
        and cash_account_id is not null
    loop
      select category_id into v_category
      from public.cash_transactions
      where reference_type = 'receivable_payment'
        and reference_id = v_payment.id
      limit 1;

      insert into public.cash_transactions (
        branch_id, cash_account_id, txn_type, category_id, amount, txn_date,
        description, method, reference_type, reference_id, created_by
      ) values (
        v_sale.branch_id, v_payment.cash_account_id, 'out', v_category,
        v_payment.amount, current_date,
        'Refund for void sale ' || v_sale.receipt_no, v_payment.method,
        'sale_void', target_sale, auth.uid()
      );
    end loop;

    v_balance := v_receivable.amount - v_receivable.paid_amount;

    update public.receivables
    set paid_amount = v_receivable.amount,
        status = 'written_off'
    where id = v_receivable.id;

    if v_balance > 0 then
      insert into public.ledger_entries (
        party_type, customer_id, description, credit,
        reference_type, reference_id
      ) values (
        'customer', v_receivable.customer_id,
        'Void sale ' || v_sale.receipt_no, v_balance,
        'sale_void', target_sale
      );
    end if;
  end loop;

  update public.sales
  set status = 'void',
      payment_status = 'refunded',
      notes = concat_ws(
        E'\n',
        notes,
        nullif('Void reason: ' || coalesce(reason, ''), 'Void reason: ')
      ),
      updated_at = now()
  where id = target_sale;
end;
$$;

revoke all on function public.void_sale(uuid, text) from public;
revoke all on function public.void_sale(uuid, text) from anon;
grant execute on function public.void_sale(uuid, text) to authenticated;
```
