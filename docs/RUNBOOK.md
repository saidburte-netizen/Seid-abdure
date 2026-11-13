# Operations runbook

## First deployment

1. Create the Supabase project and set a strong database password.
2. Apply migrations from a trusted workstation:
   ```sh
   supabase link --project-ref <ref>
   supabase db push
   ```
3. Create the first Auth user (email/password or invite).
4. Build the client with the project URL and public publishable key:
   ```sh
   flutter build web --release \
     --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
     --dart-define=SUPABASE_PUBLISHABLE_KEY=<public-key>
   ```
5. Sign in and use **Claim owner account** once. Verify the branch, owner role
   and settings appear.
6. Add staff users in Auth, then **Settings → Members** with the correct role.
7. Configure **Settings → Organization**, **Branch**, numbering and payroll
   defaults.
8. Seed stores, cash accounts, units/products, suppliers and opening stock
   before the first live sale.

## Daily close

1. Count the cash drawer.
2. Open **Cash → Daily close**.
3. Enter counted cash and notes. The server calculates expected cash from cash
   transactions and sales, records variance and prevents duplicate closes for
   the same business date.
4. Investigate any variance before the next day.

## Payroll cycle

1. Confirm attendance, leave and advances.
2. **Payroll → Run payroll** for the period.
3. Review gross, deductions and net totals.
4. **Approve / pay**, selecting the cash or bank account.
5. Distribute branded PDF payslips from the payslip row action.

## Rent cycle

1. Ensure active leases have the correct rent and payment day.
2. **Rentals → Invoices → Generate rent invoices** for the month.
3. Record payments against the invoice and cash account.
4. Review the rent roll and outstanding balance in Reports.

## Backup and restore

- Enable Supabase daily backups/PITR for production.
- Before a major migration, take an on-demand backup and export a full branch
  JSON from **Reports → Full branch export**.
- Restore to a staging project first; verify RLS with `supabase test db`.
- Never restore production data into a public or shared project.

## Incident checklist

1. Revoke exposed keys/tokens immediately.
2. Disable compromised Auth users and rotate their passwords.
3. Inspect `audit_logs` for the affected branch and time range.
4. Preserve database/storage evidence before remediation.
5. Patch the root cause, add a regression test and redeploy.
6. Record the incident, impact and follow-up owner.

## Health checks

- `flutter analyze`, `flutter test`, `flutter build web`.
- `supabase db reset` and `supabase test db` on a clean database.
- `select * from public.rls_coverage where not rls_enabled or policy_count = 0;`
- Check notification counts and failed offline batches:
  ```sql
  select status, count(*) from public.pos_sync_batches group by status;
  ```
- Review failed/rejected offline payloads and retry after correcting data.
