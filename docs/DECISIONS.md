# Brade and Cake House — Decisions (batch 13/90)

## 1. Riverpod removal
- **Decision**: `flutter_riverpod` has been removed from `pubspec.yaml` and `ProviderScope` removed from `main.dart`. 
- **Verification**: `grep -rn "riverpod\|ProviderScope\|ref\.watch\|ref\.read" lib/ test/` returns no results outside generated `.g.dart` files. The app uses `ChangeNotifier` + `InheritedNotifier` (AuthController, SessionScope) as the single state‑management approach.
- **Action**: Keep removal. If any screen fails to refresh after create/update/delete, re‑add Riverpod with a clear migration plan.

## 2. Security migration (20261115000001_security_hardening.sql)
- **Decision**: The migration is kept as printed in full above. It satisfies the non‑negotiable rules:
  - `has_admin()` and `customer_signup_allowed()` stay executable by **both** `anon` and `authenticated`.
  - RLS helper functions (`current_role_code`, `is_admin`, `is_staff`, `has_any_role`, `current_employee_id`, `current_customer_id`, `can_read_bucket`, `can_write_bucket`) are granted only to `authenticated`, not `anon`.
  - `next_number()` stays executable by `authenticated`.
  - `void_sale`, `fn_generate_*`, `fn_close_day` are `authenticated`‑only; never anon.
  - All public views have `security_invoker = true`.
- **Next step**: Add an automated RLS test that logs in as each of the 9 roles and proves read/write boundaries, and that anon can call only `has_admin` and `customer_signup_allowed`. This test uses a mock client for scaffold purposes only; real RLS validation must run against a local Supabase stack (`supabase start` with migrations) in the CI integration workflow at release. Mark "runs in CI integration job at release" — do not mark done until the integration job has executed once.

## 3. R8 / ProGuard
- **Decision**: The local environment has **no Android SDK**, so a release‑APK smoke test cannot be run. To avoid a potentially broken release, we have **disabled shrinking** in `android/app/build.gradle.kts` (`isMinifyEnabled false`, `isShrinkResources false`). 
- **ProGuard rules** (`android/app/proguard-rules.pro`) are in place to keep Flutter embedding, plugin entry points and any Supabase‑related classes. These rules can be kept minimal until an emulator is available.
- **When an emulator becomes available**: re‑enable `isMinifyEnabled true` / `isShrinkResources true`, run the full release smoke test, and tighten ProGuard rules if needed.

## 4. Timezone migration (20261115000002)
- **Decision**: The migration sets `timezone = 'Africa/Addis_Ababa'` on the four functions and changes 17 column defaults to `(now() at time zone 'Africa/Addis_Ababa')::date`. This is kept as the authoritative change. An integration test should verify that an entry at 00:30 Ethiopian time yields the Ethiopian date (not the previous day). This test will be added when the CI environment supports it.

## 5. Flutter analyze / test environment
- **Decision**: The current Flutter tool uses Dart SDK 3.5.4, while the project's `pubspec` requires `>=3.9.0`. Because of this mismatch, `flutter pub get`, `flutter analyze` and `flutter test` cannot be run to completion. All analysis errors (16 issues) are therefore **unverifiable** in this environment. The commit `424f81e` is marked **UNVERIFIED** in `docs/AUDIT_REPORT.md`. Once the Dart SDK is upgraded or the project constraint is relaxed, the analysis and test suite must pass with zero issues.

## 5. Formatting
- **Decision**: `dart format` was run and applied to 32 files; the changes are committed as `cd21a56`. All Dart code now conforms to the project style.

## 6. Remaining work (77 jobs)
- Schema and column mismatch checks (compare Dart tables/views/columns/RPCs against migrations and live schema).
- RLS validation (role‑based access tests).
- Money precision (ensure no `double` arithmetic in write paths; rounding to 2 decimals display).
- Dependency and OSV vulnerability scan (run `osv-scanner` if network available; otherwise document).
- Secret scan of git history and APK strings (run Gitleaks locally; already clean).
- Pagination and timeouts (ensure `listAll` and 20‑second read timeout are wired; prevent double submission).
- State refresh and double‑submit protection (in‑flight guards, idempotency keys).
- Dead buttons / UI walkthrough (role‑based automated walkthrough test).
- Management module business‑rule tests (end‑to‑end for users/roles, branches, stores, cash, products/recipes, stock, production, cake orders, POS, daily closing, cash transfers, bills, customers/suppliers, credit/debit, HR, rentals, notifications, reports/exports, settings and audit).
- Client handover pack in `docs/client/` (`CLIENT_USER_GUIDE.md`, `SUPPORT.md`, `PRIVACY_POLICY.md`, `FEATURES.md`).
- Final report with GO / NO‑GO verdict, checksums, release links, test results, owner actions.

**Job counter**: 13/90 local commits done; 77 remaining. Next batch will continue after this decision document.