# Brade and Cake House

**hani brade and cake**

One Flutter app for the Brade and Cake House bakery, shop and rental business.
It runs on Android and on the web from the same project, uses the official
green, cream and gold brand, and ships English, Amharic and Afaan Oromo
interfaces with light and dark themes.

## Download and install

The GitHub Release contains the three compiled deliverables:

- `brade-cake-house.apk` — install this on an Android phone.
- `brade-cake-house.aab` — upload this to Google Play.
- `brade-cake-house-web.zip` — unzip and serve `index.html` for the web admin
  portal.

Install the APK by opening it on the phone and allowing installs from the
browser or file manager. If Android warns that the app is debug-signed, that is
expected until the four Android signing secrets are added to the repository.

## Included modules

- Dashboard with live KPIs and alerts.
- Point of sale, sales, returns, receipts, close-day.
- Products, categories, units, items, recipes, production batches, cake orders.
- Stock, stores, movements, counts, transfers, purchasing and goods receipts.
- Cash accounts, transactions, transfers, expenses, bills and payables.
- Employees, departments, documents, shifts, attendance, leave and advances.
- Payroll runs, payslips, approval, payment and PDF payslips.
- Properties, units, tenants, leases, rent invoices, rent payments, maintenance.
- Receivables, supplier payables, aging, statements and write-offs.
- Approvals, notifications, reports, CSV/PDF exports, users, roles and settings.

Every module is reachable from the single navigation drawer and is gated by the
live `role_permissions` table. Admin, manager and staff see the menus their role
allows; the admin role can use every module.

## First login

1. Open the app and tap **Create the first account**.
2. Enter a name, email and password. The live `handle_new_user` trigger makes
   the first profile `admin` automatically.
3. If Supabase email confirmation is enabled, confirm the email and sign in.
4. If no branch exists yet, the app offers **Create the first branch**.
5. Add later users by having them sign up, then open **Settings → Users** as an
   administrator and set their branch and role.
6. Roles are `admin`, `manager`, `cashier`, `baker`, `store_keeper`,
   `hr_officer`, `accountant`, `staff` and `customer`.

The app only reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` at build time. It
never embeds a service-role key.

## Local development

```sh
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

Build the same three deliverables locally:

```sh
flutter build apk --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
cp build/app/outputs/flutter-apk/app-release.apk brade-cake-house.apk

flutter build appbundle --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
cp build/app/outputs/bundle/release/app-release.aab brade-cake-house.aab

flutter build web --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
(cd build/web && zip -r ../../brade-cake-house-web.zip .)
```

## CI and releases

- `.github/workflows/ci.yml` runs formatting, `flutter analyze`, `flutter test`
  and a web build.
- `.github/workflows/build-android.yml` builds one universal APK and one AAB,
  renames them, verifies the APK with `aapt`, checks the 15 MB minimum, checks
  the package/label, checks the bundled logo, and uploads only those files.
- `.github/workflows/build-web.yml` builds and zips the web app, uploads only
  `brade-cake-house-web.zip`, and optionally deploys to GitHub Pages when the
  repository variable `ENABLE_PAGES` is `true`.
- Pushing a `v*` tag creates/updates the GitHub Release and attaches the APK,
  AAB and web ZIP.

Android release signing uses `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`.
If they are absent, the workflow produces a clearly labelled debug-signed build.
See [docs/ANDROID_SIGNING.md](docs/ANDROID_SIGNING.md).

## Documentation

- [docs/GAP_REPORT.md](docs/GAP_REPORT.md) — live-schema audit and known limits.
- [docs/BUILD_DIAGNOSIS.md](docs/BUILD_DIAGNOSIS.md) — why the old artifact was
  not one app.
- [docs/TOOLS.md](docs/TOOLS.md) — tool versions.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- [docs/SECURITY.md](docs/SECURITY.md)
- [docs/REPORTING.md](docs/REPORTING.md)
- [docs/BRANDING.md](docs/BRANDING.md)
- [supabase/README.md](supabase/README.md) — live database and migration safety.

## Security

The client uses only the public anon key. Row-level security, role checks,
triggers and `SECURITY DEFINER` functions enforce access in the database.
Never commit a service-role key, keystore, password, or GitHub token. If a token
was ever placed in a remote URL or terminal, revoke and rotate it immediately.
