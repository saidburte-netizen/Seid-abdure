#!/usr/bin/env python3
"""Static drift test: app schema vs the committed live schema snapshot.

Compares every ``TableSpec``/``FieldSpec`` in ``lib/data/schema.dart`` with the
tables and views in ``supabase/fixtures/live_schema.sql``.  This catches the
failure mode that matters most after a live migration: a screen that references
a column which no longer exists.

It is deliberately read-only.  It never connects to the live project and never
writes to a database; the authoritative snapshot is the committed fixture.

Output is a per-table table:

    table | app fields | live columns | result | missing in live

Exit status is non-zero when an app table/view or column is missing from the
live snapshot.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tool"))

from check_schema import (  # noqa: E402
    SqlSchema,
    parse_alter_table,
    parse_create_table,
    parse_create_view,
    parse_schema_dart,
    strip_sql_comments,
)

LIVE_SQL = ROOT / "supabase" / "fixtures" / "live_schema.sql"


def parse_live() -> SqlSchema:
    schema = SqlSchema()
    sql = strip_sql_comments(LIVE_SQL.read_text(encoding="utf-8", errors="replace"))
    # pg_dump writes the schema as "public"."table"; the shared parser expects
    # the unquoted public. prefix used by the migrations.
    sql = sql.replace('"public".', "public.")
    parse_create_table(sql, schema)
    parse_create_view(sql, schema)
    parse_alter_table(sql, schema)
    # The shared view parser stops at the first FROM, which under-reports
    # views whose select list contains scalar subqueries (e.g.
    # v_dashboard_kpis). Union in every top-level alias as a safe fallback.
    for match in re.finditer(
        r"create\s+(?:or\s+replace\s+)?(?:materialized\s+)?view\s+"
        r"(?:public\.)?\"?([a-z_][a-z0-9_]*)\"?\s+as",
        sql,
        re.I,
    ):
        name = match.group(1)
        rest = sql[match.end() :]
        next_create = re.search(r"\ncreate\s+", rest)
        body = rest[: next_create.start()] if next_create else rest
        schema.views.setdefault(name, set()).update(
            column.lower()
            for column in re.findall(r"\bAS\s+\"?([a-z_][a-z0-9_]*)\"?", body, re.I)
        )
    return schema


def main() -> int:
    live = parse_live()
    app = parse_schema_dart()
    live_names = set(live.tables) | set(live.views)

    rows: list[tuple[str, str, str, str, str]] = []
    failures: list[str] = []
    app_missing: list[str] = []

    for name, info in sorted(app.items()):
        live_columns = live.tables.get(name)
        if live_columns is None:
            live_columns = live.views.get(name)
            kind = "view"
        else:
            kind = "table"
        if live_columns is None:
            rows.append((name, str(len(info.fields)), "–", "MISSING", "table/view absent"))
            failures.append(f"{name}: table/view is absent from the live snapshot")
            if not name.startswith("v_"):
                app_missing.append(name)
            continue
        missing = sorted(info.fields - live_columns)
        rows.append(
            (
                name,
                str(len(info.fields)),
                str(len(live_columns)),
                "ok" if not missing else "DRIFT",
                "–" if not missing else ", ".join(missing),
            )
        )
        if missing:
            failures.append(f"{name} ({kind}): missing columns: {', '.join(missing)}")

    width = max([len(row[0]) for row in rows] + [5])
    head = (
        f"{'table':<{width}}  {'app':>4}  {'live':>4}  {'result':<6}  "
        "missing app field(s)"
    )
    print(head)
    print("-" * len(head))
    for name, app_count, live_count, result, missing in rows:
        print(
            f"{name:<{width}}  {app_count:>4}  {live_count:>4}  "
            f"{result:<6}  {missing}"
        )

    unused = sorted(live_names - set(app))
    print()
    print(
        f"checked {len(rows)} app tables/views against {len(live_names)} live "
        f"tables/views"
    )
    if unused:
        print(
            f"live objects not described by the app (informational): "
            f"{', '.join(unused[:12])}"
            + (" …" if len(unused) > 12 else "")
        )

    if failures:
        print()
        print(f"DRIFT: {len(failures)} problem(s)")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print("PASS: every app table/view and field exists in the live snapshot")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
