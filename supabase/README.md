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

The timestamped SQL files in `supabase/migrations/` are legacy
local-development migrations. They describe an earlier schema and do **not**
match the live project. Do not run `supabase db push`, `supabase db reset`, or
`supabase migration up` against the live project with these files.

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

## Required build variables

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

The service-role key is not used by the Flutter app and is not required by any
remaining workflow. Schema inspection was performed once and then removed from
the repository.
