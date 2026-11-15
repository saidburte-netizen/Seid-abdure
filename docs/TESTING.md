# Testing

## Flutter gates

```sh
flutter pub get
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test
bash tool/check_placeholders.sh
python3 tool/check_schema.py
flutter analyze
flutter test
```

`flutter analyze` must report no issues. The suite covers:

- branded configuration and brand constants,
- every portal route in en/am/om (`test/all_routes_localization_test.dart`),
- live locale switching and the pre-login sign-in language menu,
- green/cream balance on all 51 routes (`test/colour_probe_test.dart`),
- offline sign-in and evidence capture (`test/airplane_mode_*_test.dart`),
- friendly-error privacy (`test/friendly_error_test.dart`),
- branch scoping (`test/branch_repository_test.dart`),
- ARB key/placeholder parity and UI/schema translation coverage,
- back navigation and Oromo framework localization.

## Supabase integration contract

The executable database test is
`supabase/tests/integration/contract.sql`. It runs in a disposable local
Supabase stack through `.github/workflows/supabase-integration.yml`:

```sh
supabase start
psql "$LOCAL_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/integration/seed.sql
psql "$LOCAL_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/integration/contract.sql
```

When the fifteen uploaded `20261114000001`–`20261114000015` migrations are
present, the workflow applies them. Otherwise it applies the read-only
`supabase/fixtures/live_schema.sql` snapshot and then
`supabase/migrations/20261114000016_void_sale.sql`. The contract wraps all work
in a transaction and rolls back. It never contacts the hosted project and never
uses the `service_role` key.

The contract covers auth users/profiles for all nine roles, RLS probes,
purchasing/receipts, stock counts, production, cash/credit/split sales, returns,
voids, customer payments, payables, cash transfers, payroll approval/payment,
rent invoices/payments, alerts, expenses, bills, approvals, stock transfers,
write-offs, role permissions, audit logs, translation columns and avatars. The
void checks prove exact pre-sale stock and cash restoration, a single stock
movement, credit receivable/ledger reversal, staff denial, rejection of a
second void, and rejection of a sale that already has a partial return without
changing stock or cash.

## Android emulator smoke test

The release APK is installed on a Pixel 6 API 34 emulator by
`tool/android_smoke.py` inside `build-android.yml`:

```sh
python3 tool/android_smoke.py brade-cake-house.apk
```

The script clears app data, launches
`net.bradeandcake.brade_and_cake_house/.MainActivity`, confirms the login screen,
switches the pre-login language menu English → አማርኛ → Afaan Oromoo → English,
captures screenshots in `build/evidence/android-smoke/`, and fails on visible
technical exception text.

## Build checks

```sh
flutter clean
flutter pub get
flutter gen-l10n
flutter build apk --release
flutter build appbundle --release
flutter build web --release
```

CI passes `SUPABASE_URL` and `SUPABASE_ANON_KEY` from repository secrets. It
verifies the APK package, label, INTERNET permission, launcher icon, bundled
logo, signing mode and SHA-256 checksums.

## Release checklist

- [x] Format, placeholder, schema, analyze and full-test gates green.
- [x] Local Supabase contract green.
- [x] Android emulator smoke green.
- [x] APK/AAB/web build and content verification green.
- [x] Checksums generated and attached.
- [x] Tag `v1.0.6` pushed and release verified.
- [x] Debug-signed sideload build clearly labelled; no Play Store signing
  required.
- [ ] Owner: configure SMTP/rate limits and test a restore from a manual export
  or a Pro daily backup.
