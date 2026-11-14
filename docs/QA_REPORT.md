# QA report - Brade and Cake House 1.0.3+3

## Environment

| Item | Value |
| --- | --- |
| Flutter | 3.35.4 stable |
| Dart | 3.9.2 |
| Test surface | 390 x 844 logical pixels, light theme |
| Live Supabase project | `nmrpmypgkljmtnsvmcfn` |
| Build version | `1.0.3+3` |

## Gate results

| Gate | Command | Result |
| --- | --- | --- |
| Formatting | `dart format --output=none --set-exit-if-changed lib test` | PASS |
| Placeholder/empty-handler scan | `bash tool/check_placeholders.sh` | PASS |
| Schema consistency | `python3 tool/check_schema.py` | PASS |
| Static analysis | `flutter analyze` | PASS, 0 issues |
| Full Flutter suite | `flutter test` | PASS, 83 tests |
| Colour-balance suite | `flutter test test/colour_probe_test.dart` | PASS, 51 routes |
| Offline evidence test | `flutter test test/airplane_mode_evidence_test.dart` | PASS |

### Schema check summary

- 81 live-schema snapshot objects (68 tables + 13 views)
- 68 SQL tables and 1 SQL view committed in the repository
- 61 SQL functions
- 52 `.from(...)` usages, 11 `.rpc(...)` usages, 47 column usages, 2 storage-bucket usages checked
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
| `/production` | 55.9% | PASS |
| `/inventory` | 53.9% | PASS |
| `/cash` | 55.9% | PASS |
| `/people` | 58.5% | PASS |
| `/payroll` | 59.2% | PASS |
| `/rentals` | 59.1% | PASS |
| `/credit` | 56.6% | PASS |
| `/approvals` | 58.4% | PASS |
| `/reports` | 56.7% | PASS |
| `/notifications` | 56.4% | PASS |
| `/settings` | 63.2% | PASS |
| `/settings/profile` | 59.1% | PASS |
| `/settings/security` | 59.3% | PASS |
| `/settings/business` | 59.8% | PASS |
| `/settings/branches` | 57.9% | PASS |
| `/settings/accounts` | 55.1% | PASS |
| `/settings/users` | 54.7% | PASS |
| `/settings/role-permissions` | 52.4% | PASS |
| `/settings/master-data` | 56.9% | PASS |
| `/settings/audit` | 56.0% | PASS |
| `/settings/export` | 56.8% | PASS |
| `/settings/storage` | 65.8% | PASS |
| `/settings/branding` | 62.7% | PASS |
| `/settings/about` | 61.0% | PASS |
| `/settings/help` | 66.1% | PASS |
| `/settings/privacy` | 65.8% | PASS |
| `/module/production` | 55.9% | PASS |
| `/module/sales` | 55.3% | PASS |
| `/module/pos` | 57.5% | PASS |
| `/module/inventory` | 53.9% | PASS |
| `/module/cash` | 55.9% | PASS |
| `/module/people` | 58.5% | PASS |
| `/module/payroll` | 59.2% | PASS |
| `/module/rentals` | 59.1% | PASS |
| `/module/credit` | 56.6% | PASS |
| `/module/approvals` | 58.4% | PASS |
| `/module/reports` | 56.7% | PASS |
| `/module/notifications` | 56.4% | PASS |
| `/module/settings` | 63.2% | PASS |
| `/module/audit` | 56.6% | PASS |
| `/module/media` | 56.6% | PASS |
| `/module/unknown` | 56.6% | PASS |
| `/access-denied` | 56.6% | PASS |
| `/sign-in` | 53.4% | PASS |
| `/loading` | 58.5% | PASS |
| `/profile-missing` | 57.6% | PASS |
| `/branch-setup` | 59.8% | PASS |
| `/auth-error` | 57.5% | PASS |


## Translation coverage

- `test/l10n_catalog_test.dart` proves `app_am.arb` and `app_om.arb` contain
  every English key and identical placeholder sets.
- `test/all_routes_localization_test.dart` builds every portal route in `en`,
  `am` and `om`, and switches language live in both directions.
- Newly translated auth/settings strings: `loading`, `branchSetup`,
  `noActiveBranch`, `createMainBranch`, `creating`, `generateInvoices`.
- No technical exception text is rendered to users; the offline path is covered
  by `test/airplane_mode_login_test.dart` and the evidence test.

## Airplane-mode evidence

Test: `test/airplane_mode_evidence_test.dart`

Asserted friendly text:

> No internet connection. Please check your network and try again.

The test also asserts that the visible widget tree contains none of
`socketexception`, `network is unreachable`, `clientexception` or `stack trace`.

Screenshot artifact: `build/evidence/airplane-mode-login.png` (76,988 bytes).
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

## Known limitations / blocked items

1. **Android signing** - The release workflow uses repository secrets when
   `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`
   and `ANDROID_KEY_PASSWORD` are configured. Without them the APK/AAB is
   debug-signed and is not Play-Store ready.
2. **Live Supabase one-time SQL** - `has_admin()`, `allow_customer_signup` and the
   `avatars` bucket/policies are documented in `supabase/sql/`. Their live
   installation is not verifiable from this checkout.
3. **Local Supabase integration matrix** - The legacy migrations do not match
   the live schema, so a local stack cannot exercise the live triggers/RPCs
   without a live-schema dump. The category matrix in `docs/WIRING.md` is the
   acceptance checklist; the Flutter widget/static suite is the executable gate
   in this environment.
4. **Release publication** - See the GitHub release for the final artifact and
   SHA-256 checksums. The workflow generates `sha256sums.txt` and attaches it to
   the release.

## Release checklist

- [x] Version bumped to `1.0.3+3`
- [x] Fresh-checkout workflow runs `flutter clean`, `pub get`, `gen-l10n`
- [x] Schema, format, placeholder, analyze and full-test gates wired into CI
- [x] APK/AAB/web build and APK content verification in workflow
- [x] SHA-256 checksums generated and attached
- [ ] Android signing secrets configured (release signing)
- [ ] Tag `v1.0.3` pushed and release verified
