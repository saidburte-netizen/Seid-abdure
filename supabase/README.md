# Supabase project notes

## Live project is authoritative

The deployed app targets the existing Supabase project
`nmrpmypgkljmtnsvmcfn`. Its live schema contains 68 tables, 13 views, the roles
`admin`, `manager`, `cashier`, `baker`, `store_keeper`, `hr_officer`,
`accountant`, `staff`, and `customer`, and the RPCs `fn_close_day`,
`fn_generate_alerts`, `fn_generate_payroll`, `fn_generate_rent_invoices`, and
`next_number`.

The application was written against an introspection of that live project
(PostgREST OpenAPI plus read-only SQL inspection). No table, view, role,
permission, policy, trigger, or function was changed.

## Migrations in this folder

The timestamped SQL files were moved to `supabase/legacy_migrations/`. They
describe an earlier schema and do **not** match the live project. Do not run
`supabase db push`, `supabase db reset`, or `supabase migration up` against the
live project with those files. `supabase/migrations/` contains only a README.

There is no new migration for this delivery because the live schema already
contains every object the app needs. If a future change is required, add one
new numbered migration that contains only that change, test it on a disposable
project, and never replay the legacy files.

## Adding users

1. The first account created in Supabase Auth receives the `admin` role from
   the live `handle_new_user` trigger.
2. Later accounts are created by sign-up and initially receive `staff`.
3. An administrator opens **Settings → Users**, sets the user's branch and role,
   and saves.
4. Role permissions are read from `role_permissions`; the app never hard-codes
   a role-to-screen map beyond the live permission keys.

### One-time sign-in SQL

The sign-in screen calls `has_admin()` to decide whether the business still
needs its first administrator, and calls `customer_signup_allowed()` before
offering customer self-service sign-up. Both functions are security-definer
RPCs that anonymous visitors may execute. The app never reads `app_settings`
before sign-in, because anonymous SELECT on that table is blocked by RLS.

Install both one-time scripts once:

```bash
supabase db execute --file supabase/sql/has_admin.sql
supabase db execute --file supabase/sql/allow_customer_signup.sql
```

If `customer_signup_allowed()` is unavailable or returns false, customer
sign-up stays hidden and the app asks visitors to contact an administrator.
Do not grant public SELECT on the whole settings table.

## Required build variables

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

The service-role key is not used by the Flutter app and is not required by any
remaining workflow. Schema inspection was performed once and then removed from
the repository.

## Profile photo storage

Run `supabase/sql/202611140001_avatars_storage.sql` once in the Supabase SQL
editor to create the public `avatars` bucket and let each signed-in user upload
only inside `avatars/<their-user-id>/`. The app uploads the selected photo and
saves its public URL in `profiles.avatar_url`; if the bucket is missing, the
Profile screen shows a friendly error and the rest of Settings still works.
