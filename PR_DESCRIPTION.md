# Fix save hang and finish minimum-field Products/POS/Stock/Rentals/HR gates

Branch: `fix/saving-hang` (rebased onto current `main`, no merge commit)
Version: `1.0.12+12`

## Owner-result fixes in this revision

- Added explicit **Products** and **Stock** entries to the portal menu.
- Home grid Products/Stock tiles now push the real `/products` and `/stock`
  routes.
- POS empty state now says **No products yet** and offers **Add product**, which
  opens the product form directly via `/products/new`.
- Rentals shows all six tabs. **Generate invoices** is a labelled action in the
  Rent invoices header, and **Receive payment** is present on every invoice row.
  Overpayment asks for confirmation.
- Sales shows all seven tabs including Payments and Returns.
- Settings > About shows version, build number, commit short SHA and branch.
  The Android workflow injects `APP_VERSION`, `APP_BUILD_NUMBER`, `BUILD_SHA`
  and `BUILD_BRANCH`; the same values are written to the generated release notes
  and workflow summary.
- Added human-flow widget tests that tap the home Products tile, save a product
  with only a name and price, find it in New sale, create a property/tenant/lease,
  generate an invoice, pay part and then the rest, and read Stock names/amounts.
- UI screenshot set is generated from running widgets and checked in CI; a
  missing required file fails the build.

## Save flow

- `SaveFlow.write` is the single database mutation boundary. It uses a 25-second
  timeout, a friendly retry message, timestamped admin diagnostics breadcrumbs,
  always releases the busy flag, keeps the dialog open on failure, and bumps
  `DataRevision` only on success.
- Failures are logged through `ErrorLog` and rethrown; no revision bump occurs.
- Resume/restore never destroys an open dialog or pending save. After process
  death the app restores the screen and clearly states the entry was **not
  saved**.

## Minimum fields and screens

- `docs/MINIMUM_FIELDS.md` documents every form's minimal fields, defaults, and
  exact-field required errors. Blank optional fields are omitted, never sent as
  `''`.
- Products supports search, category/active filters, gold Add product, photo,
  tax, multilingual names, Track stock (default on), opening stock, edit,
  deactivate/reactivate, duplicate, detail, stock/sales and “Start tracking
  stock”.
- POS reads active products, refreshes via `DataRevision`, searches by
  category/name, defaults to Shop/Cash Drawer, confirms price 0 and requires a
  customer for credit.
- Stock reads `v_stock_overview` with translated units, low chip, search and
  per-store actions; the dashboard Stock on hand card shows low-first items and
  uses `DataRevision`.
- Rentals covers Properties, Tenants, Leases, Invoices and Payments, receipt PDF,
  tenant statement, overdue display and the new Receive payment flow.
- HR supports name-only employees, list/edit/deactivate, quick attendance,
  leave, advances and payroll with a non-blocking zero-salary warning.

## Gates — real output from this commit

```
$ /root/flutter/bin/dart format --set-exit-if-changed lib test
Formatted 98 files (0 changed) in 8.13 seconds.

$ /root/flutter/bin/flutter analyze
No issues found! (ran in 8.5s)

$ /root/flutter/bin/flutter test
+311: All tests passed!

$ bash tool/check_placeholders.sh
Static placeholder check passed.

$ python3 tool/check_schema.py
PASS

$ bash tool/run_contract_local.sh
SCREEN SAVE SUMMARY | admin | 45 PASS | 0 SQLSTATE
SCREEN SAVE SUMMARY | manager | 38 PASS | 7 SQLSTATE
CONTRACT PASSED

$ python3 tool/payload_drift_test.py
checked 81 app tables/views against 81 live tables/views
PASS: every app table/view and field exists in the live snapshot

$ python3 tool/check_save_flow.py
SAVE FLOW SUMMARY | writes=73 wrapped=70 allow-listed=3 unwrapped=0
PASS: every database write uses the shared save flow or an explained allow-list entry.
```

Generated minimum-field artifacts were regenerated and left `docs/MINIMUM_FIELDS.md`
and the contract SQL unchanged. `flutter gen-l10n` succeeded.

## Required screenshot proof

Generated at 360x800, light, English from running widgets:

```
SCREENSHOT | home-grid.png
SCREENSHOT | products-list.png
SCREENSHOT | add-product-form.png
SCREENSHOT | new-sale.png
SCREENSHOT | stock.png
SCREENSHOT | dashboard-stock-card.png
SCREENSHOT | rentals-invoices.png
SCREENSHOT | receive-payment-form.png
SCREENSHOT | hr-employee-form.png
SCREENSHOT | cash-account-form.png
SCREENSHOT | wrote 23 files to build/ui_screenshots
```

CI verifies all ten required files exist before uploading the `ui-screenshots`
artifact.

## Human-flow test output

```
HUMAN_FLOW | saved product name=Owner Test Cake price=275
HUMAN_FLOW | New sale shows saved product "Owner Test Cake"
HUMAN_FLOW | created property Owner Test Property
HUMAN_FLOW | created tenant Owner Test Tenant
HUMAN_FLOW | created lease rent=1000
HUMAN_FLOW | tapped Generate invoices and confirmed
HUMAN_FLOW | paid 400, invoice paid_amount=400
HUMAN_FLOW | paid 600, invoice paid_amount=1000
HUMAN_FLOW | invoice INV-HUMAN fully paid (1000/1000)
HUMAN_FLOW | Stock shows "Chocolate cake" with quantity 12
```

## Database changes

No new data/schema migration. The only added migration file records dashboard and
stock views that are already live so the disposable contract database matches
production; it is applied by the contract test only and was not run against the
live project.

## Installing the APK

The CI APK is debug-signed for sideloading. If Android reports “App not
installed”, uninstall the previous version first, then install the new APK. App
data lives in Supabase, so uninstalling does not delete business records.

## UNVERIFIED — owner must check

- The original “Saving…” hang was not reproduced against the live Supabase
  project; live credentials and a live phone were not available here.
- No APK was installed or tested on a physical device in this workspace.
- Live payment, receipt PDF, tenant statement, sideload and update flows were
  not executed against production data.
- The generated screenshots were asserted by tests, but the owner has not
  visually approved them on a phone.
- The already-live SQL views were not executed against the live project; only
  the committed snapshot and disposable contract copy were verified.
- The PR has not been created or merged by automation; the owner must create or
  review it from `fix/saving-hang`.
