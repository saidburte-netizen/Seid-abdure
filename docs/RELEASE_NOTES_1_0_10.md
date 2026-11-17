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
  360x800 in light English from the running widgets. Required files are
  `home-grid`, `products-list`, `add-product-form`, `new-sale`, `stock`,
  `dashboard-stock-card`, `rentals-invoices`, `receive-payment-form`,
  `hr-employee-form`, and `cash-account-form`. CI fails if any is missing.
- Human-flow widget tests tap the home Products tile, save a product with only
  a name and price, find it in New sale, create a property/tenant/lease,
  generate an invoice, pay part and then the rest, and read item names and
  amounts on Stock.
- All gates passed locally in the required order: format, format check,
  `flutter analyze` (no issues), `flutter test` (311 tests), placeholder check,
  schema check, SQL contract with real RLS, and drift test.

## Owner-result fixes in this revision

- The portal menu now has explicit **Products** and **Stock** entries, and the
  home grid tiles push the real `/products` and `/stock` routes.
- The POS empty state now says **No products yet** and offers **Add product**,
  which opens the product form directly through `/products/new`.
- Rentals keeps all six tabs. **Generate invoices** is a visible labelled action
  in the Rent invoices header, and **Receive payment** appears on every invoice
  row. Overpayment asks for confirmation instead of being silently rejected.
- Sales still exposes all seven tabs, including Payments and Returns.

## Build identity

Settings > About shows version, build number, commit short SHA and branch. The
Android workflow injects `APP_VERSION`, `APP_BUILD_NUMBER`, `BUILD_SHA` and
`BUILD_BRANCH` with `--dart-define` into every build. The same values are
printed in the workflow summary and the generated release notes, so the APK you
install can be matched to the branch commit.

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
