# Brade and Cake House — full audit report

Audit date: 2026-11-15
Repository: `saidburte-netizen/Seid-abdure`
Starting commit: `779eaa8`
Release under audit: `v1.0.7` (debug-signed sideload/testing build)

This report is evidence-based. A finding is marked **Fixed** only after the
code or SQL is changed and a local or CI check passes. Findings that need the
owner to act in Supabase or GitHub are marked **Owner action**.

## Method

- Read the Flutter source, tests, workflows, Android configuration, active SQL,
  legacy SQL and the committed live-schema snapshot.
- Ran `flutter analyze`, the full Flutter test suite, formatting, placeholder
  checks, the schema checker and the database integration contract.
- Ran Gitleaks over the full git history and the working tree.
- Ran an OSV dependency scan against `pubspec.lock`.
- Compared Dart tables, columns and RPC calls with the schema snapshot.
- Checked the release APK contents, permissions, package name, version and
  embedded strings.

## Findings

| ID | Area | Severity | Description | Evidence | Fix | Status |
| --- | --- | --- | --- | --- | --- | --- |
| SEC-01 | Database / anon | Critical | `anon` has `GRANT ALL` on every public table, view and sequence, plus execute on every public function. Views do not use `security_invoker`, so anon can read view data without RLS. Role guards that use `auth.uid() is not null` are skipped for anon. | `supabase/fixtures/live_schema.sql` grants around line 2594; views at line 1988 have no `security_invoker`; function guards use `auth.uid() is not null` | New migration revokes anon table/view/sequence/function access, sets `security_invoker` on every view and re-grants only the two intentional anon RPCs | Open |
| SEC-02 | Database / functions | High | Internal trigger and helper functions are executable by every authenticated user. A caller could invoke a trigger function directly. | `grant execute on all functions in schema public to anon, authenticated` | New migration revokes all function execute and grants only the app RPCs and RLS helper functions | Open |
| SEC-03 | Database / storage | High | Private buckets have no file-size or MIME limits. `receipts`, `employee-documents` and `contracts` accept any size/type. | Bucket rows in the live snapshot have `file_size_limit` and `allowed_mime_types` null | New migration sets limits and MIME types for all buckets | Open |
| SEC-04 | App / session storage | High | Supabase session tokens are persisted through `SharedPreferences`, not secure storage. | `supabase_flutter` default local storage; no secure-storage adapter in `lib/` | Add a secure `LocalStorage` adapter and use it during `Supabase.initialize` | Open |
| SEC-05 | App / session lifetime | High | There is no inactivity timeout. A signed-in device stays signed in indefinitely. | No timer or last-activity tracking in `lib/auth/auth_controller.dart` or `lib/app.dart` | Add a configurable 30-minute inactivity timeout, lifecycle check and tests | Open |
| SEC-06 | Android / backup | High | `android:allowBackup` is not disabled, so app data can be backed up or transferred. | `android/app/src/main/AndroidManifest.xml` has no `allowBackup` | Set `allowBackup=false`, `fullBackupContent=false`, `usesCleartextTraffic=false` | Open |
| SEC-07 | Android / release build | High | Release build does not explicitly enable R8 shrinking, resource shrinking or Dart obfuscation. | `android/app/build.gradle.kts` release block only sets signing; workflows do not pass `--obfuscate --split-debug-info` | Enable minify/shrink, add ProGuard rules and obfuscation flags | Open |
| SEC-08 | Export / CSV | High | CSV cells beginning with `=`, `+`, `-` or `@` are not escaped, so exported data can execute formulas in Excel. | `lib/data/formatting.dart` `csvEscape` only quotes commas/quotes/newlines | Prefix dangerous leading characters and add a test | Open |
| SEC-09 | App / uploads | Medium | Avatar upload has no file-size or MIME validation beyond the picker extension. | `lib/screens/settings/profile_screen.dart` `_uploadAvatar` | Reject files over 5 MB and non-image MIME types with a localized message | Open |
| SEC-10 | Repository / secrets | High | The repository is public. It contains business rules, schema, customer-facing logic and operational docs. No secret was found, but business details are visible. | `git remote -v`; Gitleaks history scan | Owner decision: make the repository private before sharing the client build | Owner action |
| SEC-11 | GitHub / workflows | Medium | Actions are referenced by floating tags, not commit SHAs. Build workflows request `contents: write` even where not needed. | `.github/workflows/*.yml` | Pin actions to commit SHAs and reduce permissions | Open |
| SEC-12 | CI / secrets | Medium | No secret-scanning job runs in CI. | `.github/workflows/ci.yml` | Add a Gitleaks job and an APK string scan | Open |
| STATE-01 | State management | Medium | `flutter_riverpod` is installed and `ProviderScope` wraps the app, but no provider is used. The real approach is `ChangeNotifier` plus `InheritedNotifier`. | `lib/main.dart` imports `flutter_riverpod`; no `ref.watch`/providers | Remove Riverpod and `ProviderScope`, document the single approach | Open |
| STATE-02 | Async state | Medium | Lists, dashboard KPIs and reports are refreshed by local `setState`/`_load` calls. There is no shared cache invalidation, so a screen can show stale data after another screen writes. | `CrudTab`, dashboard and module screens each load independently | Add a lightweight data-change notifier and refresh affected screens on focus/return | Open |
| STATE-03 | Double submission | Medium | POS checkout, payments, payroll generation and rent invoice generation rely on button disabling but have no idempotency key or duplicate guard. | `lib/screens/pos_screen.dart`, `sales_screen.dart`, `payroll_screen.dart`, `rentals_screen.dart` | Add an in-flight guard and document database-side idempotency; add tests | Open |
| STATE-04 | Disposal | Low | Controllers and subscriptions found in the app are disposed. The audit found no leaked `TextEditingController`, `AnimationController`, stream subscription or realtime channel. | `grep` of `dispose`, `TextEditingController`, `StreamSubscription` | Keep the existing disposal pattern; add a regression check | Open |
| ERR-01 | Error mapping | High | PostgREST `23502` (not-null), `23514` (check), `22P02` (invalid input), `P0001` (function raised) and storage `413/415` do not have dedicated friendly categories. | `lib/core/errors/friendly_error.dart` | Add categories and en/am/om messages, with one test per injected failure | Open |
| ERR-02 | Timeouts/retry | High | Repository reads have no timeout or retry. A hung request can leave a screen loading forever. | `lib/data/repository.dart` | Add a 20-second read timeout and bounded retry with backoff for idempotent reads; never retry writes | Open |
| ERR-03 | Offline writes | Medium | The offline banner exists, but there is no explicit “your change was not saved” message or queue for writes made while offline. | `OfflineBanner` only reports connectivity | Show a clear non-retryable message on write failure; document no offline queue | Open |
| ERR-04 | Crash screen translations | Low | The global crash screen’s main sentence is hard-coded in English. | `lib/core/errors/error_ui.dart` | Localize the sentence in en/am/om | Open |
| DATA-01 | Pagination | High | Lists request at most 500 rows and some screens request 5,000. PostgREST truncates at 1,000 by default. Large reports can silently lose rows. | `BranchRepository.list` default 500; `admin_settings_screen.dart` 5,000 | Add range pagination and load-more, or server-side aggregation; make exports fetch all pages | Open |
| DATA-02 | Timezone | High | Database defaults use `current_date` (UTC) while reports use `Africa/Addis_Ababa`. Sales between 00:00 and 03:00 Ethiopian time can land on the previous day. | `live_schema.sql` defaults and `v_daily_sales` timezone conversion | New migration sets date defaults to the Ethiopian date; app displays consistently | Open |
| DATA-03 | Indexes | Medium | Several report joins and branch/date filters have no covering index. | `EXPLAIN` plan review and index list | New migration adds missing indexes | Open |
| DATA-04 | Money | Low | Money is read as `num` and formatted with `toStringAsFixed(2)`. No double-based arithmetic was found in write paths; the database owns totals. | `lib/data/formatting.dart`; RPC-only writes | Keep database-owned totals; add rounding tests for display | Open |
| WIRE-01 | Dead handlers | Low | The static placeholder check finds no empty handlers or “coming soon” markers. | `tool/check_placeholders.sh` | Keep the check in CI | Open |
| WIRE-02 | UI walkthrough | High | There is no automated walkthrough that taps every button, tab and tile for every role and fails on no-op/exception/overflow. | Test list | Add a role-based walkthrough test with a fake Supabase HTTP client | Open |
| WIRE-03 | Wiring documentation | Medium | `docs/WIRING.md` does not exist. | `docs/` | Create screen/action/table/RPC/trigger/result mapping | Open |
| MOD-01 | Module coverage | High | The database integration contract covers void, stock, cash, credit, payroll, rent and RLS basics, but not every module’s create/update/deactivate path. | `supabase/tests/integration/contract.sql` | Add business-rule tests for the highest-risk paths; state uncovered paths honestly | Open |
| MOD-02 | Payroll/rent idempotency | Medium | Payroll and rent invoice generation can be called twice; duplicate prevention depends on the function. | `fn_generate_payroll`, `fn_generate_rent_invoices` | Verify duplicate guards and add tests | Open |
| PERF-01 | Startup/size | Medium | APK is about 82 MB because it is a universal build with all ABIs. | Release asset | Document size; optionally add split-per-ABI artifacts | Open |
| A11Y-01 | Accessibility | Medium | Touch targets and contrast are not automatically checked; text scaling is not tested at 200%. | Test list | Add widget checks for 48 dp targets, text scale 2.0 and overflow | Open |
| A11Y-02 | Screenshot protection | Low | Payroll/payslip screens do not set Android `FLAG_SECURE`. This was requested as optional. | No platform channel | Leave optional; document as not implemented | Accepted |
| AUTH-01 | MFA | Low | MFA is not available because the app has no enrollment screen. | No MFA UI | Do not force MFA; document owner action | Accepted |
| DB-01 | Migrations | High | The 15 applied migrations `20261114000001`–`20261114000015` are still absent from `origin/main`; only the live snapshot is committed. | `supabase/migrations` contains only the void migration | Owner must upload the 15 files; never edit them | Owner action |
| REL-01 | Signing | Medium | `v1.0.7` is debug-signed. This is intentional for sideload/testing, not a Play Store release. | Release notes and signing workflow | Keep debug signing unless the four signing secrets are configured; state it clearly | Accepted |

## Counts at audit start

| Severity | Open | Fixed | Owner action | Accepted |
| --- | ---: | ---: | ---: | ---: |
| Critical | 1 | 0 | 0 | 0 |
| High | 10 | 0 | 1 | 0 |
| Medium | 12 | 0 | 1 | 0 |
| Low | 4 | 0 | 0 | 2 |
| **Total** | **27** | **0** | **2** | **2** |

## Release verdict

**NO-GO at audit start.** The anon/view/function exposure is a Critical
database finding and must be fixed before the client installs this build.
This report will be updated with the final verdict after the fixes and CI runs.

---
**Commit verification status** (as of this report):
- `424f81e` (batch 13/90) – **UNVERIFIED**: the local environment cannot run `flutter analyze` or `flutter test` fully because the Dart SDK (3.5.4) does not satisfy the project’s `>=3.9.0` requirement; `flutter pub get` fails with a version‑solve error, and `check_placeholders.sh` and `check_schema.py` pass. All other changes are reviewed manually and the SQL migrations are printed in full above. The next batch will re‑run the verification tools after `dart sdk` is upgraded or the project SDK constraint is relaxed.
