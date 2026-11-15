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
13. The Oromo locale lacked Flutter Material and Cupertino localizations.
    Oromo-specific framework delegates now load English framework labels while
    the app continues to use `app_om.arb`.
14. Saved locale restoration now validates language codes, resets invalid or
    crash-marked locales to English, and shows a localized recovery notice.
    The global crash screen also has **Try again** and **Reset language**
    actions; technical details remain in the private logger.
15. Intl date, quantity and ETB currency formatting now uses a supported
    locale, mapping Oromo to English, and date data is initialized at startup.
16. Added an app-level smoke test that boots the real router at each route in
    English, Amharic and Oromo and exercises Admin, Manager and User dashboards.
    Additional tests cover live locale switching, formatting, ARB keys and
    placeholders, crash recovery, and privacy of user-facing error messages.

## Database decision

The live project remains authoritative. The fifteen uploaded
`20261114000001`–`20261114000015` migrations are the intended source of truth
and were not edited.

A real mismatch was found while diffing the app's RPC calls against the
read-only live-schema snapshot: the app calls `void_sale`, but the live schema
does not expose that RPC. One later-timestamp migration was added:

- `supabase/migrations/20261114000016_void_sale.sql`

It creates `public.void_sale(uuid, text)`, checks the
admin/manager/accountant/cashier role with `has_any_role`, rejects a sale that
is already void, reverses cash sale payments and received credit payments,
writes off the remaining receivable with a balancing customer-ledger credit,
updates the sale to `void`/`refunded`, and lets the existing `trg_sales_void`
and `trg_sales_audit` triggers restore stock and write the audit row. The RPC
never inserts a stock movement itself, so stock is restored exactly once. The
local contract proves stock and cash return to their exact pre-sale values,
credit receivables and the customer ledger are reversed, staff are denied, and
a second void is rejected with a friendly message.

Apply the exact SQL to the hosted project with the Supabase CLI or SQL editor.
The copy-paste version is in `docs/SQL_TO_RUN.md`:

```bash
supabase db push
# or
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 \
  -f supabase/migrations/20261114000016_void_sale.sql
```

No other migration is required. The read-only live-schema fixture under
`supabase/fixtures/live_schema.sql` is used only for disposable local/CI runs
and must never be applied to the hosted project.

**The fifteen uploaded migrations are still not on `origin/main`.** The
repository currently contains only `20261114000016_void_sale.sql` and the
migration README. Upload the fifteen files before relying on `supabase db push`
as the authoritative migration run. They were not edited.

## Remaining limitations

The requested operational modules (HR, cash and expenses, stores/inventory,
production, POS/sales, rentals, credit/debit, reports, and notifications) are
present in the existing app and are covered by the route smoke test. No TODO,
FIXME, “coming soon”, or null-button placeholders were found in `lib/`.

The following work still depends on product or deployment owners and is not
silently treated as complete:

- **Operational translation coverage:** 152 UI phrases, all 81 schema titles,
  all 277 field labels, 16 templates and a 280-word fallback dictionary are
  covered in en/am/om. ARB key/placeholder parity and live locale switching are
  tested. A native-speaker review of domain wording is still recommended before
  an Amharic/Oromo-only rollout.
- **Android distribution:** this release is a debug-signed sideload/testing
  build. Google Play is not a target, and no keystore work is required. If
  Android says **App not installed**, uninstall the previous version first;
  data is safe in Supabase. The optional `generate-keystore` workflow remains
  available for a future release-signed build.
- **Backups and account security:** the Supabase Free plan has no automatic
  backups; export regularly or upgrade to Pro for 7-day daily backups. PITR is
  a paid add-on. SMTP and rate limits still need to be configured in the hosted
  project. MFA is not implemented in the app, so do not force it yet. See
  `docs/HOSTED_SETUP.md`.
- **Business rules:** payroll tax/deduction defaults require review by a local
  accountant.
- **Additional user onboarding:** later users sign up, then an administrator
  assigns their branch and role under **Settings → Users**. Only first-admin
  setup is self-service. To create staff only from the admin account, disable
  public signups in Supabase Auth and in app settings as described in
  `docs/HOSTED_SETUP.md`.
- **Role-wide notification receipts:** the live RLS update policy only lets a
  user mark their own notifications read, so role-wide notifications remain
  unread until addressed to a specific user.
- **Accessibility and platform behavior:** every icon-only action has a
  localized tooltip, and back navigation, responsive layout and semantics are
  covered by the route tests. A native screen-reader spot-check on a physical
  device is recommended post-release; desktop PDF sharing depends on
  platform/plugin support.
- **Optional web deployment:** GitHub Pages runs only when `ENABLE_PAGES` is
  `true`; the complete web ZIP is built independently.

One later-timestamp migration (`20261114000016_void_sale.sql`) is committed and
must be applied to the hosted project; the fifteen uploaded migrations were not
edited. The live schema remains authoritative for every other object.
