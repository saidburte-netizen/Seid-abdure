# Testing

## Automated

```sh
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
```

`flutter analyze` must report no issues. Widget tests verify the branded
configuration screen and brand constants. Add widget tests for each new screen
and unit tests for formatting/export logic.

Database:

```sh
supabase start
supabase db reset
supabase test db
```

`supabase/tests/database/initial_foundation.test.sql` and
`operational_modules.test.sql` use pgTAP to check core tables/views/functions,
RLS on every public table, policy coverage and the permission catalog.

## Manual end-to-end RPC smoke test

Use a disposable local database with the Supabase Auth/storage stubs, then run
the script below with `psql`. It is wrapped in `begin/rollback` so it leaves no
data. It verifies owner bootstrap, POS sale, return, rent invoice/payment,
payroll run/approval, alerts and dashboard reporting.

```sql
begin;
insert into auth.users (email) values ('owner@example.com') returning id as owner \gset
select set_config('request.jwt.claim.sub', :'owner', true);
set local role authenticated;
select public.bootstrap_first_owner() as bootstrap \gset
select :'bootstrap'::jsonb->>'branch_id' as branch \gset
reset role;
-- seed store, inventory item, product, cash account and customer here
-- then call complete_sale, process_sale_return, generate_rent_invoices,
-- record_rent_payment, run_payroll, approve_payroll, refresh_branch_alerts
-- and report_dashboard; assert row counts before rollback.
rollback;
```

The full executable script is kept outside source control because it depends on
the local Auth stubs. Recreate it from the function signatures in
`supabase/migrations/`.

## RLS isolation check

Create a second Auth user with no membership and set their claim. The following
must hold:

```sql
select public.has_permission('<branch>', 'sales.write'); -- false
select count(*) from public.branches;                    -- 0
select count(*) from public.branch_memberships;          -- 0
select count(*) from public.profiles;                    -- 1 (own profile only)
```

## Build checks

```sh
flutter build web --release
flutter build apk --release
flutter build appbundle --release
```

On an arm64 development host whose Flutter SDK lacks the `const_finder`
snapshot, use `flutter build web --release --no-tree-shake-icons`; CI on x64
runs the normal command.

## Release checklist

- [ ] Analyze/test/build green.
- [ ] Migrations reset cleanly.
- [ ] pgTAP passes.
- [ ] RLS coverage query returns zero rows.
- [ ] Owner claim tested once on a fresh project.
- [ ] Staff membership and permission denial tested.
- [ ] Cash close, payroll and rent cycle smoke-tested.
- [ ] Receipt/invoice/payslip PDF branding inspected.
- [ ] Launcher icon, splash, notification icon and platform names inspected.
- [ ] Backups enabled and restore tested.
