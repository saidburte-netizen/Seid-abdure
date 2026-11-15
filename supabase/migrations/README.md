# Active migrations

The live Supabase project remains authoritative. The fifteen uploaded
`20261114000001`–`20261114000015` migrations are the intended source of truth
and were not edited. They are not present in this checkout; when they are
supplied, they belong here and should be applied in order.

One later migration is committed here:

- `20261114000016_void_sale.sql`

The app calls `void_sale`, but the read-only live-schema snapshot does not
expose that RPC. This migration adds only that missing function. It allows
admin, manager, accountant and cashier roles, rejects an already-void sale,
reverses cash and credit, and relies on the existing `trg_sales_void` and
`trg_sales_audit` triggers for stock and audit. It never inserts stock movements
itself, so stock is restored exactly once. Execute is revoked from `public` and
`anon` and granted to `authenticated`.

The copy-paste SQL is in `docs/SQL_TO_RUN.md`. Apply it to the hosted project
with the Supabase CLI or SQL editor:

```bash
supabase db push
# or
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 \
  -f supabase/migrations/20261114000016_void_sale.sql
```

Do not edit the fifteen uploaded migrations. Do not apply
`supabase/fixtures/live_schema.sql` to the hosted project; it is a schema-only
snapshot for disposable local/CI runs. The older
`20261113020000_organizations_rls.sql` file is in `../legacy_migrations/` and
must not be replayed.
