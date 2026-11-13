# Security

## Authentication and authorization

- Supabase Auth is the only identity provider. Signup is disabled in
  `supabase/config.toml`; users are created by an administrator.
- A database trigger creates a profile and notification preferences for each
  auth user.
- Branch membership is the authorization unit. Roles are branch-scoped and
  carry granular permission keys.
- The first authenticated user may call `bootstrap_first_owner()` only while no
  active membership exists. The function creates the organization branch,
  owner role and membership atomically. Later calls fail.
- Administrators add members by email through `assign_branch_membership`, which
  requires `settings.manage` and only accepts roles belonging to that branch.

## Row-level security

RLS is enabled on all public tables. `public.rls_coverage` is the operational
view used by tests and audit queries:

```sql
select * from public.rls_coverage
where not rls_enabled or policy_count = 0;
```

The query must return zero rows. Branch data is filtered through
`user_has_branch_access(branch_id)` or an equivalent ownership/role check.
Profiles are visible only to the owner or users who share a branch.

## Server-side writes

All sensitive operations are RPCs:

- Sales: `complete_sale`, `process_sale_return`, `void_sale`, `close_business_day`.
- Stock: `receive_purchase_order`, `complete_production_batch`,
  `approve_stock_adjustment`, `approve_stock_count`, `complete_stock_transfer`.
- Credit: `record_customer_payment`, `enforce_customer_credit_limit`.
- Cash: `approve_expense`, `approve_cash_transfer`, `pay_bill`, `void_bill`.
- HR/payroll: `review_leave_request`, `run_payroll`, `approve_payroll`.
- Rentals: `generate_rent_invoices`, `record_rent_payment`.
- Payables: `record_supplier_payment`, `supplier_statement`.
- Notifications: `refresh_branch_alerts`.
- Reports: `report_*`, `export_branch_data`.
- Offline: `sync_offline_sale`.

Each function checks permission and derives branch ownership from the record
where possible; client-supplied branch IDs are validated. Every function has a
fixed `search_path`. Client-supplied prices are ignored: the server reloads
catalog prices before calculating totals.

## API grants

`20261113170000_api_grants.sql` explicitly grants schema/table/function access
to `authenticated` and `service_role`, revokes `anon`, and sets default
privileges for future migrations. This prevents a project from accidentally
depending on dashboard defaults. RLS still filters rows.

## Secrets

- Only `SUPABASE_URL` and a public publishable/anon key are compiled into the
  client.
- A service-role key, JWT secret, database password, Android signing key and
  GitHub token must never be committed or embedded in the app.
- Rotate any credential that was pasted into a terminal, issue, chat or commit.
- Use GitHub Actions secrets and platform environment configuration.

## Storage

Buckets are private. Object paths begin with the branch UUID and policies check
`storage_branch_id(name)` against the caller's memberships. Public URLs are not
used for business documents.

## Audit logging

`audit_logs` records actor, branch, action, entity and details for sensitive
workflows. The generic `audit_row_change` trigger covers configured tables.
Audit rows are append-only through RLS; deletion is not exposed to normal users.

## Residual security work

- Review payroll tax and statutory deduction defaults with an Ethiopian
  accountant before production use.
- Configure Supabase Auth rate limits, SMTP and MFA for the production project.
- Enable point-in-time recovery and encrypted backups in the Supabase plan.
- Run dependency and container scanning in the deployment pipeline.
