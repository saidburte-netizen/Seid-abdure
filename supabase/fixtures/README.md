# Live schema fixture

`live_schema.sql` is a **schema-only** fixture generated read-only from the
hosted Supabase project through the Management API. It exists so the
integration tests can run on a disposable local Supabase stack even when the
15 application migrations are not present in the checkout.

It contains:

- table, column, constraint, index, view, function, trigger and policy
  definitions for `public`;
- the `storage.objects` avatar policies and the `avatars` bucket row;
- catalog rows for `roles`, `permissions`, `role_permissions` and
  `app_settings`;
- no customer, sale, cash, payroll or other business rows;
- no API keys, service-role keys, passwords or tokens.

It is **not** a migration and must never be applied to the hosted project.

Regenerate it with the read-only helper:

```bash
SUPABASE_ACCESS_TOKEN=... python3 tool/dump_live_schema.py \
  --project-ref nmrpmypgkljmtnsvmcfn \
  --out supabase/fixtures/live_schema.sql
```

The `Supabase integration` workflow prefers the uploaded
`supabase/migrations/20261114000001_foundation.sql` when it exists. Otherwise it
starts a disposable local stack with the application migrations moved aside,
applies this fixture, seeds the minimal role/permission catalog and runs
`supabase/tests/integration/contract.sql`.
