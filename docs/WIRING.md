# Wiring map and integration-test plan

This document is the category-by-category contract between the Flutter UI and
the live Supabase project. The live project is authoritative; the legacy SQL in
`supabase/legacy_migrations/` is not replayed. `tool/check_schema.py` enforces
the names used by Dart code.

## Shared wiring

| Layer | Responsibility |
| --- | --- |
| `AuthController` | session, profile, role, branch list, selected branch, permissions, theme and locale |
| `SessionScope` | exposes the signed-in controller to every screen |
| `SupabaseClient` | PostgREST reads/writes and RPC calls |
| `ModuleScaffold` / `AppScaffold` | green hero, Back arrow, drawer, branch selector, notifications |
| `CrudTab` + `tableSpecs` | generic list/create/edit/delete screens driven by the live-schema snapshot |
| Database triggers | stock movements, cash balances, ledgers, receivables/payables, revenue, payslip totals, audit |
| Database RPCs | multi-row operations that must be atomic (sale completion, returns, payroll, rent invoices, alerts) |

The app inserts primary records only. It never writes derived balances or
ledger rows directly; those are owned by the database triggers/RPCs.

## Category wiring

| Category | Screens / routes | Primary objects | RPCs | Trigger/RPC-owned effects | Permission gate |
| --- | --- | --- | --- | --- | --- |
| Dashboard | `/` | `v_dashboard_kpis`, `cake_orders`, `customers`, `receivables` | `fn_generate_alerts` | alert refresh | signed-in |
| POS & sales | `/pos`, `/sales` | `sales`, `sale_items`, `sale_payments`, `cash_transactions`, `sale_returns`, `sale_return_items` | live sale/return/void RPCs | stock movement, cash, revenue, customer ledger, receivables | `sales.create`, `sales.void` |
| Production | `/production` | `production_batches`, `cake_orders` | production completion RPC | ingredient consumption, finished stock | `production.manage` |
| Inventory & purchasing | `/inventory` | `purchase_orders`, `purchase_order_items`, `goods_receipts`, `goods_receipt_items`, `stock_counts`, `stock_count_items`, `stock_transfers` | receipt/adjustment/transfer/count RPCs | stock movement and stock balances | `inventory.manage`, `purchasing.manage` |
| Cash, expenses & payables | `/cash` | `cash_accounts`, `cash_transactions`, `cash_transfers`, `expenses`, `bills`, `payables`, `payable_payments` | expense/payable/cash-transfer RPCs | cash balance, supplier payable, cash-flow view | `cash.manage`, `expenses.manage`, `payables.manage` |
| Customers & credit | `/credit` | `customers`, `receivables`, `receivable_payments`, `write_offs` | customer payment/credit RPCs | customer ledger, receivable balance, credit-limit guard | `credit.manage` |
| People & HR | `/people` | `employees`, `employee_shifts`, `attendance`, `leave_requests`, `leave_types` | leave review RPC | attendance/payroll inputs | `hr.manage` |
| Payroll | `/payroll` | `payroll_runs`, `payslips`, `payslip_lines`, `employees` | payroll run/approve RPCs | gross/net totals, payslip lines, ledger | `payroll.manage` |
| Rentals | `/rentals` | `properties`, `units`, `leases`, `rent_invoices`, `rent_payments`, `maintenance_requests` | rent-invoice and rent-payment RPCs | rent status, receivables | `rentals.manage` |
| Notifications | `/notifications` | `notifications`, `notification_settings` | `fn_generate_alerts` | read state and alert generation | signed-in |
| Reports | `/reports` | reporting views and RPCs | report RPCs | read-only | `reports.view` |
| Settings | `/settings/**` | `app_settings`, `branches`, `profiles`, `roles`, `permissions`, `role_permissions`, `audit_logs`, storage `avatars` | `has_admin`, `fn_generate_alerts` | profile/role changes, audit | signed-in; admin sections gated in UI |
| Approvals | `/approvals` | `approvals` | approval decision RPCs | entity-specific side effects | `approvals.manage` |

## Integration-test matrix

Run these against a disposable Supabase project or a local stack seeded from a
live-schema dump. They are not run against the legacy migrations because those
files describe an older schema.

| # | Scenario | Expected evidence |
| --- | --- | --- |
| 1 | Sign in as admin, switch branch | branch selector changes scoped data; no cross-branch rows |
| 2 | Create product, receive purchase order | `stock_movements` row, `stock_balances` increases |
| 3 | Complete a sale with two payment methods | sale/receipt totals, cash balance, customer ledger and receivable update atomically |
| 4 | Void a completed sale | stock and cash reverse, audit row written, status becomes `voided` |
| 5 | Process a sale return | return lines, stock restored, receivable/refund balanced |
| 6 | Record customer payment | receivable decreases, ledger row written, credit limit recalculated |
| 7 | Create expense and pay a bill | cash balance decreases, payable settles, cash-flow view updates |
| 8 | Run and approve payroll | payslip gross/net totals match components; ledger is balanced |
| 9 | Generate rent invoices | one invoice per active lease, duplicate run is idempotent |
| 10 | Generate alerts | notification rows created once per condition, read state survives refresh |
| 11 | Role/permission change | hidden routes and actions match `role_permissions`; direct navigation shows access denied |
| 12 | RLS probes | anon cannot read protected tables; staff cannot cross branches; admin can manage |
| 13 | Offline sign-in | friendly offline message, no technical exception text |
| 14 | Language switch | en/am/om update live without restart; no English leakage in am/om |

## Local stack note

`supabase/config.toml` and the legacy migrations can start a local stack, but
that stack does **not** match the live project. A local integration run is only
meaningful after restoring a live-schema dump:

```bash
# On a disposable project, never the production project:
supabase db dump --schema public --data-only=false > /tmp/live-schema.sql
supabase start
supabase db reset --db-url "$LOCAL_DB_URL"   # or psql -f /tmp/live-schema.sql
```

Until that dump is committed or generated in CI, the Flutter widget/static
suite is the executable gate and the matrix above is the required acceptance
checklist for the next environment that has the live schema.
