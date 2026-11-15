# Brade and Cake House — Support Notes

Version 1.0.8

## Who to contact

Contact your branch administrator or the business owner first. They can reset
a password, change a role, correct a business record, or escalate to whoever
maintains the app.

The maintainer's support address for this handover is:

> support@bradeandcakehouse.example

Replace that address with the business's real support mailbox before giving
this pack to staff. The app itself does not send e-mail or open a support
ticket; **Settings → Help** only explains what to include in a report.

## What to include in a support request

1. App version (Settings → About) and build type (APK, AAB or web).
2. Device model and Android version, or browser and version for the web portal.
3. Your role and branch.
4. The screen and the action you were taking.
5. The exact friendly message shown on screen and the time it happened.
6. Whether the device had a working internet connection.

Never send passwords. Session tokens are not needed and should not be copied.

## Known limitations in this release

| Area | Limitation |
| --- | --- |
| Offline writes | No offline queue. Saves require connectivity and are never retried automatically. |
| Reports | A single screen shows at most 500 rows; CSV and PDF exports fetch all pages. |
| Password reset | No self-service reset. An administrator resets the password. |
| Multi-factor authentication | Not available. |
| Barcode scanning | Not available. Search for products by name. |
| Screenshot protection | Payroll screens do not block screenshots. |
| Push notifications | Alerts appear inside the Notifications screen only. |

## If the app cannot sign in

- Check the device time is automatic and roughly correct.
- Check the connection; the sign-in screen works with a normal connection only.
- If the screen shows only the e-mail and password form, the app could not read
  the login options. Try again later; if it persists, the administrator should
  check that the Supabase project is running and that the login helper
  functions are granted to anonymous callers.
- A "not authorised" message means the account exists but is not allowed to do
  that action. The administrator must adjust the role or branch assignment.

## Data and recovery

- Business records live in the organization's Supabase project, not on the
  phone. Reinstalling the app does not delete business data.
- Reinstalling signs the user out because the secure session is removed with
  the app. Signing in again restores access.
- The owner should keep the database backup policy and the migration files
  under version control. The app does not provide a restore button.

## Security notes for administrators

- The app embeds only the Supabase **anon** key. The `service_role` key must
  never be placed in the app or in `--dart-define` values.
- Sessions are stored in the platform secure store and expire after 30 minutes
  of inactivity.
- Android backup and cleartext HTTP are disabled in the release manifest.
- The three SQL migrations in `supabase/migrations/20261115*` must be applied in
  the Supabase SQL Editor by the owner before relying on the hardened access
  rules.
