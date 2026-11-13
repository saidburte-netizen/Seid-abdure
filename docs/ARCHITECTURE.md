# Architecture

## Overview

```
Flutter client (Android, iOS, web, Windows, macOS, Linux)
        │  Supabase public key only
        ▼
Supabase Auth ── profiles ── branch_memberships ── roles ── role_permissions
        │
        ▼
Postgres (RLS + SECURITY DEFINER RPCs + views) ── private storage buckets
```

The Flutter app is a single responsive application with three role-derived
portal experiences:

- **Admin portal** — owner/admin roles: every module plus settings.
- **Manager portal** — manager/supervisor roles: operations and reports.
- **Team portal** — staff roles: only modules granted by their permissions.

The role label is derived from the selected branch membership. Access is always
checked again by the database; the UI is not the security boundary.

## Flutter layers

| Layer | Location | Responsibility |
| --- | --- | --- |
| Brand | `lib/brand/brand.dart` | Name, slogan and official logo asset constants. |
| Theme | `lib/theme/app_theme.dart` | The single green/cream/gold light and dark palette. |
| Auth | `lib/auth/auth_controller.dart` | Session, profile, branch memberships, permissions, locale and theme preferences. |
| Routing | `lib/app.dart` | Auth redirects, portal routes, permission guards, onboarding, claim-owner and error screens. |
| Data | `lib/data/` | Supabase repository, schema specs, formatting, CSV/PDF export, offline queue. |
| Widgets | `lib/widgets/` | Module scaffold, drawer, account menu, CRUD table, dialogs, payment dialog, shared states. |
| Screens | `lib/screens/` | Dashboard, POS, production, sales, inventory, cash, people, payroll, rentals, payables, reports, notifications, settings. |
| Localization | `lib/l10n/` | English, Amharic and Afaan Oromo ARB catalogs. |

### Routing and auth states

`AuthController` exposes `loading`, `signedOut`, `needsMembership`, `error` and
`ready`. `GoRouter` redirects to `/loading`, `/sign-in`, `/onboarding`,
`/auth-error` or the requested page. `/access-denied` is shown when a module
permission is missing, including direct URL navigation.

Routes:

```
/                     dashboard
/pos                  point of sale
/sales                sales, returns, customers
/production           batches and recipes
/inventory            stock, purchasing, suppliers
/cash                 accounts, expenses, bills, transfers, daily close
/people               employees, attendance, leave, shifts
/payroll              runs, payslips, advances, components
/rentals              properties, units, leases, invoices, maintenance
/payables             supplier payables, aging, suppliers
/reports              reporting and CSV/PDF export
/notifications        inbox and preferences
/settings             organization, branch, members, roles, numbering
```

`/module/:name` remains as a compatibility route used by dashboard cards.

### Data access

Reads use `BranchRepository` which always scopes queries by the selected
`branch_id` and lets RLS enforce access. Generic CRUD tables use `TableSpec`
descriptors so labels, lookups, number/date/boolean fields and permissions are
declared once. Every money, stock, credit, approval or multi-table operation
uses a database RPC instead of client-side writes.

## Database

Migrations live in `supabase/migrations/` and apply in timestamp order. Major
groups:

- Foundation: branches, roles, permissions, profiles, memberships, products,
  stores, inventory items, stock ledger, customers, sales, payments, cash
  accounts, audit logs.
- Organization: branch provisioning, settings, document sequences, RLS helpers.
- Catalog/production: recipes, recipe items, production batches and consumption.
- Inventory/purchasing: suppliers, purchase orders, goods receipts, counts,
  adjustments, transfers, stock views.
- Sales/POS: sales, sale items, receipts, returns, daily close, cash movement.
- Customers/credit: customer ledger, credit limit enforcement, customer
  payments, sale returns.
- Cash/expenses/bills: expenses, approvals, transfers, bills and payments.
- People/HR: employees, shifts, attendance, leave types/requests, salary setup.
- Payroll: settings, components, employee components, advances, runs, payslips,
  payslip lines and approval/payment.
- Rentals: properties, units, leases, invoices, payments, rent roll and
  maintenance.
- Payables: supplier bills, payments, aging, statements.
- Notifications: branch alerts, reads and user preferences.
- Reports: dashboard, sales, inventory, production, P&L, receivables, payables,
  rentals, payroll, supplier statement and full branch export.
- Storage/audit/offline: private buckets, audit trigger, offline sale inbox.
- RLS hardening and API grants: explicit policies and API-role privileges.

### Security model

- RLS is enabled on every public table and every table has at least one policy.
- `user_has_branch_access`, `has_permission`, `is_branch_admin` and
  `shares_branch_with` are the reusable RLS helpers.
- Roles are branch-scoped. Owner/admin bypasses granular permission checks;
  other roles require the exact permission key.
- Every `SECURITY DEFINER` function sets `search_path = public, pg_temp`,
  checks `auth.uid()`/permission and runs with `row_security = off` only inside
  the trusted function.
- `anon` has no table or function grants. `authenticated` receives explicit
  CRUD grants; RLS decides row visibility. `service_role` is for server jobs
  only and never ships in the Flutter app.
- Storage buckets are private and scoped through branch-aware policies.

### Idempotency and offline sales

`complete_sale` accepts a `p_client_id`. The unique constraint prevents a
duplicate sale when a client retries. `sync_offline_sale` records each queued
payload in `pos_sync_batches` with a unique `(branch_id, client_id)` key, then
calls `complete_sale`; repeated syncs return the original sale. Rejected
payloads retain the database error for review.

## Error handling

- Auth errors render a retry/sign-out screen.
- Module failures use `ErrorView` with a retry action.
- RPC failures are converted by `readableError` and shown in a snackbar/dialog.
- Money/stock/credit validation remains server-side; the client never
  calculates authoritative balances.
- Offline POS failure offers a local queue only for non-credit sales.
