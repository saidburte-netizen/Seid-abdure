# Brade and Cake House

**hani brade and cake**

A complete Flutter + Supabase management system for the Brade and Cake House
bakery, shop and rental business. The app uses the official green, cream and
gold brand identity and ships English, Amharic and Afaan Oromo interfaces.

## What is included

- Responsive Admin, Manager and Team portals selected from the signed-in role.
- Point of sale with product search, cart, discounts, tax/service charge,
  cash/mobile-money/bank/credit payments, receipts, returns and offline queue.
- Production batches, recipes, stock ledger, stock counts, adjustments,
  transfers, purchasing, goods receipts and supplier bills.
- Customers, credit limits, receivables, statements and customer payments.
- Cash accounts, expenses, transfers, bills, daily business close and variance.
- Employees, shifts, attendance, leave, salary components, payroll runs,
  payslips, advances and approval/payment.
- Properties, units, leases, rent invoices, rent payments, rent roll and
  maintenance requests.
- Supplier payables, aging, statements and payments.
- Notifications, read state, preferences and branch alert refresh.
- Dashboard, sales, inventory, production, P&L, receivables, payables, rentals,
  payroll and full-branch export reports with CSV and branded PDF output.
- Supabase Auth, branch-scoped roles/permissions, row-level security, audit
  logging, private storage policies and idempotent offline-sale ingestion.
- Branded launcher icons, Android adaptive/monochrome notification icons,
  native light/dark splash screens, web/PWA metadata and desktop titles.

See [docs/PLAN.md](docs/PLAN.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md),
[docs/SECURITY.md](docs/SECURITY.md), [docs/RUNBOOK.md](docs/RUNBOOK.md),
[docs/REPORTING.md](docs/REPORTING.md) and [docs/BRANDING.md](docs/BRANDING.md).

## Requirements

- Flutter stable 3.35+ and Dart 3.9+
- Supabase CLI and Docker for a local database
- A Supabase project for deployed environments

## Local development

```sh
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-public-key
```

`SUPABASE_ANON_KEY` is also accepted for older projects. Only a public
publishable/anon key belongs in the client; never put a service-role key in the
Flutter app or repository.

Local database:

```sh
supabase start
supabase db reset
supabase test db
```

## First-run setup

1. Create the first user in Supabase Auth.
2. Sign in to the app. The onboarding screen offers **Claim owner account**
   when no active membership exists yet. This creates the organization, the
   first branch and the owner role.
3. Add additional users in Supabase Auth, then add them under
   **Settings → Members** with a branch role.
4. Configure organization details, branch prefixes, tax/service rates,
   numbering and notification preferences.

## Testing

```sh
flutter analyze                 # must be clean
flutter test                    # widget and brand tests
supabase test db                # pgTAP schema, RLS and RPC coverage
```

A local end-to-end RPC smoke script is documented in
[docs/TESTING.md](docs/TESTING.md). It exercises owner bootstrap, a POS sale,
a return, rent invoicing/payment, payroll approval, alerts and dashboard
reporting against a disposable transaction.

## CI/CD

- `.github/workflows/ci.yml` runs formatting, analysis, tests and a web build,
  then resets the database and runs pgTAP.
- `.github/workflows/build-web.yml` and `build-android.yml` publish artifacts
  on `v*` tags or manual dispatch.
- No signing keys, service-role keys or deployment credentials are committed.
  Configure them as GitHub Actions secrets and environment configuration.

## Security

Row-level security is enabled on every public table and every table has at
least one policy. All money, stock, credit and workflow writes go through
`SECURITY DEFINER` RPCs with explicit permission checks and a fixed
`search_path`. The client only receives the public API key.

If a GitHub token or other secret was ever pasted into a terminal, issue
tracker or commit, revoke/rotate it immediately. The repository remote must not
contain a plaintext token; use a credential helper or GitHub CLI login.
