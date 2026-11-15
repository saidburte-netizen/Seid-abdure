# Brade and Cake House — Privacy Notice

Last updated: 2026-11-15 · Applies to app version 1.0.8

## What the app stores

### On the device

- Your selected language, theme and branch.
- Your sign-in session token, kept in the platform secure store (Android
  Keystore / iOS Keychain). A migration removes any older plain-text copy.
- No business records are cached on the device and no offline write queue
  exists, so sales and payments are never stored on the phone waiting to sync.

### In the organization's database

The app sends the records you enter to the organization's Supabase project:

- Account details: name, e-mail, phone, role, branch access and optional photo.
- Business records: sales, sale items and payments, returns and voids, stock and
  stock counts, production, cash and expenses, customers and suppliers, credit
  and receivables, employees and attendance, payroll, rentals and rent payments,
  approvals, notifications and audit entries.

Access to those records is enforced by database row-level security and by the
role and branch permissions your administrator assigns.

## What the app does not do

- No advertising, analytics or crash-reporting service is embedded.
- No data is sold, rented or shared for marketing.
- No `service_role` key is embedded. The app uses only the Supabase anon key and
  still requires a signed-in user for table access.
- No raw SQL, database URL or technical error text is shown to users.
- No screenshot or screen-recording protection is enabled.

## Why the data is used

- To sign you in and keep your session.
- To record and calculate sales, stock, cash, payroll, rent and credit.
- To enforce permissions and produce reports and exports.
- To keep an audit trail of sensitive changes.

## How long data is kept

The organization's administrator decides the retention period for business
records and audit entries. Deleting the app removes the device's session and
preferences but not the organization's records.

## Your choices

- Change your name, phone, photo, password and language in Settings.
- Sign out at any time; the local session is cleared.
- Ask an administrator to correct or delete records, or to deactivate an
  account that should no longer have access.
- Ask the business owner for a copy of the records held about you.

## Security measures

- HTTPS for all communication with the database.
- Session tokens in the platform secure store.
- Automatic sign-out after 30 minutes without interaction.
- Android backup disabled and cleartext HTTP disabled in the release build.
- Release builds are minified, resource-shrunk and Dart-obfuscated.

## Contact

For privacy questions, contact the business owner or your branch administrator.
The handover support address is:

> support@bradeandcakehouse.example

Replace it with the business's real contact address before distributing this
pack.
