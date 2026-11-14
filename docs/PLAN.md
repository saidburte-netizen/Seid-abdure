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

Current completion: **23/23 complete**. Deployment-only tasks that require the
project owner (PITR/SMTP/MFA settings, Play Store upload, and copying the
generated keystore into repository secrets) are listed in `docs/GAP_REPORT.md`.
