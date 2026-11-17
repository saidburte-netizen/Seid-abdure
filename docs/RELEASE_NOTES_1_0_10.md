# Release notes — 1.0.12+12 (branch `fix/saving-hang`, rebased onto current `main`)

## Verified in this branch

- The shared `SaveFlow.write` boundary now has a 25-second timeout, a friendly
  retry message, timestamped admin diagnostics breadcrumbs, an always-released
  busy flag, and leaves the dialog open on failure.
- A background/resume restore never destroys an open dialog or pending save.
  After process death, the app returns to the screen and clearly says the entry
  was **not saved**.
- Minimum-field saves were generated from the real repository payload rules and
  executed against the disposable contract database. Result: 45 forms as admin
  with 45 PASS / 0 SQLSTATE; the same 45 forms as a normal manager with 38 PASS
  and 7 expected SQLSTATE `42501` results on admin/HR-only forms. No other
  SQLSTATE was accepted.
- Screen-by-screen minimal saves printed `SCREEN SAVE | role | screen | action |
  fields sent | PASS/SQLSTATE | friendly message` for every create-capable form.
- Products, POS, Stock, Rentals payment flow, HR quick actions, dashboard Stock
  and Cashflow cards, localization, and admin Diagnostics are covered by widget
  and contract tests.
- UI screenshots for the `ui-screenshots` CI artefact were generated at
  360x800 in light English, including Home/Dashboard, Cash, Products, New sale,
  Stock, Rentals invoices, Rentals payment form, HR employee form and Settings.
- All gates passed locally in the required order: format, format check,
  `flutter analyze` (no issues), `flutter test` (301 tests), placeholder check,
  schema check, SQL contract with real RLS, and drift test.

## Database changes

- No new migration changes data or schema. The only added migration file,
  `20261117000000_dashboard_stock_views.sql`, records views that are already
  live so the disposable contract database matches production. It is applied by
  the contract test only; it was not run against the live Supabase project.
- No tags, releases, merges, or changes to `main` were made from this branch.

## Installing the APK

The CI APK is **debug-signed** and intended for sideloading, not the Play Store.
If Android says **“App not installed”**, uninstall the previous version first
and install the new APK again. App data is stored in Supabase, so uninstalling
the app does not delete business records.

## UNVERIFIED — owner must check

- The original hang was not reproduced against the live Supabase project; live
  credentials and a live phone were not available to this work.
- No APK was installed on a physical device and no live payment, receipt PDF,
  tenant statement, or sideload flow was exercised here.
- Screenshot files were generated and inspected by tests, but the owner has not
  visually approved the final look on a phone.
- The already-live SQL views were not executed against the live project; only
  their committed snapshot and contract copy were verified locally.
