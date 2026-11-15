# Implementation plan

Status after the completion pass. `[x]` means implemented and validated in the
repository or in a CI gate.

1. [x] Configure GitHub Actions for Flutter and Supabase tools.
2. [x] Record scope, assumptions, architecture and runbooks.
3. [x] Create the Flutter app shell, branded theme, routing and localization.
4. [x] Add Supabase Auth, profile onboarding, owner claim and role-based guards.
5. [x] Create organization, branches, profiles, roles, permissions and RLS.
6. [x] Create products, recipes and production batches.
7. [x] Implement stock ledger, purchasing, suppliers and stock controls.
8. [x] Implement sales, POS, payments, receipts and daily close.
9. [x] Implement customers, credit, returns and receivable ledger.
10. [x] Implement cash accounts, transactions, expenses, bills and approvals.
11. [x] Implement employee records, attendance, shifts and leave workflows.
12. [x] Implement payroll, advances, payslips and configurable deductions.
13. [x] Implement properties, leases, rent invoices and maintenance.
14. [x] Implement supplier payables, aging and statements.
15. [x] Implement notifications, preferences and alert generation.
16. [x] Implement dashboards, reports, filters, CSV and branded PDF exports.
17. [x] Add private storage buckets and secure document policies.
18. [x] Add offline POS cache and idempotent synchronization.
19. [x] Add accessibility, responsive layouts and localized currency/date
    formats. Material semantics, back arrows, responsive layouts and en/am/om
    navigation are present; the sign-in screen has a pre-login language menu.
20. [x] Add audit logging, settings, data export and backup runbooks. Audit,
    settings and export are implemented; backup/PITR steps are documented in
    `docs/RUNBOOK.md` for the deployment owner.
21. [x] Add focused unit, widget, integration and database regression tests.
    The Flutter suite, route/colour probes, offline evidence test, live-schema
    contract (`supabase/tests/integration/contract.sql`) and Android emulator
    smoke test are automated in CI.
22. [x] Validate schema references, RLS coverage, workflows and user journeys.
23. [x] Complete setup/deployment documentation and final audit.

Current completion: **23/23 complete**. The app is distributed as a
debug-signed sideload/testing build; Google Play and release signing are not
targets for this release. Deployment-only tasks that require the project owner
(hosted backups/PITR, SMTP, rate limits, native-speaker review, and token
rotation) are listed in `docs/GAP_REPORT.md`. The 15 uploaded migrations
`20261114000001`–`20261114000015` are still absent from `origin/main`; upload
them before treating the repository as the authoritative migration source.

## Post-release completion pass (1.0.6)

These are the remaining hardening jobs after the 23-item build plan. `[x]`
means implemented and covered by a local or CI gate.

- [x] Add `void_sale` role check for admin, manager, accountant and cashier.
- [x] Reject a second void with a friendly message.
- [x] Revoke execute from `public` and `anon`; grant only `authenticated`.
- [x] Never insert stock movements from `void_sale`; rely on `trg_sales_void`.
- [x] Reverse direct cash payments and received credit payments.
- [x] Write off the linked receivable and post the balancing customer ledger.
- [x] Prove exact pre-sale stock and cash restoration in the contract.
- [x] Prove credit receivable and ledger reversal in the contract.
- [x] Prove staff cannot void and a second void is rejected.
- [x] Show a localized friendly message for every void failure in the app.
- [x] Put the exact copy-paste SQL in `docs/SQL_TO_RUN.md`.
- [x] Confirm the 15 migrations are still absent and keep the fixture path.
- [x] Keep legacy migrations isolated in `supabase/legacy_migrations/`.
- [x] Add `docs/OWNER_TEST_CHECKLIST.md`.
- [x] Add `docs/HOSTED_SETUP.md` with SMTP, rate limits, backups and signups.
- [x] Update PLAN, GAP_REPORT, QA_REPORT, WIRING, TESTING, RUNBOOK, README and
  signing notes for the debug-signed sideload decision.
- [x] Bump the patch version and build number.
- [x] Run clean format, analyze and the full Flutter test suite.
- [x] Build and verify the APK/AAB/web ZIP in CI.
- [x] Run the Android emulator smoke test and upload screenshots.
- [x] Publish the GitHub Release with checksums.
