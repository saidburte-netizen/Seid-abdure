# No migrations are applied to the live project

The live Supabase project already contains the full schema used by the app.
This delivery intentionally adds no migration.

The earlier timestamped SQL files were moved to `../legacy_migrations/`. They
describe a different schema and must not be applied to the live project.

If a future schema change is genuinely required, add one new numbered `.sql`
file here containing only that change. Test it on a disposable project first.
