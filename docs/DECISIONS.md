# Brade and Cake House — Engineering Decisions

Updated: 2026-11-15 · Job counter: 50/90

This file records decisions that affect the shipped behaviour. Where an earlier
draft of this file was wrong, the correction is stated explicitly.

## Toolchain

- **Flutter 3.35.4 / Dart 3.9.2** is installed at `/tmp/opencode/tools/flutter`
  and matches `.github/workflows/*` (`flutter-version: "3.35.4"`).
- The `pubspec.yaml` SDK constraint (`>=3.9.0 <4.0.0`) stays unchanged. The SDK
  was upgraded to satisfy it; the constraint was not lowered.
- `flutter_secure_storage` is pinned to `^10.3.4` because `^11` and
  `share_plus ^10.1.4` cannot resolve together (win32 conflict). Other packages
  keep their existing pins for the same reason.

## State management

- Riverpod is removed. The app uses `ChangeNotifier` (`AuthController`) plus
  `InheritedNotifier` (`SessionScope`). No second state container is added.
- Screens refresh after their own write and on pull-to-refresh. There is no
  shared cache; this is intentional and documented in the client guide.
- Every destructive or expensive control guards against a second tap while its
  request is running: POS checkout, `CrudTab` row actions (payroll generation,
  payroll approval, rent generation, void), and form submit buttons.

## Authentication

- Sign-in goes through `SignInGateway` (`lib/auth/sign_in_gateway.dart`). The
  production implementation calls Supabase; tests inject `FakeSignInGateway`.
  Tests never contact the live project.
- If `has_admin()` or `customer_signup_allowed()` throws or returns null, the
  screen shows the normal email/password form, hides create-account options and
  never displays the raw error.
- Sessions live in the platform secure store. `initialize()` migrates a legacy
  `SharedPreferences` session exactly once and only if secure storage has no
  session, so an old copy cannot overwrite a newer one.
- Inactivity: 30 minutes without pointer activity signs out; returning to the
  app after a longer absence signs out immediately.

## Money

- `lib/data/sale_math.dart` rounds each line to two decimals and derives the
  sale total from the rounded lines, so the printed line totals always add up.
- The database remains the owner of posted totals, stock movements, cash rows
  and refund cash. The app does not insert its own stock/cash side effects for
  void, returns, production or transfers.

## Data access

- Reads time out after 20 seconds and retry once. Writes are never retried.
- `BranchRepository.listAll` pages with `offset`/`limit` until a short page is
  returned, so exports are not capped at PostgREST's 1,000-row default.
- The app never queues offline writes. A failed save tells the user it was not
  saved; this is deliberate, to avoid duplicate sales after reconnection.

## Database / SQL

- The live Supabase schema is authoritative. The committed snapshot
  `supabase/fixtures/live_schema.sql` is used to build disposable test
  databases; the absent migrations `20261114000001`–`000015` are not replayed.
- `20261115000001_security_hardening.sql` keeps `has_admin()` and
  `customer_signup_allowed()` executable by `anon` and `authenticated`, grants
  the RLS helpers and `next_number` only to `authenticated`, keeps
  `void_sale`/`fn_generate_*`/`fn_close_day` authenticated-only, and sets every
  view to `security_invoker`. These rules are asserted by the contract.
- The three `20261115*` migrations have **not** been applied to the hosted
  project. The owner applies them in the SQL Editor.
- `void_sale` restores stock through `trg_sales_void`/`fn_sale_void`; returns
  post refund cash through `trg_returns_cash` and stock through
  `trg_return_items_stock`. The app must not duplicate those rows.
- Stock-count statuses are `draft`, `completed`, `cancelled`; only `completed`
  is applied.

## Testing

- SQL contract tests run against a disposable local PostgreSQL with Supabase
  stubs (`tool/run_contract_local.sh`), replaying the live-schema snapshot,
  every committed migration and `contract.sql` in one rolled-back transaction.
  This is the same suite the release integration job runs against
  `supabase start`.
- Widget tests use `offlineSupabaseClient()` (an HTTP mock returning `[]`) or a
  purpose-built mock; none uses the real network.
- The button walkthrough taps visible controls on every route and role
  dashboard and fails on any Flutter exception. It found two real bugs.

## Android release

- `minSdkVersion` is 24, which satisfies every plugin (highest requirement 24;
  `flutter_secure_storage` needs 23).
- R8, resource shrinking, ProGuard rules and Dart obfuscation are **enabled**.
  An earlier draft of this file said shrinking was disabled; that is no longer
  true — `android/app/build.gradle.kts` has `isMinifyEnabled = true` and
  `isShrinkResources = true`, and the workflow passes
  `--obfuscate --split-debug-info`.
- If signing secrets are absent, the build is debug-signed and is a
  sideload/testing artifact, not a Play Store release.

## CI / supply chain

- All workflow actions are pinned to commit SHAs with the version in a comment.
  `supabase/setup-cli@v1` did not exist as a ref and was corrected to `v1.7.3`.
- CI runs static analysis, the full test suite, formatting, schema checks, OSV
  dependency scanning and a Gitleaks history scan.
- The Android workflow verifies that the embedded Supabase JWT has role `anon`
  and scans the built APK for secret-like strings before publishing.
- The smoke job only gets `contents: read`; write permission stays with the
  release job.

## Known limitations (accepted)

- No offline write queue; no MFA; no self-service password reset; no barcode
  scanning; no push notifications; no screenshot protection on payroll.
- Universal APK is large; split-per-ABI is optional.
- Global `anon` revocation is applied by SQL migration, not by the app.
- PostgreSQL role switching in the local contract is not a substitute for a
  real GoTrue sign-in; the release integration job performs that run.
