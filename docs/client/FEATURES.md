# Brade and Cake House — Feature Guide

Release: **v1.0.8**
Platforms: Android (sideload APK/AAB), web admin portal
Languages: English, Amharic (አማርኛ), Afaan Oromoo

This document lists what the app actually does in this release. A feature is
listed only if it is wired to a screen and a database table or RPC. Anything
still missing is listed under **Not included** rather than promised.

## Roles

The app reads the signed-in user's role from the database and shows only the
modules that role may use.

| Role code | Typical user | Main access |
| --- | --- | --- |
| `admin` | Owner / system administrator | Everything, including users, roles, business settings and audit log |
| `manager` | Branch manager | Sales, production, inventory, cash, HR, payroll, rentals, credit, approvals, reports |
| `cashier` | Counter staff | New sale, sales list and returns, own shift cash |
| `baker` | Kitchen staff | Production batches and recipes |
| `store_keeper` | Store keeper | Inventory, stock counts, stock movements, suppliers |
| `hr_officer` | HR officer | People & HR, attendance, leave, payroll preparation |
| `accountant` | Accountant | Cash, expenses, credit, payroll approval, reports |
| `staff` | General staff | Own profile and own attendance |
| `customer` | Wholesale/retail customer | Own profile and the active product catalogue |

A user with more than one branch gets a branch selector in the navigation
drawer. All lists and writes are limited to the selected branch by database
row-level security, not only by the app.

## Modules

| Module | Route | What it does |
| --- | --- | --- |
| Dashboard | `/` | Branch KPIs, quick actions and today's activity |
| New sale (POS) | `/pos` | Product search, cart, discount, split payment, credit sale, receipt |
| Sales & returns | `/sales` | Sale history, sale detail, void with reason, returns and refunds |
| Production | `/production` | Batches, recipe consumption, completion and stock posting |
| Inventory | `/inventory` | Items, stock by store, stock counts, transfers, adjustments |
| Cash & expenses | `/cash` | Cash accounts, receipts, payments, transfers, expense claims, daily close |
| People & HR | `/people` | Employees, attendance, leave, shifts, departments |
| Payroll | `/payroll` | Payroll runs, payslip generation, approval, payment status |
| Rentals | `/rentals` | Properties, tenants, leases, rent invoice generation and payments |
| Credit control | `/credit` | Customer credit limits, receivables, aging and payments |
| Approvals | `/approvals` | Expense and stock-count approvals |
| Reports | `/reports` | Sales, stock, cash, payroll, rent and credit summaries |
| Notifications | `/notifications` | Low-stock, overdue-rent and other generated alerts |
| Settings | `/settings` | Profile, security, business settings, branches, accounts, users, roles, master data, audit log, exports, storage, branding, help, privacy |

### Sale and money rules

- Money is rounded per line, and the sum of line totals always equals the sale
  total (see `lib/data/sale_math.dart` and `test/money_precision_test.dart`).
- The database owns sale totals, stock movement, cash posting and refund cash.
  The app sends items and payments; triggers and RPCs do the accounting.
- A sale can be voided only with a reason, and only by a role allowed to do so.
  Voiding restores stock through the database trigger.
- A return must reference an existing sale line; refund cash and stock
  restoration are performed by database triggers.
- A credit sale is limited by the customer's credit limit in the database.

### Stock rules

- Stock counts move through `draft` → `completed` or `cancelled`.
- Only a completed count is applied to stock.
- Transfers and production consumption post stock movements through database
  functions, so the app cannot post a partial movement.

### Exports

- Every list has **CSV** and **PDF** export.
- CSV fields that start with `=`, `+`, `-`, `@`, tab or carriage return are
  quoted so spreadsheet software does not execute them as formulas.
- Exports page through the table until every row is fetched, so a report can
  contain more than the 1,000 rows PostgREST returns in one response.

## Security and sessions

- Sign-in uses Supabase email/password authentication.
- The app must sign in before any table is readable; anonymous callers can only
  call the two login helpers `has_admin()` and `customer_signup_allowed()`.
- The session token is stored in the platform secure store (Android Keystore /
  iOS Keychain), not in plain-text preferences. A one-time migration moves any
  old plain-text session and deletes the copy.
- 30 minutes without interaction signs the user out. Returning to the app after
  a longer absence signs out immediately.
- Login is robust: if `has_admin()` or `customer_signup_allowed()` fails or
  returns nothing, the normal sign-in form is shown, create-account options are
  hidden, and no raw error is displayed.
- Android backup is disabled, cleartext traffic is disabled, release builds are
  minified/shrunk with R8 and built with Dart obfuscation.

## Languages

English, Amharic and Afaan Oromoo are available on the sign-in screen and in
Settings. Changing the language updates the interface immediately; the choice
is remembered on the device.

## Offline behavior

- The app shows a banner when the device is offline and retries reads when the
  connection returns.
- **Writes are not queued.** A sale, payment or edit needs a working connection.
  If a write fails, the app shows a friendly "not saved" message and the user
  must retry; nothing is silently stored for later.
- Reads time out after 20 seconds and retry once; writes are never retried
  automatically, which prevents duplicate sales or payments.

## Not included in v1.0.8

| Not included | Detail |
| --- | --- |
| Offline write queue | Writes require connectivity; there is no local sync queue. |
| Barcode scanning | Products are found by search, not by camera scanning. |
| Multi-factor authentication | Not available in this release. |
| Self-service password reset | An administrator resets the password. |
| Screenshot protection on payroll | Not enabled; device policy can cover this. |
| Push notifications | Alerts appear in the in-app Notifications screen. |
