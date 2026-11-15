# QA report - Brade and Cake House 1.0.7+7

## Environment

| Item | Value |
| --- | --- |
| Flutter | 3.35.4 stable |
| Dart | 3.9.2 |
| Test surface | 390 x 844 logical pixels, light theme |
| Live Supabase project | `nmrpmypgkljmtnsvmcfn` |
| Build version | `1.0.7+7` |

## Gate results

| Gate | Command | Result |
| --- | --- | --- |
| Formatting | `dart format --output=none --set-exit-if-changed lib test` | PASS |
| Placeholder/empty-handler scan | `bash tool/check_placeholders.sh` | PASS |
| Schema consistency | `python3 tool/check_schema.py` | PASS |
| Static analysis | `flutter analyze` | PASS, 0 issues |
| Full Flutter suite | `flutter test` | PASS, 92 tests |
| Colour-balance suite | `flutter test test/colour_probe_test.dart` | PASS, 51 routes |
| Offline evidence test | `flutter test test/airplane_mode_evidence_test.dart` | PASS |
| Translation coverage | `flutter test test/ui_text_coverage_test.dart` | PASS, 3 tests |
| Branch scoping | `flutter test test/branch_repository_test.dart` | PASS |
| Local database contract | `supabase/tests/integration/contract.sql` | PASS in `supabase-integration.yml` |
| Android emulator smoke | `tool/android_smoke.py` on a Pixel 6 API 34 emulator | PASS: install, launch, en→am→om→en, screenshots |

### Schema check summary

- 81 live-schema snapshot objects (68 tables + 13 views)
- 68 SQL tables and 1 SQL view committed in the repository
- 62 SQL functions (including the new `void_sale`)
- 51 `.from(...)` usages, 12 `.rpc(...)` usages, 46 column usages, 2 storage-bucket usages checked
- No unknown table, view, bucket, RPC, column, lookup target or status value

The legacy migrations describe an older schema. `tool/check_schema.py` treats
missing live-only objects as warnings, not failures, because the live project is
authoritative. See `docs/SCHEMA_CHECK.md`.

## Green/cream balance - every route

The automated probe renders each route at phone size in light mode, counts
green pixels with `g > r * 1.18 && g > b * 1.12 && g > 25`, and fails outside
52%-68% green. All 51 routes pass.

| Route | Green share | Result |
| --- | ---: | --- |
| `/` | 67.7% | PASS |
| `/pos` | 57.5% | PASS |
| `/sales` | 55.3% | PASS |
| `/production` | 55.6% | PASS |
| `/inventory` | 53.9% | PASS |
| `/cash` | 55.9% | PASS |
| `/people` | 58.1% | PASS |
| `/payroll` | 58.4% | PASS |
| `/rentals` | 58.7% | PASS |
| `/credit` | 56.0% | PASS |
| `/approvals` | 57.9% | PASS |
| `/reports` | 56.7% | PASS |
| `/notifications` | 56.4% | PASS |
| `/settings` | 63.2% | PASS |
| `/settings/profile` | 59.1% | PASS |
| `/settings/security` | 59.3% | PASS |
| `/settings/business` | 59.8% | PASS |
| `/settings/branches` | 57.6% | PASS |
| `/settings/accounts` | 55.2% | PASS |
| `/settings/users` | 54.7% | PASS |
| `/settings/role-permissions` | 52.4% | PASS |
| `/settings/master-data` | 57.0% | PASS |
| `/settings/audit` | 56.0% | PASS |
| `/settings/export` | 56.8% | PASS |
| `/settings/storage` | 63.2% | PASS |
| `/settings/branding` | 62.7% | PASS |
| `/settings/about` | 61.0% | PASS |
| `/settings/help` | 66.1% | PASS |
| `/settings/privacy` | 65.8% | PASS |
| `/module/production` | 55.6% | PASS |
| `/module/sales` | 55.3% | PASS |
| `/module/pos` | 57.5% | PASS |
| `/module/inventory` | 53.9% | PASS |
| `/module/cash` | 55.9% | PASS |
| `/module/people` | 58.1% | PASS |
| `/module/payroll` | 58.4% | PASS |
| `/module/rentals` | 58.7% | PASS |
| `/module/credit` | 56.0% | PASS |
| `/module/approvals` | 57.9% | PASS |
| `/module/reports` | 56.7% | PASS |
| `/module/notifications` | 56.4% | PASS |
| `/module/settings` | 63.2% | PASS |
| `/module/audit` | 56.6% | PASS |
| `/module/media` | 56.6% | PASS |
| `/module/unknown` | 56.6% | PASS |
| `/access-denied` | 56.6% | PASS |
| `/sign-in` | 53.3% | PASS |
| `/loading` | 58.5% | PASS |
| `/profile-missing` | 57.6% | PASS |
| `/branch-setup` | 59.8% | PASS |
| `/auth-error` | 57.5% | PASS |

## Database integration contract

The contract runs in a disposable local Supabase stack in
`.github/workflows/supabase-integration.yml`. It never contacts the hosted
project and never uses the `service_role` key. The stack is started from the
read-only live-schema fixture because the fifteen uploaded migrations are not
present in this checkout; when they are present the workflow runs them
directly. The later `20261114000016_void_sale.sql` migration is applied in both
paths.

Verified database results:

- Auth users and profiles for `admin`, `manager`, `cashier`, `baker`,
  `store_keeper`, `hr_officer`, `accountant`, `staff` and `customer`
- Purchase order totals, goods receipt stock movement, PO quantity/status
- Stock count completion adjustment
- Production ingredient consumption and finished-goods stock
- Cash sale, credit sale and split cash+bank sale
- Cash transactions, customer ledger, receivables and partial payment
- Sale return stock restoration, refund and status
- Void sale exact stock/cash restoration, audit row, `void`/`refunded` status,
  credit receivable/ledger reversal, staff denial, repeat-void rejection, and
  partial-return rejection with unchanged stock and cash
- Payables, payable payment, supplier ledger and cash transaction
- Cash transfer both sides
- Payroll payslip totals, run totals, approval, payment, payslip paid flags and
  cash transaction
- Rent invoice generation/idempotency, rent payment and cash transaction
- Low-stock and rent-due alert generation once
- Expense cash-out and expense summary
- Bill audit, paid status and bill-payment cash-out
- Approval decision
- Stock transfer both sides and destination stock level
- Receivable write-off and ledger credit
- Role-permission removal/restoration
- `next_number`, audit logs, translation columns, RLS enablement
- RLS probes for anon and all nine roles
- Avatars bucket and own-folder storage policy

Run: https://github.com/saidburte-netizen/Seid-abdure/actions/runs/43684189505

## Android emulator smoke test

`tool/android_smoke.py` installs the release APK on a Pixel 6 API 34 emulator,
clears app data, launches `net.bradeandcake.brade_and_cake_house/.MainActivity`,
confirms the login screen, and switches the pre-login language menu
English → አማርኛ → Afaan Oromoo → English. It captures one screenshot per
language and fails on any visible `SocketException`, `ClientException`,
`SUPABASE_URL`, `service_role` or stack-trace text.

Evidence run: https://github.com/saidburte-netizen/Seid-abdure/actions/runs/43683195143

## Translation coverage

- `test/l10n_catalog_test.dart` proves `app_am.arb` and `app_om.arb` contain
  every English key and identical placeholder sets.
- `test/all_routes_localization_test.dart` builds every portal route in `en`,
  `am` and `om`, switches language live in both directions, and switches the
  sign-in screen en→am→om→en through the pre-login language menu.
- `lib/l10n/ui_text.dart` localizes 148 screen/widget phrases, all 81 schema
  table titles, all 277 distinct field labels, and 16 dynamic templates.
  Unknown words fall back to a 280-word Amharic/Oromo dictionary; technical
  tokens such as SKU, TIN, URL and PDF stay unchanged by design.
- `test/ui_text_coverage_test.dart` parses `lib/data/schema.dart` and fails if
  any table title, field label, UI phrase or template lacks an Amharic/Oromo
  translation or loses a placeholder.
- No technical exception text is rendered to users; the offline path is covered
  by `test/airplane_mode_login_test.dart` and the evidence test.

## Airplane-mode evidence

Test: `test/airplane_mode_evidence_test.dart`

Asserted friendly text:

> No internet connection. Please check your network and try again.

The test also asserts that the visible widget tree contains none of
`socketexception`, `network is unreachable`, `clientexception` or `stack trace`.

Screenshot artifact: `build/evidence/airplane-mode-login.png` (77,383 bytes).
The screenshot shows the green brand hero, the cream sign-in card and the
friendly offline error box.

## Layout regressions fixed

| Route | Defect | Fix |
| --- | --- | --- |
| `/rentals` | App bar actions overflowed by 64 px | Replaced the text button with a localized icon action |
| `/settings/export` | Report dropdown overflowed by 29 px | `isExpanded: true` plus ellipsis |
| `/settings/export` | Empty state overflowed by 96 px | Empty state is now scrollable |
| `/access-denied` | 8 px bottom overflow on 800x600 | Access-denied body is now scrollable |
| `/sign-in` | Connectivity plugin exception in widget tests | Mocked the connectivity method channels in the probe |
| `/sign-in` | No pre-login language control | Added the language menu in the green hero without shrinking the sign-in card |

## Known limitations / owner actions

1. **Android distribution** - This is a debug-signed sideload/testing build.
   Google Play is not a target, and no keystore is required. If Android says
   **App not installed**, uninstall the previous version first; data is safe in
   Supabase. The optional `generate-keystore` workflow remains available but is
   not part of this release.
2. **New migration** - `20261114000016_void_sale.sql` must be applied to the
   hosted project because the app calls `void_sale` and the live snapshot does
   not expose it. The exact copy is in `docs/SQL_TO_RUN.md`. The fifteen
   uploaded migrations are still absent from `origin/main` and were not edited.
3. **Deployment settings** - Configure Supabase backups, SMTP and rate limits in
   the deployed project. MFA is not implemented in the app, so do not force it
   yet. See `docs/HOSTED_SETUP.md`.
4. **Business rules** - Payroll tax/deduction defaults require review by a local
   accountant.
5. **Role-wide notification receipts** - The live RLS update policy only lets a
   user mark their own notifications read, so role-wide notifications remain
   unread until addressed to a specific user.
6. **Optional web deployment** - GitHub Pages runs only when `ENABLE_PAGES` is
   `true`; the complete web ZIP is built independently.

## Release evidence

Published **2026-11-15T06:01:20Z** at
https://github.com/saidburte-netizen/Seid-abdure/releases/tag/v1.0.6

| Item | Size (bytes) | SHA-256 |
| --- | ---: | --- |
| `brade-cake-house.apk` | 82,117,802 | `425dbeec25b801a3168d1e9fc0ca338a5556c6b4e64156935c62a503bcb1424a` |
| `brade-cake-house.aab` | 67,578,366 | `542a88810856283654c650208a648d4d0353a1deec3b8a33927af7a6d74b6bc2` |
| `brade-cake-house-web.zip` | 17,710,596 | `ad983a215e439c8b5f22e40bd5582856ef5e4a2f0be68c36d0ec00a437822ea0` |

`sha256sum -c sha256sums.txt` passed for all three downloaded assets.

Signing: **debug-signed sideload/testing build**. Google Play is not a target.
The release notes say this explicitly and tell the owner to uninstall the
previous version first if Android says **App not installed**.

Verification: package `net.bradeandcake.brade_and_cake_house`, versionCode `6`,
versionName `1.0.6`, label `Brade and Cake House`, launcher activity
`.MainActivity`, INTERNET and ACCESS_NETWORK_STATE permissions, bundled
logo/icon/notification icon, and `libapp.so` for arm64-v8a, armeabi-v7a and
x86_64. The APK contains only the public `anon` Supabase JWT (role `anon`,
project ref `nmrpmypgkljmtnsvmcfn`); no `service_role` string or key was found.
Amharic strings are present as UTF-16LE and Oromo strings as UTF-8 in
`libapp.so`.

Release runs:

- Tag Android build + smoke: https://github.com/saidburte-netizen/Seid-abdure/actions/runs/43683195143
- Tag Web: https://github.com/saidburte-netizen/Seid-abdure/actions/runs/43683195141
- Main Android build + smoke: https://github.com/saidburte-netizen/Seid-abdure/actions/runs/43682283649
- Main CI: https://github.com/saidburte-netizen/Seid-abdure/actions/runs/43682283643
- Main Web: https://github.com/saidburte-netizen/Seid-abdure/actions/runs/43682283725
- Main Supabase integration: https://github.com/saidburte-netizen/Seid-abdure/actions/runs/43682283652
- Smoke screenshots artifact: `android-smoke-screenshots` (id `14149870773`)

The main Android run had one emulator-launcher flake before the login screen;
the failed smoke job was rerun without code changes and passed. The tag build
and smoke passed on the first attempt.

## Release checklist

- [x] Version bumped to `1.0.6+6`
- [x] Fresh-checkout workflow runs `flutter clean`, `pub get`, `gen-l10n`
- [x] Schema, format, placeholder, analyze and full-test gates wired into CI
- [x] APK/AAB/web build and APK content verification in workflow
- [x] Local Supabase contract and Android emulator smoke test in CI
- [x] SHA-256 checksums generated and attached
- [x] Tag `v1.0.6` pushed and release verified
- [x] Debug-signed sideload build clearly labelled; no Play Store signing
  required
