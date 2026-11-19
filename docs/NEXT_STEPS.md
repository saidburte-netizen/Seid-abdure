# Next steps

## Done

- Round 4 fixes are merged into `origin/main` (`faca4c2`), including `ba3b52a`.
- Database contract now runs before the minimum-field seed in both CI and the local runner.
- Android smoke script dismisses a cold-boot launcher ANR and relaunches the app.
- The database contract reports the exact failing SQL statement in the job annotation.
- Anonymous SELECT was revoked from the three dashboard views and authenticated access was restored.
- Nexa-style presentation work is present on `ux/simple-flow`:
  - persistent bottom navigation;
  - dashboard quick actions and compact KPI cards;
  - searchable "All modules" sheet;
  - mobile gold add buttons on Products and Stock;
  - light app bar, rounded cards, and ivory navigation styling.

## Not done

- Home is not yet the requested 8-tile grid (Sell, Products, Stock, Money, Customers, Suppliers, Reports, More).
- Bottom navigation still has five destinations (Home, Sell, Stock, Reports, More); it is not yet the requested four (Home, Sell, Stock, Money).
- Login has not been reduced to the requested single clean screen with visible language switcher and stay-signed-in.
- Sell is not yet the requested 3-tap product grid, cart, total bar, payment sheet, and success screen.
- Sales history is not yet the requested simple receipt/date/total/status list with Today/Week/Month filters.
- Product and Stock add forms do not yet start with only the minimum fields plus a "More details" expander.
- The Money screen, partner-style Customers/Suppliers screen, and simplified Reports screen are not implemented.
- The universal Help, first-run hints, skeleton loaders, undo snackbar, text-size setting, and full wiring table are not implemented.
- No new human-flow test has been added for the requested daily paths.

## Tests that still need to run

These must run in GitHub CI on the pull request, not on this machine.

- `dart format --output=none --set-exit-if-changed lib test`
- `flutter analyze`
- `flutter test`
- placeholder check
- schema check
- save-flow check
- drift check
- `bash tool/run_contract_local.sh` or the CI contract job
- UI screenshot artifact check

## Known failures from the latest CI run

- Build job: 311 passed, 12 failed.
  - `test/layout_design_test.dart`: `/sales`, `/production`, `/inventory`, `/people`, `/payroll`, `/rentals`, `/credit`, `/approvals`, `/reports`, `/notifications` failed in light English.
  - `test/round4_screens_test.dart`: Products and Stock screen expectations failed after the mobile add button changed to an icon-only FAB.
- Integration job: the disposable Supabase stack step failed with exit code 1 before the contract ran. The exact step error is not yet captured.

## Files changed on this branch relative to `origin/main`

The exact list is in the commit diff. The UX work touches:

- `lib/app.dart`
- `lib/l10n/app_am.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_om.arb`
- generated localization files
- `lib/screens/dashboard_screen.dart`
- `lib/screens/products_screen.dart`
- `lib/screens/stock_screen.dart`
- `lib/theme/app_theme.dart`
- `lib/widgets/app_bottom_nav.dart`
- `lib/widgets/module_scaffold.dart`
- `test/navigation_ease_test.dart`
- `test/ui_screenshots_test.dart`
- `.github/workflows/build-android.yml`
- `supabase/migrations/20261119000000_revoke_anon_dashboard_views.sql`

## Unverified

- The layout and UX changes have not been verified by a local test run.
- No emulator, physical device, live Supabase, payment, receipt, or statement flow was exercised.
- The latest integration failure is not diagnosed.
