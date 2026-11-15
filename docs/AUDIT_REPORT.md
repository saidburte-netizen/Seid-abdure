# Brade and Cake House — Audit Report and Job Log

Audit date: 2026-11-15
Repository: `saidburte-netizen/Seid-abdure`
Starting commit: `779eaa8`
Target release: **v1.0.8** (sideload APK/AAB plus web portal)
Job counter: **88 / 90** verified jobs
Release verdict: **GO for the local artifact; NO-GO for publishing until the final push is verified.** The code, contract, tests and release pipeline are ready; jobs 89–90 (push/tag/release and its run report) are blocked because `GH_TOKEN` is not visible in this environment.

A job counts as done only when a command or database query in this report
produced the stated result. Anything not yet executed is listed under
**UNVERIFIED** with the reason, and is not counted.

## Verified commands and outputs

| Check | Command | Observed result |
| --- | --- | --- |
| Static analysis | `dart analyze` | `Analyzing repo... No issues found!` (exit 0) |
| Test suite | `flutter test` | `03:18 +217: All tests passed!` (217 passed, 0 failed, exit 0) |
| Formatting | `dart format --output=none --set-exit-if-changed lib test` | `Formatted 75 files (0 changed)` (exit 0) |
| Localization generation | `flutter gen-l10n` | exit 0, no diff under `lib/l10n` |
| Placeholder scan | `tool/check_placeholders.sh` | `Static placeholder check passed.` |
| Schema snapshot check | `python3 tool/check_schema.py` | `PASS` (21 expected warnings for live-only objects) |
| Dependency vulnerabilities | `osv-scanner scan source -L pubspec.lock` | `Scanned pubspec.lock and found 136 packages` … `No issues found` |
| Secret history scan (v1.0.7) | Gitleaks full history | clean |
| SQL contract suite | `./tool/run_contract_local.sh` | `CONTRACT PASSED` (exit 0; 116 `assert_true`/`assert_raises` calls, including the new business-rule guards) |
| Accessibility | `flutter test test/accessibility_test.dart` | 66 tests pass: 51 routes at 200% text, 3 small-phone routes, 6 am/om routes, 1 negative control, 5 icon-target routes |
| Colour balance | `flutter test test/colour_probe_test.dart` | 51 route probes pass, every green ratio inside 52–68% |
| Translation coverage | 4 localisation test files | 10 tests pass; every schema/UI phrase has am and om text and placeholders are preserved |
| Workflow YAML | `python3` + `yaml.safe_load` on `.github/workflows/*.yml` | all 5 files parse |
| Smoke script syntax | `python3 -m py_compile tool/android_smoke.py` | exit 0 |
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
| SEC-13 | Medium | New trigger helpers would inherit PostgreSQL's default `EXECUTE` grant to `PUBLIC` | `20261115000004_business_rule_guards.sql` revokes them from `public`, `anon` and `authenticated`; contract asserts anon/auth cannot call them | **Fixed** |
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
| MOD-01 | High | Contract did not cover enough module rules | Contract now runs 116 `assert_true`/`assert_raises` calls covering void/stock/cash/credit/payroll/rent/close-day/payment limits/active records/RLS/storage and passes locally | **Fixed** |
| MOD-02 | Medium | Payroll/rent generation could duplicate | Duplicate guards asserted by the contract; UI buttons guard while a request is running | **Fixed** |
| BUS-01 | High | Payments could exceed the outstanding balance, and supplier payments had no positive-amount check | `20261115000004_business_rule_guards.sql`; contract asserts sale, customer, supplier and rent payments reject overpayment and negatives | **Fixed** |
| BUS-02 | High | A closed day could be silently overwritten by calling `fn_close_day` again or updating the row | Guard raises on a second close; `trg_daily_closing_locked` blocks edits/deletes except the notes field; contract verifies the value is unchanged | **Fixed** |
| BUS-03 | High | A credit sale could be saved without a customer or above the credit limit | `fn_sale_payment_apply` now requires an active customer and `outstanding + amount <= credit_limit`; contract proves both rejections | **Fixed** |
| BUS-04 | Medium | Inactive products and customers were accepted in new sales | `fn_sale_item_guard` and the sale-payment guard reject them; contract verifies both | **Fixed** |
| BUS-05 | Medium | Payslip money could be edited after payroll approval | `trg_payroll_payslip_guard` freezes money columns outside draft; contract verifies regeneration and payslip edits are rejected | **Fixed** |
| PERF-01 | Medium | Universal APK is large | Documented; split-per-ABI remains optional | **Accepted** |
| A11Y-01 | Medium | No 200% text-scale or 48 dp target test | `test/accessibility_test.dart`: 66 passing tests (all 51 routes at 200%, small phone, am/om, target sizes/labels, negative control) | **Fixed** |
| A11Y-02 | Low | No screenshot protection on payroll | Optional; documented | **Accepted** |
| AUTH-01 | Low | No MFA | Not in scope for this release; documented | **Accepted** |
| AUTH-02 | Medium | A deactivated profile could still reach the dashboard with a valid token | `AuthController._loadSession` signs it out, clears state and shows a translated notice; `test/deactivated_user_test.dart` and the RLS contract prove the block | **Fixed** |
| DB-01 | High | The 15 applied migrations `20261114000001`–`000015` are absent from the repository | Owner must upload them; the committed live-schema snapshot is used for disposable tests | **Owner action** |
| REL-01 | Medium | Release may be debug-signed | Debug signing stays unless the four signing secrets are configured; stated in release notes | **Accepted** |

### Counts

| Severity | Fixed | Verified | Owner action | Accepted | Open | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Critical | 1 | 0 | 0 | 0 | 0 | 1 |
| High | 16 | 0 | 2 | 0 | 0 | 18 |
| Medium | 13 | 1 | 0 | 3 | 0 | 17 |
| Low | 2 | 2 | 0 | 2 | 0 | 6 |
| **Total** | **32** | **3** | **2** | **5** | **0** | **42** |

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

## Job log (51–88)

51. `test/accessibility_test.dart` builds 51 routes at 200% text scale with no
    layout overflow. 51 tests pass.
52. The same routes `/`, `/pos` and `/sales` pass at 200% on a 320×568 phone.
53. Dashboard, POS and settings pass at 200% in Amharic and Afaan Oromoo
    (6 tests).
54. A deliberately broken `Row` is caught by the overflow detector, proving the
    test is not a no-op.
55. Five screens expose a tooltip or semantic label on every `IconButton` and
    every measured target is at least 48×48 dp.
56. A deactivated profile is signed out, state is cleared, and a translated
    notice is shown (`test/deactivated_user_test.dart`).
57. Contract rejects negative/zero payments for sales, customer credit,
    supplier payables and rent.
58. Contract rejects any payment larger than the outstanding balance on all
    five payment paths (including a second credit line), and proves the balance
    is unchanged after rejection.
59. Contract rejects a second close of the same day and a direct edit of a
    closed row; the counted cash stays at its original value.
60. Contract rejects payroll regeneration after approval, payslip money edits
    after approval, and adding a payslip after approval.
61. Contract re-verifies that a sale with a return cannot be voided.
62. Contract rejects a credit sale with no customer.
63. Contract rejects a credit sale above the customer credit limit and shows no
    receivable was created.
64. Contract rejects adding an inactive product to a new sale.
65. Contract rejects an inactive customer buying on credit.
66. Contract shows a deactivated user has no role code, no admin/staff role and
    cannot call `fn_close_day`.
67. Contract confirms a terminated employee is excluded from active payroll.
68. Contract asserts the three new `SECURITY DEFINER` trigger helpers are not
    executable by anon or authenticated; `fn_close_day` stays auth-only.
69. `./tool/run_contract_local.sh` applies `live_schema.sql`, all five committed
    migrations and 116 assertion calls; result `CONTRACT PASSED`.
70. Colour probe passes on all 51 routes; green share is 52–68% everywhere.
71. Translation coverage passes 10 tests across en/am/om catalogs, UI phrases
    and templates.
72. The database integration job lives in `build-android.yml`; the separate
    `supabase-integration.yml` was deleted, so a tag does not start a fourth
    workflow. The `release` job needs `build`, `smoke` and `integration`, so a
    failing contract or smoke test cannot publish.
73. Trigger audit: `ci` runs on a `main` push; only `build-android` and
    `build-web` match `v*` tags. The final push therefore starts exactly three
    runs.
74. `tool/android_smoke.py` now signs in, opens the dashboard and attempts one
    POS cash sale when smoke credentials are provided; `py_compile` passes.
75. The release notes state that the signed-in smoke phase needs the optional
    `SMOKE_EMAIL`/`SMOKE_PASSWORD` secrets, so a missing secret never blocks the
    release.
76. Android release signing falls back to the debug key when keystore secrets
    are absent, while `isDebuggable` stays false.
77. Release workflow audit: R8/shrink/obfuscation enabled, APK secret scan,
    `aapt` installable-app checks, all four artifacts plus `sha256sums.txt`
    attached by a separate `release` job that only runs after `build`, `smoke`
    and `integration` succeed.
78. A `SessionScope` lookup regression from the deactivated-account banner was
    fixed with `maybeOf`; the 74 affected sign-in/accessibility tests pass.
79. Version bumped to `1.0.8+8`; no SDK constraint or package version changed.
80. `flutter analyze` reports `No issues found!`.
81. `dart format --set-exit-if-changed` reports zero changed files.
82. Full `flutter test` suite passes: `03:18 +217: All tests passed!`
    (217 passed, 0 failed).
83. `flutter gen-l10n` succeeds, including the new deactivated-account phrase.
84. `bash -n tool/run_contract_local.sh` passes.
85. Gitleaks scan of the current source is clean (`no leaks found`). The only
    raw hits were inside generated `build/test_cache` binaries; generated build
    output is excluded, and the tracked source has no leaks.
86. Token/secret scan: `GH_TOKEN` is absent from the environment and from every
    tracked file; no credential was written to a document, workflow or config.
87. This final audit report records the GO/NO-GO verdict and the exact
    UNVERIFIED items instead of claiming an unexecuted release.
88. All work is committed locally in one commit on `main`; the tag and push are
    deliberately not created without the token.

## UNVERIFIED (jobs 89–90)

| Item | Reason |
| --- | --- |
| Final push, tag `v1.0.8` and GitHub release | `GH_TOKEN` is not visible (`env | grep -c '^GH_TOKEN='` → `0`, `${#GH_TOKEN}` → `0`). No push, tag or release was attempted. |
| Workflow run count and minutes used; release link | Depends on the unexecuted final push. |
| Local release APK/AAB build and R8 smoke test | No Android SDK, Java runtime or emulator in this environment. The deliberately small runner has no emulator; `build-android` performs this at release. |
| APK secret-string scan | Needs the APK produced by the release workflow. |
| Signed-in emulator smoke (dashboard + POS sale) | The script is ready, but no emulator/credentials exist locally; it runs at release only if `SMOKE_EMAIL`/`SMOKE_PASSWORD` are configured. |
| RLS with real GoTrue users | Local contract uses SQL role switching; the real `supabase start` integration job runs inside `build-web` at release. |
| Applying the four migrations to the live project | Owner must run them in the Supabase SQL Editor; they have not been pushed live. |
| The 15 earlier migrations | Absent from the repository; owner must upload them. |
| Physical-device sideload install | No device available; the emulator job covers install/launch at release. |
| v1.0.8 checksums and release links | Release is not built yet; reported after the final push. |

## Owner actions before handover

1. Apply `20261115000001_security_hardening.sql`,
   `20261115000002_ethiopian_date_defaults.sql`,
   `20261115000003_performance_indexes.sql` and
   `20261115000004_business_rule_guards.sql` in the Supabase SQL Editor, in that
   order, and keep the output.
2. Upload the missing migrations `20261114000001`–`20261114000015` if the
   repository should be authoritative.
3. Decide whether the GitHub repository stays public.
4. Replace `support@bradeandcakehouse.example` in the client pack with the real
   support address.
5. Configure the four Android signing secrets if a signed release is required.
6. Optionally add `SMOKE_EMAIL` and `SMOKE_PASSWORD` repository secrets so the
   release smoke can also sign in and complete one POS sale.
7. Provide `GH_TOKEN` to the release operator for the final push, then delete
   the token after the release.
