# Hosted Supabase setup

Plain steps for the owner. Do these in the Supabase Dashboard for project
`nmrpmypgkljmtnsvmcfn`. Menu names can move slightly; look under
**Authentication** and **Database**.

## 1. Signup emails do not arrive

Supabase's built-in email sender is only for testing. It sends about **2 emails
per hour** for the whole project and only to addresses on your Supabase team.
Real staff addresses will fail with "Email address not authorized".

Choose one:

### Option A - turn off email confirmation (fastest for staff-only)

1. Open **Authentication → Providers → Email**.
2. Turn **Confirm email** off and save.
3. Sign up or sign in again.

New accounts work immediately. Only do this if you also disable public signups
(section 4), otherwise anyone who knows the project URL can create an account.

### Option B - use your own SMTP (recommended for real use)

1. Create an account with an email provider such as Resend, Brevo, SendGrid,
   Postmark or Amazon SES.
2. Copy its SMTP host, port, username, password and sender address.
3. In Supabase open **Authentication → SMTP Settings** (or **Emails → SMTP**).
4. Enable custom SMTP and enter the details. Use a sender address you own.
5. Save, then send a test email.
6. Open **Authentication → Rate Limits** and raise the email limit if needed.
   Custom SMTP starts at **30 emails per hour**; the provider has its own quota.

Custom SMTP is included on the Free plan. The email provider may charge you;
free tiers and limits change, so check the provider's current price page.

## 2. Rate limits

Open **Authentication → Rate Limits**. Current Supabase defaults:

| Action | Default |
| --- | --- |
| Sign-ups and sign-ins | 30 requests per 5 minutes per IP |
| Token refresh | 150 requests per 5 minutes per IP |
| Auth emails, built-in sender | 2 per hour for the whole project |
| Auth emails, custom SMTP | 30 per hour at first |
| Repeat email to the same user | 60 seconds |

For a small shop these defaults are usually enough. Raise them only if real
staff hit "too many requests". Do not set them very high; that makes abuse
easier. The app shows a friendly message instead of the raw 429 error.

## 3. Backups

### Free plan

- **No automatic backups.** If data is lost, only your own export can restore it.
- Export regularly with the Supabase CLI and keep the file off Supabase:

  ```sh
  supabase login
  supabase link --project-ref nmrpmypgkljmtnsvmcfn
  supabase db dump -f backup-$(date +%F).sql
  ```

- Check that the file is not empty. Store it on another disk or cloud account.
- Database exports do **not** include files in Storage (avatars, documents).
  Download those separately.
- Free projects **pause after 1 week without activity**. Open the app or
  dashboard regularly, or upgrade.
- Free includes about 500 MB database, 1 GB file storage, 50,000 monthly active
  users and 2 active projects.

### Pro plan

- From about **$25/month**.
- Includes **7 days of daily backups**.
- Projects do not pause for inactivity.
- Point-in-time recovery (PITR) is a separate paid add-on, about **$100/month
  for a 7-day window**, and needs at least Small compute. Check the current
  price before enabling it.
- Backups still do not include Storage objects.

Test a restore on a separate staging project before you need it. Never restore
production data into a public or shared project.

## 4. Disable public signups (staff only)

Do both steps:

1. In Supabase open **Authentication → Providers → Email** and turn
   **Allow new users to sign up** off.
2. In the app, open **Settings → App settings** and turn customer signup off.
   If that switch is not visible, run this in the SQL Editor:

   ```sql
   insert into public.app_settings (key, value)
   values ('allow_customer_signup', '{"enabled": false}'::jsonb)
   on conflict (key) do update
   set value = excluded.value;
   ```

   Do **not** run `supabase/sql/allow_customer_signup.sql` afterwards; that file
   turns customer signup back on.

Now create staff yourself:

1. Supabase **Authentication → Users → Add user**. Create an email/password
   user, or send an invite.
2. In the app sign in as admin and open **Settings → Users**.
3. Set the new user's branch and role.

The first account is still created in the app with **Create the first account**.
After that, the admin creates staff.

## 5. MFA and admin safety

This app does **not** have an MFA enrollment screen yet. Do not force MFA for all
users until that screen exists, or staff may be locked out.

Instead:

- Use long, unique passwords for admin accounts.
- Keep the admin account count small.
- Never put the `service_role` key in the app or repository. The app uses only
  the public anon key.
- Revoke and rotate any token or key that was ever exposed.

## 6. Quick cost summary

| Item | Free | Pro |
| --- | --- | --- |
| Monthly price | $0 | from about $25 |
| Database | 500 MB | 8 GB disk |
| File storage | 1 GB | 100 GB |
| Monthly active users | 50,000 | 100,000 |
| Automatic backups | none | 7 days daily |
| PITR | not available | paid add-on |
| Pauses after inactivity | after 1 week | never |
| Custom SMTP | included | included |

Prices and limits change. Check the Supabase pricing page before upgrading.
