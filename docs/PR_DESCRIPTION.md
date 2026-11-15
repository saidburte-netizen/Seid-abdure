# Release v1.0.8: audit fixes, security hardening, Jimma location

## Summary

This PR prepares the **v1.0.8** release of Brade and Cake House (Flutter app +
Supabase backend) for the client in **Jimma, Ethiopia**. It contains the audit
fixes, the security hardening, the accessibility work, the business-rule
database guards and the Jimma location corrections.

The branch is `release/v1.0.8`. No tag is pushed by the automation; the owner
creates the tag and the release from the GitHub web UI after merging.

## What changed

### Jimma location
- Business location is **Jimma, Ethiopia**. The branch name and address are
  read from the database (`branches.name`, `branches.address`), and receipts,
  invoices, payslips and reports print the branch address and phone when
  available.
- Removed hard-coded "Addis Ababa" as a business location. Only a fallback
  branch label remains, used solely when the database returns no branch.
- The IANA time zone stays `Africa/Addis_Ababa` because Ethiopia uses a single
  time zone (UTC+3); it is the standard identifier for the whole country.
  Dates and times shown in the app use Ethiopian time regardless of the phone
  setting (database defaults migrated in `20261115000002`).

### Security hardening
- RLS and `SECURITY DEFINER` execute matrix tightened: `has_admin` and
  `customer_signup_allowed` are the only functions callable by `anon`;
  RLS helpers and `next_number` are authenticated-only; `void_sale`,
  `fn_generate_*` and `fn_close_day` are authenticated-only; views remain
  `security_invoker`.
- New trigger helper functions revoked from `public`, `anon`, `authenticated`.
- APK secret scan in CI (no `service_role` or token strings in the built APK).
- Deactivated profiles are signed out app-side with a translated, persistent
  sign-in notice.
- CSV injection guard, upload validation, secure storage, inactivity timeout,
  export pagination, friendly error messages.

### Business-rule database guards (`20261115000004`)
- Payment cannot exceed the sale total; over-payment and exact-balance credit
  rules enforced.
- Closed-day guard blocks new sales/expenses on a closed day.
- Payroll cannot be inserted after approval.
- Active-record guards on deletes/updates.

### Accessibility and i18n
- 200% text scale, small-phone layout and touch-target coverage across all
  routes, including icon-only controls.
- Full translation coverage for **en / am / om** (10 translation tests).

### Release pipeline
- `ci` (on `main` and PRs) → `build-android` (on `v*` tags: build → emulator
  smoke → local Supabase integration → publish) → `build-web` (on `v*` tags).
- The release job attaches `brade-cake-house.apk`, `brade-cake-house.aab`,
  `brade-cake-house-web.zip` and `sha256sums.txt` to an **existing** release
  (created from the GitHub web UI) using `softprops/action-gh-release`, which
  updates the release by tag and overwrites same-named assets.
- R8/shrinking/obfuscation enabled; CI actions pinned to commit SHAs.

## Tests passed (real counts)

| Gate | Result |
|------|--------|
| `flutter test` | **217 passed, 0 failed** (`All tests passed!`) |
| `test/accessibility_test.dart` | 66 tests passed |
| `flutter analyze` | **No issues found!** |
| `dart format --set-exit-if-changed` | 75 files, **0 changed** |
| `flutter gen-l10n` | exit 0, no diff |
| SQL contract (`tool/run_contract_local.sh`) | **CONTRACT PASSED** (116 `assert_true`/`assert_raises`) |
| `tool/check_placeholders.sh` | passed |
| `tool/check_schema.py` | PASS (21 expected live-only warnings) |
| Gitleaks (source tree + 8 commits) | **no leaks found** |
| Colour balance probe | 51 routes PASS, 52–68% green |

## Database migrations

These were **already applied by the owner in the live Supabase project** and
verified there:

- `20261115000001`
- `20261115000002`
- `20261115000003`
- `20261115000004`
- `20261115000005` (review fixes)

The 15 earlier `20261114000001`–`20261114000015` migrations are **not present**
in this checkout; the CI integration job therefore falls back to the read-only
`supabase/fixtures/live_schema.sql` fixture.

## UNVERIFIED items (with reason)

- **GitHub Actions results for v1.0.8** — not yet run; they start only when the
  owner pushes the `v1.0.8` tag on release publish.
- **APK/AAB/web build, R8 smoke, APK secret scan** — produced by CI at release;
  no Android SDK/emulator in the development environment.
- **Signed-in emulator smoke (dashboard + POS sale)** — runs only when the
  optional `SMOKE_EMAIL` / `SMOKE_PASSWORD` secrets exist; otherwise it logs
  `SMOKE SKIP`.
- **Real GoTrue RLS matrix** — runs in the CI `integration` job at release;
  locally the contract uses SQL role switching.
- **Physical-device sideload** — no device available here; covered by the
  owner's phone test.
- **Live schema for the 15 earlier migrations** — absent from the checkout,
  so only the fixture path is exercised.

## How to test

1. Merge this PR.
2. Create the release from the GitHub web UI (Releases → Draft a new release),
   choose tag `v1.0.8`, publish. This creates the tag and triggers
   `build-android` and `build-web`.
3. Wait for `build-android` to finish; it publishes the four assets to the
   release you created.
4. On an Android phone: uninstall any previous version first (the build is
   **debug-signed**; if Android says "App not installed", uninstall the old
   app — data is safe in Supabase). Install `brade-cake-house.apk`.
5. Sign in, open the dashboard, make one POS sale, switch language en/am/om,
   and open a receipt: it must show the business name and the branch address
   from the database (`Jimma, Ethiopia`) and the phone if set.
6. Report any problem; fixes will ship as v1.0.9 in one batch.
