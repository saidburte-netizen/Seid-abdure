# Active migrations

The live Supabase project remains authoritative. The fifteen uploaded
`20261114000001`–`20261114000015` migrations are the intended source of truth
and were not edited. They are not present in this checkout; when they are
supplied, they belong here and should be applied in order.

One earlier migration is committed here:

- `20261114000016_void_sale.sql`

Four later migrations are committed here and must be applied in order:

- `20261115000001_security_hardening.sql`
- `20261115000002_ethiopian_date_defaults.sql`
- `20261115000003_performance_indexes.sql`
- `20261115000004_business_rule_guards.sql`

`20261115000001` revokes anonymous table/view access, fixes the storage bucket
limits, and restores the documented execute matrix. `20261115000002` sets the
Ethiopian date defaults. `20261115000003` adds the report indexes.
`20261115000004` adds the payment, closed-day, payroll, credit-limit and
active-record guards, and revokes its new trigger helpers from `public`, `anon`
and `authenticated`.

The copy-paste `void_sale` SQL is in `docs/SQL_TO_RUN.md`. Apply the migrations
to the hosted project with the Supabase CLI or SQL editor:

```bash
supabase db push
# or, in this order
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 \
  -f supabase/migrations/20261115000001_security_hardening.sql
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 \
  -f supabase/migrations/20261115000002_ethiopian_date_defaults.sql
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 \
  -f supabase/migrations/20261115000003_performance_indexes.sql
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 \
  -f supabase/migrations/20261115000004_business_rule_guards.sql
```

Do not edit the fifteen uploaded migrations. Do not apply
`supabase/fixtures/live_schema.sql` to the hosted project; it is a schema-only
snapshot for disposable local/CI runs. The older
`20261113020000_organizations_rls.sql` file is in `../legacy_migrations/` and
must not be replayed.
