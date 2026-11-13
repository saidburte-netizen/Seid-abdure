# Final audit

## Fixed during completion

- Added explicit API grants so `authenticated` can reach RLS-protected tables;
  revoked `anon` and set default privileges for future migrations.
- Fixed ambiguous `sale_return` alias in `process_sale_return`, found by the
  end-to-end RPC smoke test.
- Fixed the audit trigger crashing on singleton tables whose key is boolean
  (`organization_settings`); non-UUID ids now audit with a null entity id.
- Aligned stored organization defaults with the official business name.
- Fixed the rent invoice client call to match `generate_rent_invoices(branch,
  period_start)`.
- Added direct-route permission guards so `/settings`, `/payroll` and other URLs
  cannot bypass the drawer/module permission checks.
- Added explicit app branding, launcher icons, adaptive foreground at the 66%
  safe zone, opaque iOS icons, white transparent notification icon, light/dark
  native splash and platform display names.
- Added branded PDF output for receipts, rent invoices, payslips and reports.
- Replaced obsolete scaffold strings and expanded English/Amharic/Afaan Oromo
  catalogs for auth, portals, navigation, dashboard metrics and common actions.
- Removed all analyzer issues; `flutter analyze` is clean.

## Verified

- All 20 migrations apply cleanly with `ON_ERROR_STOP=1`.
- RLS is enabled on all 67 public tables and every table has a policy
  (`rls_coverage` returns zero gaps).
- 29 permission keys are seeded.
- Owner bootstrap, cash sale, return, rent invoice/payment, payroll
  run/approval, dashboard report and alert refresh execute successfully.
- A user without membership cannot sell, see branches or see memberships; they
  see only their own profile.
- Flutter widget tests pass and the web release build succeeds.

## Residual risks and follow-up

- UI copy on deep operational screens is still mostly English; the localization
  framework and all navigation/auth/dashboard strings are complete, but a full
  domain-label translation pass is recommended before an Amharic/Oromo-only
  rollout.
- Automated coverage is focused on schema/RLS and core smoke flows; add widget
  tests per screen and integration tests for each approval workflow.
- Payroll tax/deduction defaults must be reviewed by a local accountant.
- Backups/PITR, SMTP, MFA, rate limits and Android signing are deployment
  configuration and must be enabled by the owner; they are not committed.
- Desktop share-sheet behavior depends on the platform; generated PDFs are
  still produced and the plugin handles supported platforms.
- Accessibility has semantic labels on key brand/logo controls but has not had
  a full screen-reader audit.

## Security warning

If the GitHub token used to push this repository was ever visible in a
terminal, chat, issue or commit, revoke it now and replace it with a credential
helper/GitHub CLI login. Do not store a plaintext token in the git remote.
