# Gap report and delivery audit

## Scope

This audit compares the single Flutter application in this repository with the
live Supabase project at `https://nmrpmypgkljmtnsvmcfn.supabase.co`. The live
database is authoritative. No table, view, role, policy, or function was
recreated or modified for this delivery.

## Result

The app is one Flutter project with one `pubspec.yaml`, one `lib/main.dart`,
one router in `lib/app.dart`, and one navigation drawer. Every screen below is
reachable from that router and is permission-gated against the live
`role_permissions` table.

| Module | Route | Main screens/tabs | Live permission |
| --- | --- | --- | --- |
| Dashboard | `/` | KPIs, sales, stock, alerts | signed-in user |
| Point of sale | `/pos` | catalog, cart, payment, receipt PDF | `pos.use` |
| Sales | `/sales` | sales, items, payments, returns, close day | `sales.view` |
| Production | `/production` | products, categories, units, items, recipes, batches, cake orders | `production.manage` |
| Inventory | `/inventory` | stock, stores, movements, counts, transfers, suppliers, POs, receipts | `inventory.view` |
| Cash and expenses | `/cash` | balances, accounts, transactions, transfers, categories, bills, payables, expenses | `cash.view` |
| People and HR | `/people` | employees, departments, documents, shifts, attendance, leave, advances, notes | `hr.view` |
| Payroll | `/payroll` | runs, payslips, generate/approve/pay, PDF payslip | `payroll.manage` |
| Rentals | `/rentals` | properties, units, tenants, leases, invoices, payments, maintenance | `rentals.manage` |
| Credit and debit | `/credit` | receivables, receipts, payables, payments, write-offs, aging | `credit.manage` |
| Approvals | `/approvals` | approval queue, approve/reject | `expenses.approve` |
| Reports | `/reports` | dashboard, sales, stock, P&L, receivables, payables, rentals, payroll, exports | `reports.view` |
| Notifications | `/notifications` | inbox, mark read, generate alerts, preferences | signed-in user |
| Settings | `/settings` | branch, users, roles, app settings, audit, media | `settings.manage` / `users.manage` |

## Gaps found and fixed

1. The old data layer used table and column names that do not exist in the live
   project. `lib/data/schema.dart` was regenerated from the live PostgREST
   OpenAPI document, and `lib/data/repository.dart` now uses the live
   `branch_id` scoping and primary keys.
2. The old auth flow expected an organization/membership model. It now reads
   `profiles.role_code`, `profiles.branch_id`, `role_permissions`, and
   `branches`, with an admin branch selector and first-branch setup.
3. Payables used the non-live status `unpaid`; the live check constraint accepts
   `open`, `partial`, `paid`, and `cancelled`. The app now inserts `open`.
4. Notification preferences used an upsert key that the live table does not
   guarantee. The app now updates by `id` or inserts a new row.
5. The notification badge and inbox read every row. They now scope to the
   signed-in user or the user's role, matching the live RLS policy.
6. Purchase-order receiving manually advanced `quantity_received` and the PO
   status, duplicating the live `fn_receipt_item_stock` trigger. The app now
   inserts the receipt lines and lets the trigger update stock, quantities and
   status.
7. POS inserted `paid_amount` and then inserted a payment, while
   `fn_sale_payment_apply` also increments `paid_amount`. The app now inserts
   `paid_amount = 0` and lets the trigger own the total. Credit sales insert a
   `credit` payment row for the full total, which makes the live trigger create
   the receivable.
8. Sale returns recorded a refund but did not post the cash movement. The app
   now inserts the matching `cash_transactions` row after the return.
9. The obsolete `payables_screen.dart` and its route were removed; payables are
   part of the single Credit and debit module.
10. The sign-in screen had no way to create the first account. It now has a
    first-account dialog that calls Supabase Auth; the live
    `handle_new_user` trigger assigns `admin` to the first profile.
11. The old build workflow uploaded a directory of web files and several APK
    variants. It now uploads one `brade-cake-house.apk`, one
    `brade-cake-house.aab`, and one `brade-cake-house-web.zip`.
12. Flutter analysis was failing on four async-context diagnostics. All four
    were fixed and `flutter analyze` now reports no issues.

## Database decision

No new migration is required. The live schema already contains the tables,
views, roles, permissions, RLS policies, triggers, and RPCs used by the app.
The timestamped files under `supabase/migrations/` are legacy local-development
migrations and must not be applied to the live project. See
`supabase/README.md`.

## Known limitations

- Android artifacts are debug-signed unless the four signing secrets are
  configured. A debug-signed APK installs normally but cannot be uploaded to
  Google Play as a production release.
- GitHub Pages deployment is optional and only runs when repository variable
  `ENABLE_PAGES` is `true`. The web ZIP is always attached to the release.
- The app has no in-app user-creation screen for additional users; later users
  sign up, then an administrator assigns their branch and role under
  **Settings → Users**. This is intentional because the live auth trigger only
  creates the first admin automatically.
- Role-wide notifications are readable by the role, but the live RLS update
  policy only lets a user mark their own notifications read. Role-wide items
  remain unread until they are addressed to a specific user.
- Custom font files are not used. Flutter's Material icon font is bundled by
  `uses-material-design: true`; translations are compiled into `libapp.so` by
  `flutter gen-l10n` and are not separate downloadable assets.
