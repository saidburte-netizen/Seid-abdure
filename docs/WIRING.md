# Wiring map and integration-test plan

This document is the category-by-category contract between the Flutter UI and
the live Supabase project. The live project is authoritative. The fifteen
uploaded `20261114000001`–`20261114000015` migrations are the intended source
of truth; the only added migration is the later
`20261114000016_void_sale.sql`. `tool/check_schema.py` enforces the names used
by Dart code.

## Shared wiring

| Layer | Responsibility |
| --- | --- |
| `AuthController` | session, profile, role, branch list, selected branch, permissions, theme and locale |
| `SessionScope` | exposes the signed-in controller to every screen |
| `SupabaseClient` | PostgREST reads/writes and RPC calls |
| `ModuleScaffold` / `AppScaffold` | green hero, Back arrow, drawer, branch selector, notifications |
| `CrudTab` + `tableSpecs` | generic list/create/edit/delete screens driven by the live-schema snapshot |
| `BranchRepository` | branch-scoped reads and branch-filled writes |
| Database triggers | stock movements, cash balances, ledgers, receivables/payables, revenue, payslip totals, audit |
| Database RPCs | multi-row operations that must be atomic (close day, void sale, payroll, rent invoices, alerts) |

The app inserts primary records only. It never writes derived balances or
ledger rows directly; those are owned by the database triggers/RPCs.

## Category wiring

| Category | Screens / routes | Primary objects | RPCs | Trigger/RPC-owned effects | Permission gate |
| --- | --- | --- | --- | --- | --- |
| Dashboard | `/` | `v_dashboard_kpis`, `cake_orders`, `customers`, `receivables` | `fn_generate_alerts` | alert refresh | signed-in |
| POS & sales | `/pos`, `/sales` | `sales`, `sale_items`, `sale_payments`, `cash_transactions`, `sale_returns`, `sale_return_items` | `void_sale`, `fn_close_day`, `next_number` | stock movement, cash, customer ledger, receivables, audit | `sales.create`, `sales.void` |
| Production | `/production` | `production_batches`, `cake_orders`, `recipes`, `recipe_items`, `stock_movements` | `next_number` | ingredient consumption, finished stock | `production.manage` |
| Inventory & purchasing | `/inventory` | `purchase_orders`, `purchase_order_items`, `goods_receipts`, `goods_receipt_items`, `stock_counts`, `stock_count_items`, `stock_transfers`, `stock_levels`, `stock_movements` | `next_number` | stock movement and stock balances | `inventory.manage`, `purchasing.manage` |
| Cash, expenses & payables | `/cash` | `cash_accounts`, `cash_transactions`, `cash_transfers`, `expense_categories`, `bills`, `payables`, `payable_payments` | `next_number` | cash balance, supplier payable, cash-flow view | `cash.manage`, `expenses.manage`, `payables.manage` |
| Customers & credit | `/credit` | `customers`, `receivables`, `receivable_payments`, `write_offs`, `ledger_entries` | `next_number` | customer ledger, receivable balance, credit-limit guard | `credit.manage` |
| People & HR | `/people` | `employees`, `employee_shifts`, `attendance`, `leave_requests`, `leave_types`, `employee_advances`, `employee_documents`, `hr_notes` | — | attendance/payroll inputs | `hr.manage` |
| Payroll | `/payroll` | `payroll_runs`, `payslips`, `employees`, `employee_advances` | `fn_generate_payroll` | gross/net totals, payslip payment, advance settlement, cash transaction | `payroll.manage` |
| Rentals | `/rentals` | `properties`, `units`, `leases`, `rent_invoices`, `rent_payments`, `maintenance_requests` | `fn_generate_rent_invoices` | rent status, cash transaction | `rentals.manage` |
| Notifications | `/notifications` | `notifications`, `notification_settings` | `fn_generate_alerts` | read state and alert generation | signed-in |
| Reports | `/reports` | `v_dashboard_kpis`, `v_daily_sales`, `v_product_sales`, `v_stock_valuation`, `v_receivable_aging`, `v_payable_aging`, `v_rent_status`, `v_payroll_summary`, `v_expense_summary`, `v_customer_balances`, `v_supplier_balances` | — | read-only | `reports.view` |
| Settings | `/settings/**` | `app_settings`, `branches`, `profiles`, `roles`, `permissions`, `role_permissions`, `audit_logs`, storage `avatars` | `has_admin`, `customer_signup_allowed` | profile/role changes, audit | signed-in; admin sections gated in UI |
| Approvals | `/approvals` | `approvals`, `write_offs` | — | write-off approval closes the receivable and posts a ledger credit | `approvals.manage` |

## Integration-test matrix

The executable evidence is split between the Flutter suite and the local
Supabase contract. The contract is
`supabase/tests/integration/contract.sql`; it wraps everything in a transaction
and rolls back. The workflow is `.github/workflows/supabase-integration.yml`.

| # | Scenario | Automated evidence |
| --- | --- | --- |
| 1 | Sign in as admin, switch branch | `test/branch_repository_test.dart` proves every read carries `branch_id=eq.<selected>` and every insert fills `branch_id`; route tests prove admin/manager/staff screens build |
| 2 | Create product, receive purchase order | contract: PO totals, receipt stock movement, PO item quantity and `received` status |
| 3 | Complete a sale with two payment methods | contract: cash sale, credit sale and split cash+bank sale; two `sale_payment` cash transactions and paid status |
| 4 | Void a completed sale | contract: `void_sale` restores stock exactly once, reverses cash, writes audit, sets `void`/`refunded`, rejects a second void, and reverses a credit receivable/ledger |
| 5 | Process a sale return | contract: return line restores stock, refunds cash, sets sale `returned` |
| 6 | Record customer payment | contract: receivable partial balance, customer-ledger credit and cash transaction |
| 7 | Create expense and pay a bill | contract: expense cash-out and `v_expense_summary`; bill audit, paid status and bill-payment cash-out |
| 8 | Run and approve payroll | contract: payslip gross/net, run totals, approval, payment, `is_paid`, and cash transaction |
| 9 | Generate rent invoices | contract: one invoice per lease, duplicate run idempotent, rent payment settles invoice and posts cash |
| 10 | Generate alerts | contract: low-stock and rent-due notifications created once |
| 11 | Role/permission change | contract: customer `products.view` removal/restoration; route tests prove permission-gated screens |
| 12 | RLS probes | contract: anon, admin, manager, cashier, baker, store keeper, HR, accountant, staff and customer visibility, profile self-update guard, avatar own-folder policy |
| 13 | Offline sign-in | `test/airplane_mode_login_test.dart` and `test/airplane_mode_evidence_test.dart` show friendly offline text, no raw exception |
| 14 | Language switch | `test/all_routes_localization_test.dart` switches en→am→om→en on the sign-in screen; Android emulator smoke repeats it on the release APK and uploads screenshots |

Additional contract checks cover stock counts, production, cash transfers,
payables, stock transfers, write-offs, approvals, `next_number`, audit logs,
translation columns, RLS enablement and the avatars bucket policies.

## Local stack note

The 15 uploaded migrations are not present in this checkout. When they are
present, the workflow runs them directly. Otherwise the workflow starts a
disposable local Supabase stack, applies the read-only
`supabase/fixtures/live_schema.sql` snapshot, then applies
`supabase/migrations/20261114000016_void_sale.sql`. The fixture is schema-only
and must never be applied to the hosted project. The workflow never uses the
hosted project or the `service_role` key.
