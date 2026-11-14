# Operations runbook

## First deployment

1. Create the Supabase project and set a strong database password.
2. Apply the fifteen uploaded migrations plus the later void-sale migration
   from a trusted workstation:
   ```sh
   supabase link --project-ref <ref>
   supabase db push
   ```
   The exact new SQL is `supabase/migrations/20261114000016_void_sale.sql`.
3. Create the first Auth user (email/password or invite). The first profile is
   promoted to admin by the live `handle_new_user` trigger.
4. Build the client with the project URL and public publishable/anon key:
   ```sh
   flutter build web --release \
     --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=<public-anon-key>
   ```
5. Sign in. If no branch exists, use **Create the first branch**. The first
   admin sees the full Settings area.
6. Add staff users in Auth, then assign branch and role under
   **Settings → Users**. Customer self-signup is shown only when
   `customer_signup_allowed()` returns true.
7. Configure **Settings → Business**, **Branches**, numbering and payroll
   defaults.
8. Seed stores, cash accounts, units/products, suppliers and opening stock
   before the first live sale.

## Daily close

1. Count the cash drawer.
2. Open **Cash → Daily close**.
3. Enter counted cash and notes. `fn_close_day` calculates expected cash from
   approved cash transactions, records the variance and rejects a duplicate
   close for the same branch and business date.
4. Investigate any variance before the next day.

## Payroll cycle

1. Confirm attendance, leave and advances.
2. **Payroll → Run payroll** for the period (`fn_generate_payroll`).
3. Review gross, deductions and net totals.
4. Set the run to **approved**, then **paid** with the cash/bank account. The
   `fn_payroll_status` trigger marks payslips paid, settles advances and posts
   the cash transaction.
5. Distribute branded PDF payslips from the payslip row action.

## Rent cycle

1. Ensure active leases have the correct rent and payment day.
2. **Rentals → Invoices → Generate rent invoices** for the month
   (`fn_generate_rent_invoices`).
3. Record payments against the invoice and cash account; the payment trigger
   updates the invoice and posts cash.
4. Review the rent roll and outstanding balance in Reports.

## Void and return policy

- A completed sale can be voided once through `void_sale`. It restores stock,
  reverses direct cash and received credit payments, writes off the remaining
  receivable with a balancing ledger credit, and records an audit row.
- A return is recorded through `sale_returns` and `sale_return_items`; the
  triggers restore stock and post the refund cash movement.
- Do not delete sales or cash rows. Use void/return so the audit trail remains
  complete.

## Backup and restore

- Enable Supabase daily backups/PITR for production.
- Before a major migration, take an on-demand backup and export a full branch
  JSON from **Reports → Full branch export**.
- Restore to a staging project first; run the local contract and verify RLS.
- Never restore production data into a public or shared project.

## Android release signing

1. Run **Actions → generate-keystore → Run workflow**.
2. Download the `android-signing-secrets` artifact before its one-day expiry.
3. Back up the JKS and both passwords in a password manager. Losing the
   keystore prevents future Play Store updates.
4. Add the four repository secrets listed in `docs/ANDROID_SIGNING.md`.
5. Re-run **Android build**. The log and release notes state
   `SIGNING_MODE=release` or `SIGNING_MODE=debug`.
6. Switching an installed app from debug to release signing requires one
   uninstall/reinstall.

## Incident checklist

1. Revoke exposed keys/tokens immediately.
2. Disable compromised Auth users and rotate their passwords.
3. Inspect `audit_logs` for the affected branch and time range.
4. Preserve database/storage evidence before remediation.
5. Patch the root cause, add a regression test and redeploy.
6. Record the incident, impact and follow-up owner.

## Health checks

- `flutter analyze`, `flutter test`, `flutter build web`.
- Run `.github/workflows/supabase-integration.yml` and confirm the contract is
  green.
- Confirm RLS is enabled on every public table:
  ```sql
  select c.relname
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;
  ```
- Review the notification inbox and any failed offline POS sync messages shown
  in the app. Offline batches are cached locally; the live schema does not have
  a `pos_sync_batches` table.
