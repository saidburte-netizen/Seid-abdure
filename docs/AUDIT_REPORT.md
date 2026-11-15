# Brade and Cake House — Audit Report and Job Log

Audit date: 2026-11-15
Repository: `saidburte-netizen/Seid-abdure`
Starting commit: `779eaa8`
Target release: **v1.0.8** (sideload APK/AAB plus web portal)
Job counter: **50 / 90** verified jobs
Release verdict: **not final** — the final GO/NO-GO is issued at job 90.

A job counts as done only when a command or database query in this report
produced the stated result. Anything not yet executed is listed under
**UNVERIFIED** with the reason, and is not counted.

## Verified commands and outputs

| Check | Command | Observed result |
| --- | --- | --- |
| Static analysis | `dart analyze` | `Analyzing repo... No issues found!` (exit 0) |
| Test suite | `flutter test` | `02:50 +150: All tests passed!` (150 passed, 0 failed) |
| Formatting | `dart format --output=none --set-exit-if-changed lib test` | `Formatted 73 files (0 changed)` (exit 0) |
| Localization generation | `flutter gen-l10n` | exit 0, no diff under `lib/l10n` |
| Placeholder scan | `tool/check_placeholders.sh` | `Static placeholder check passed.` |
| Schema snapshot check | `python3 tool/check_schema.py` | `PASS` (21 expected warnings for live-only objects) |
| Dependency vulnerabilities | `osv-scanner scan source -L pubspec.lock` | `Scanned pubspec.lock and found 136 packages` … `No issues found` |
| Secret history scan (v1.0.7) | Gitleaks full history | clean |
| SQL contract suite | `./tool/run_contract_local.sh` | `CONTRACT PASSED` (exit 0, 0 failed assertions) |
| Views use invoker rights | `select count(*) … relkind='v'` | `13 invoker / 13 views` |
| Anonymous table access | `has_table_privilege('anon', …)` | `0` readable relations in `public` |
| SECURITY DEFINER search path | `pg_proc.prosecdef` without `search_path` | `0` functions |
| RPC execute matrix | `has_function_privilege` | `has_admin` and `customer_signup_allowed` anon+auth = true; every other helper/RPC anon = false, auth = true |
| Storage bucket limits | `select … from storage.buckets` | avatars/branding/product-images 5 MiB image-only; receipts/contracts/employee-documents 10 MiB PDF+image |
| Android plugin API floor | scan of `~/.pub-cache/*/android` | highest plugin `minSdk` = 24; app `minSdk` = 24 |
| Dart SDK | `flutter --version` | Flutter 3.35.4, Dart 3.9.2 (pubspec constraint unchanged) |
| Workflow syntax | `yaml.safe_load` on `.github/workflows/*.yml` | all files parse |
| Contract runner syntax | `bash -n tool/run_contract_local.sh` | ok |

## Findings

| ID | Severity | Finding | Fix / evidence | Status |
| --- | --- | --- | --- | --- |
| SEC-01 | Critical | `anon` had full table/view/sequence access and views bypassed RLS | `20261115000001_security_hardening.sql`; verified `0` anon-readable relations and `13/13` invoker views; contract asserts anon cannot read profiles/settings | **Fixed** |
| SEC-02 | High | Every authenticated user could execute internal/trigger functions | Migration revokes all function execute, re-grants only app RPCs and RLS helpers; ACL matrix verified | **Fixed** |
| SEC-03 | High | Private storage buckets had no size/MIME limits | Migration sets limits and MIME types; bucket rows verified in database | **Fixed** |
| SEC-04 | High | Session tokens were stored in plain `SharedPreferences` | `lib/auth/secure_local_storage.dart` + `test/secure_session_storage_test.dart` (4 tests) | **Fixed** |
| SEC-05 | High | No inactivity timeout | 30-minute timer and foreground check; `test/inactivity_logout_test.dart` (4 tests) | **Fixed** |
| SEC-06 | High | Android backup and cleartext traffic were allowed | Manifest has `allowBackup="false"`, `fullBackupContent="false"`, `usesCleartextTraffic="false"` | **Fixed** |
| SEC-07 | High | Release build did not shrink or obfuscate | `isMinifyEnabled`, `isShrinkResources`, ProGuard rules, `--obfuscate --split-debug-info` in the Android workflow | **Fixed** |
| SEC-08 | High | CSV formula injection | `csvEscape` quotes `= + - @`, tab and CR; `test/formatting_test.dart` | **Fixed** |
| SEC-09 | Medium | Avatar upload accepted any type/size | `lib/data/upload_validation.dart` + `test/upload_validation_test.dart` (4 tests) | **Fixed** |
| SEC-10 | High | Repository is public and reveals business rules | Owner decision required before handover | **Owner action** |
| SEC-11 | Medium | Workflows used floating action tags; `supabase/setup-cli@v1` did not exist | Every action pinned to a commit SHA; CLI action pinned to `v1.7.3`; smoke job limited to `contents: read` | **Fixed** |
| SEC-12 | Medium | No CI secret or dependency scan | Added OSV scan and a Gitleaks job to `ci.yml`; added anon-key role guard and APK secret scan to the Android workflow | **Fixed** |
| STATE-01 | Medium | Unused Riverpod dependency | Removed; one `ChangeNotifier` + `InheritedNotifier` approach | **Fixed** |
| STATE-02 | Medium | No shared cache invalidation between screens | Each screen refreshes after its own write and on pull-to-refresh; no shared cache is intentional. Documented in `docs/client/FEATURES.md` | **Accepted** |
| STATE-03 | Medium | Double-submit risk on POS, payroll, rent, void | POS `_submitting`; `CrudTab` per-row in-flight guard; `test/crud_tab_double_submit_test.dart` proves one RPC for a double tap and release afterwards | **Fixed** |
| STATE-04 | Low | Possible controller/subscription leaks | No leaked controller or subscription found; existing `dispose` pattern retained | **Verified** |
| ERR-01 | High | PostgREST/storage errors were not mapped | `friendly_error.dart` categories; `test/friendly_error_test.dart` (12 tests incl. 23502, 23514, P0001, 413/415) | **Fixed** |
| ERR-02 | High | Reads could hang forever | 20-second timeout, one retry for reads, never for writes; `test/repository_pagination_test.dart` | **Fixed** |
| ERR-03 | Medium | Offline writes had no clear failure story | Failures show a friendly message; there is no offline queue, and the client guide states this explicitly | **Fixed** |
| ERR-04 | Low | Crash screen sentence was hard-coded | Now localised through `uiText` in en/am/om | **Fixed** |
| DATA-01 | High | Lists could silently lose rows above the 1,000-row cap | `offset`/`limit` pagination for `listAll`; export pages through all rows; test loads 2,500 rows | **Fixed** |
| DATA-02 | High | Date defaults used UTC, reports use Addis Ababa | `20261115000002_ethiopian_date_defaults.sql` (owner must apply to the live project) | **Fixed** |
| DATA-03 | Medium | Missing report indexes | `20261115000003_performance_indexes.sql` (owner must apply) | **Fixed** |
| DATA-04 | Low | Display rounding could disagree with the sale total | `lib/data/sale_math.dart` per-line rounding; `test/money_precision_test.dart` (9 tests) | **Fixed** |
| WIRE-01 | Low | Dead/empty handlers | Static placeholder check passes | **Verified** |
| WIRE-02 | High | No automated button walkthrough | `test/button_walkthrough_test.dart`: 17 routes and 9 role dashboards, every visible control tapped, no exception. It found and fixed two real bugs (app-bar overflow; `setState` returning a `Future`) | **Fixed** |
| WIRE-03 | Medium | No wiring documentation | `docs/WIRING.md` exists and maps screens to tables/RPCs | **Verified** |
| MOD-01 | High | Contract did not cover enough module rules | Contract now runs 127 assertions covering void/stock/cash/credit/payroll/rent/close-day/RLS/storage and passes locally | **Fixed** |
| MOD-02 | Medium | Payroll/rent generation could duplicate | Duplicate guards asserted by the contract; UI buttons guard while a request is running | **Fixed** |
| PERF-01 | Medium | Universal APK is large | Documented; split-per-ABI remains optional | **Accepted** |
| A11Y-01 | Medium | No 200% text-scale or 48 dp target test | Not yet written — this is the next job | **Open** |
| A11Y-02 | Low | No screenshot protection on payroll | Optional; documented | **Accepted** |
| AUTH-01 | Low | No MFA | Not in scope for this release; documented | **Accepted** |
| DB-01 | High | The 15 applied migrations `20261114000001`–`000015` are absent from the repository | Owner must upload them; the committed live-schema snapshot is used for disposable tests | **Owner action** |
| REL-01 | Medium | Release may be debug-signed | Debug signing stays unless the four signing secrets are configured; stated in release notes | **Accepted** |

### Counts

| Severity | Fixed | Verified | Owner action | Accepted | Open | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Critical | 1 | 0 | 0 | 0 | 0 | 1 |
| High | 13 | 0 | 2 | 0 | 0 | 15 |
| Medium | 8 | 1 | 0 | 3 | 1 | 13 |
| Low | 2 | 2 | 0 | 2 | 0 | 6 |
| **Total** | **24** | **3** | **2** | **5** | **1** | **35** |

## Job log (1–50)

Each entry is a finished, verified job. Evidence is the command output above or
the named test file.

1. Pin Flutter 3.35.4 (Dart 3.9.2) to match CI; `flutter pub get` succeeds.
2. `dart analyze` reports zero issues across `lib` and `test`.
3. Full `flutter test` suite passes: 150 tests, 0 failures.
4. `dart format --set-exit-if-changed` reports no changes.
5. `flutter gen-l10n` succeeds with no generated diff.
6. `tool/check_placeholders.sh` passes.
7. `tool/check_schema.py` passes with only expected live-only warnings.
8. OSV scan of `pubspec.lock`: 136 packages, no known vulnerabilities.
9. Gitleaks full-history scan of the v1.0.7 tree is clean.
10. SQL contract suite passes locally against a disposable PostgreSQL.
11. All three new migrations apply cleanly to the live-schema snapshot.
12. Anonymous callers have zero readable relations; only `has_admin` and
    `customer_signup_allowed` are executable by anon.
13. All 13 public views run with `security_invoker = true`.
14. Every SECURITY DEFINER function in `public` has a pinned `search_path`.
15. Storage buckets have explicit size and MIME limits.
16. Sign-in is behind an injectable gateway (`SignInGateway`).
17. Login tolerates `has_admin()` throwing or returning null.
18. Login tolerates `customer_signup_allowed()` throwing; create-account hidden.
19. Sign-in tests cover valid, invalid, double-tap and friendly-failure paths.
20. Inactivity timer signs out after 30 minutes.
21. Returning to the app after more than 30 minutes signs out immediately.
22. A short absence keeps the session and restarts the timer.
23. Legacy plain-text session is migrated into the secure store and deleted.
24. A stale plain-text session cannot overwrite a newer secure session (bug
    found and fixed while writing the test).
25. Removing the session clears secure storage.
26. Avatar validation extracted from the widget and covered by four tests.
27. CSV formula-injection guard fixed and tested.
28. Per-line money rounding helper added.
29. Money precision tests cover discounts, tax, rounding and totals.
30. POS uses the shared sale-total helper.
31. Repository pagination fetches more than 1,000 rows with `offset`/`limit`.
32. Reads retry exactly once after a timeout; writes never retry.
33. Export path reuses full pagination (2,500-row test).
34. CRUD row actions cannot fire twice while running (widget test).
35. Button walkthrough found and fixed a `setState` that returned a `Future`.
36. Button walkthrough found and fixed an app-bar title overflow.
37. Walkthrough taps every visible control on 17 routes without exceptions.
38. Walkthrough taps the dashboard controls for all 9 roles.
39. Route/localisation tests build every route in en, am and om.
40. Contract asserts anonymous access, staff/customer/admin boundaries.
41. Contract asserts void, returns, stock, cash, credit, payroll, rent and
    close-day behaviour.
42. CI now scans dependencies with OSV on every push.
43. CI now scans Git history with Gitleaks.
44. Every workflow action is pinned to a commit SHA.
45. The non-existent `supabase/setup-cli@v1` reference is corrected to v1.7.3.
46. Android release workflow refuses a non-anon Supabase key.
47. Android release workflow scans the built APK for secret-like strings.
48. `minSdkVersion 24` confirmed against every plugin's Android requirement.
49. Reproducible local contract runner committed and run to `CONTRACT PASSED`.
50. Client handover pack written: user guide, feature list, support notes,
    privacy notice, all matched to the shipped behaviour.

## UNVERIFIED

| Item | Reason |
| --- | --- |
| Local release APK/AAB build and R8 smoke test | No Android SDK, Java runtime or emulator in this environment. Runs in `build-android` at release. |
| APK secret-string scan | Needs the APK produced by the release workflow. |
| RLS with real GoTrue users | Local contract uses SQL role switching; the real `supabase start` integration job runs at release. |
| Applying the three migrations to the live project | Owner must run them in the Supabase SQL Editor; they have not been pushed live. |
| The 15 earlier migrations | Absent from the repository; owner must upload them. |
| 200% text-scale and 48 dp target checks | Test not written yet (job 51+). |
| Physical-device sideload install | No device available; the emulator job covers install/launch at release. |
| v1.0.8 checksums and release links | Release is not built yet; reported at job 90. |

## Owner actions before handover

1. Apply `20261115000001_security_hardening.sql`,
   `20261115000002_ethiopian_date_defaults.sql` and
   `20261115000003_performance_indexes.sql` in the Supabase SQL Editor, in that
   order, and keep the output.
2. Upload the missing migrations `20261114000001`–`20261114000015` if the
   repository should be authoritative.
3. Decide whether the GitHub repository stays public.
4. Replace `support@bradeandcakehouse.example` in the client pack with the real
   support address.
5. Configure the four Android signing secrets if a signed release is required.
