-- 20261115000002_ethiopian_date_defaults.sql
--
-- Make database-generated business dates use Africa/Addis_Ababa (UTC+3)
-- instead of the database session timezone (UTC on Supabase).
--
-- Safe to run more than once. It changes defaults and function settings only;
-- it does not rewrite existing rows.
--
-- Apply after 20261115000001_security_hardening.sql.

begin;

-- Date columns that used CURRENT_DATE (UTC) now use the Ethiopian date.
alter table public.attendance alter column work_date
  set default ((now() at time zone 'Africa/Addis_Ababa')::date);
alter table public.bills alter column bill_date
  set default ((now() at time zone 'Africa/Addis_Ababa')::date);
alter table public.cash_transactions alter column txn_date
  set default ((now() at time zone 'Africa/Addis_Ababa')::date);
alter table public.cash_transfers alter column transfer_date
  set default ((now() at time zone 'Africa/Addis_Ababa')::date);
alter table public.daily_closings alter column closing_date
  set default ((now() at time zone 'Africa/Addis_Ababa')::date);
alter table public.employee_advances alter column advance_date
  set default ((now() at time zone 'Africa/Addis_Ababa')::date);
alter table public.employees alter column hire_date
  set default ((now() at time zone 'Africa/Addis_Ababa')::date);
alter table public.goods_receipts alter column received_date
  set default ((now() at time zone 'Africa/Addis_Ababa')::date);
alter table public.hr_notes alter column note_date
  set default ((now() at time zone 'Africa/Addis_Ababa')::date);
alter table public.ledger_entries alter column entry_date
  set default ((now() at time zone 'Africa/Addis_Ababa')::date);
alter table public.maintenance_requests alter column reported_date
  set default ((now() at time zone 'Africa/Addis_Ababa')::date);
alter table public.payable_payments alter column payment_date
  set default ((now() at time zone 'Africa/Addis_Ababa')::date);
alter table public.production_batches alter column production_date
  set default ((now() at time zone 'Africa/Addis_Ababa')::date);
alter table public.purchase_orders alter column order_date
  set default ((now() at time zone 'Africa/Addis_Ababa')::date);
alter table public.receivable_payments alter column payment_date
  set default ((now() at time zone 'Africa/Addis_Ababa')::date);
alter table public.rent_payments alter column payment_date
  set default ((now() at time zone 'Africa/Addis_Ababa')::date);
alter table public.stock_counts alter column count_date
  set default ((now() at time zone 'Africa/Addis_Ababa')::date);

-- Trigger and RPC bodies that call CURRENT_DATE now evaluate it in Ethiopian
-- time. Their search_path setting is preserved.
alter function public.fn_sale_payment_apply()
  set timezone = 'Africa/Addis_Ababa';
alter function public.fn_generate_alerts()
  set timezone = 'Africa/Addis_Ababa';
alter function public.fn_generate_rent_invoices(date)
  set timezone = 'Africa/Addis_Ababa';
alter function public.void_sale(uuid, text)
  set timezone = 'Africa/Addis_Ababa';

commit;
