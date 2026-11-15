#!/usr/bin/env bash
# Run the SQL contract suite against a disposable local PostgreSQL database.
#
# This is the same test the "Supabase integration" CI job runs, without Docker:
# it replays the committed snapshot of the live schema, applies every committed
# migration, seeds the role/permission catalogue and executes contract.sql in a
# single transaction that rolls back.
#
# Requirements: PostgreSQL 16 server binaries. The script never contacts the
# hosted Supabase project.
#
#   ./tool/run_contract_local.sh
#
# Optional environment variables:
#   PGBIN   directory holding initdb/pg_ctl (default: pg_config --bindir)
#   PORT    TCP port for the disposable server (default: 55439)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PGBIN="${PGBIN:-$(pg_config --bindir 2>/dev/null || echo /usr/lib/postgresql/16/bin)}"
PORT="${PORT:-55439}"
DB="brade_contract"
DATA="$(mktemp -d "${TMPDIR:-/tmp}/brade-contract.XXXXXX")"
SOCK="$DATA-socket"
LOG="$DATA/postgres.log"

if [ "$(id -u)" = 0 ]; then
  if ! id postgres >/dev/null 2>&1; then
    echo "Run as a non-root user, or create a 'postgres' user first." >&2
    exit 1
  fi
  chown -R postgres:postgres "$DATA"
  as_pg() { su postgres -s /bin/bash -c "$1"; }
else
  as_pg() { bash -c "$1"; }
fi

cleanup() {
  as_pg "'$PGBIN/pg_ctl' -D '$DATA' -m immediate stop" >/dev/null 2>&1 || true
  rm -rf "$DATA" "$SOCK"
}
trap cleanup EXIT

mkdir -p "$SOCK"
if [ "$(id -u)" = 0 ]; then chown -R postgres:postgres "$SOCK"; fi

echo "Starting disposable PostgreSQL on port $PORT ..."
as_pg "'$PGBIN/initdb' -D '$DATA' -A trust -E UTF8 --locale=C" >/dev/null
as_pg "'$PGBIN/pg_ctl' -D '$DATA' -o '-p $PORT -k $SOCK -c listen_addresses=' -l '$LOG' start" >/dev/null
as_pg "'$PGBIN/createdb' -h '$SOCK' -p $PORT '$DB'"

psql_local() {
  as_pg "'$PGBIN/psql' -h '$SOCK' -p $PORT -d '$DB' -v ON_ERROR_STOP=1 $1"
}

echo "Loading Supabase stubs ..."
psql_local "-q -f '$ROOT/supabase/fixtures/local_supabase_stub.sql'"

# pgcrypto lives in the extensions schema, as it does on Supabase.
psql_local "-q -c 'alter database $DB set search_path = public, extensions'"

echo "Replaying the live schema snapshot ..."
grep -v -e 'supabase_vault' -e 'pg_stat_statements' \
  "$ROOT/supabase/fixtures/live_schema.sql" > "$DATA/live_schema.sql"
chmod 644 "$DATA/live_schema.sql"
psql_local "-q -f '$DATA/live_schema.sql'"

echo "Applying committed migrations ..."
for migration in "$ROOT"/supabase/migrations/*.sql; do
  echo "  $(basename "$migration")"
  psql_local "-q -f '$migration'"
done

echo "Seeding roles, permissions and settings ..."
psql_local "-q -f '$ROOT/supabase/tests/integration/seed.sql'"

echo "Running contract assertions ..."
psql_local "-q -f '$ROOT/supabase/tests/integration/contract.sql'"

echo "CONTRACT PASSED"
