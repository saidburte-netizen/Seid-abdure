# Implementation plan

Status after the completion pass. `[x]` means implemented and validated;
`[~]` means implemented with documented follow-up.

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
19. [~] Add accessibility, responsive layouts and localized currency/date
    formats. Responsive layouts and en/am/om navigation are complete; a full
    screen-reader and deep domain-label translation audit remains.
20. [~] Add audit logging, settings, data export and backup runbooks. Audit,
    settings and export are complete; automated backup/PITR is deployment
    configuration.
21. [~] Add focused unit, widget, integration and database regression tests.
    Brand widget tests, pgTAP schema/RLS tests and an end-to-end RPC smoke test
    exist; broader per-screen widget/integration coverage remains.
22. [x] Validate schema references, RLS coverage, workflows and user journeys.
23. [x] Complete setup/deployment documentation and final audit.

Current completion: **20/23 complete, 3 with documented follow-up**. See
`docs/AUDIT.md` for residual risks.
