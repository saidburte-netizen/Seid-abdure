# Schema check

The deployed Supabase project (`nmrpmypgkljmtnsvmcfn`) is authoritative. The
files in `supabase/legacy_migrations/` describe an older schema and are
deliberately not replayed. The app's compact live-schema snapshot lives in
`lib/data/schema.dart`.

`tool/check_schema.py` is the static gate that keeps Dart code, that snapshot
and the SQL that is actually committed in this repository in agreement.

## Run it

```bash
python3 tool/check_schema.py
python3 tool/check_schema.py --json
python3 tool/check_schema.py --strict-sql
```

CI runs the default command on every push and pull request.

## What it validates

| Check | Source of truth | Failure mode |
| --- | --- | --- |
| `.from('table')` / `.from('view')` | live snapshot + committed SQL | unknown table or view |
| `.storage.from('bucket')` | documented public buckets | unknown bucket |
| `.rpc('function')` | documented live RPCs + committed SQL functions | unknown RPC |
| filter/order column names | `TableSpec` field lists | column missing from the snapshot |
| `status` defaults and select options | SQL `CHECK (status IN (...))` | status value not allowed by SQL |
| `lookupTable` targets | live snapshot + committed SQL | missing lookup table |
| live snapshot objects | committed SQL | warning by default; error with `--strict-sql` |

Common system columns (`id`, `created_at`, `updated_at`, `branch_id`,
`organization_id`, `deleted_at`, `created_by`, `updated_by`) are allowed on
every table even though the compact CRUD field lists do not repeat them.

The checker intentionally does not attempt to parse every PostgREST select
string or join. It validates the high-risk names: tables, views, buckets, RPCs,
filter columns and status values. Complex selects are covered by the Flutter
integration and widget tests.

## Live-only objects

The live project contains 68 tables, 13 views and the roles/RPCs documented in
`supabase/README.md`. Many of those objects are not in the legacy SQL. The
default run prints a `WARN` for each live-only object and still passes. This is
expected and prevents the legacy migrations from being treated as a source of
truth. Use `--strict-sql` only when you are intentionally validating a future
migration set against the snapshot.

## Refreshing the snapshot

When the live schema changes:

1. Add one numbered migration under `supabase/migrations/` containing only the
   change. Do not replay the legacy files.
2. Update `lib/data/schema.dart` from the live introspection (or regenerate it
   with the same tooling used previously).
3. Run `python3 tool/check_schema.py` and `flutter test`.
4. Update this document if the checker's scope changes.
