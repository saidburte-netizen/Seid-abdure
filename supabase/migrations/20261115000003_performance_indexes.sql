-- 20261115000003_performance_indexes.sql
--
-- Composite indexes for the main list, dashboard and aging queries.
-- Safe to run more than once.
--
-- Apply after 20261115000002_ethiopian_date_defaults.sql.

begin;

create index if not exists idx_sales_branch_date
  on public.sales (branch_id, sale_date desc);

create index if not exists idx_cash_txn_branch_date
  on public.cash_transactions (branch_id, txn_date desc);

create index if not exists idx_receivables_status_due
  on public.receivables (status, due_date);

create index if not exists idx_payables_status_due
  on public.payables (status, due_date);

create index if not exists idx_rent_invoices_status_due
  on public.rent_invoices (status, due_date);

create index if not exists idx_bills_status_due
  on public.bills (status, due_date);

create index if not exists idx_ledger_customer_date
  on public.ledger_entries (customer_id, entry_date desc);

create index if not exists idx_ledger_supplier_date
  on public.ledger_entries (supplier_id, entry_date desc);

create index if not exists idx_sale_items_sale_product
  on public.sale_items (sale_id, product_id);

commit;
