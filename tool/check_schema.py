#!/usr/bin/env python3
"""Validate Dart Supabase usage against the committed schema snapshot.

The live Supabase project is authoritative.  The legacy migrations in
``supabase/legacy_migrations`` describe an older schema and are deliberately
not replayed.  This checker therefore uses two sources:

* ``lib/data/schema.dart`` - the live-schema snapshot used by the generated
  CRUD screens (tables, views, columns and select options);
* ``supabase/**/*.sql`` - the SQL objects that *are* present in the repository.

It fails when Dart code references an unknown table/view, RPC or column, and
when a status default/option contradicts a SQL CHECK constraint that is present
in the repository.  Missing live-only objects in the legacy SQL are reported as
warnings, not errors, because the live project owns them.

Usage:
    python3 tool/check_schema.py
    python3 tool/check_schema.py --strict-sql   # fail on legacy/live drift too
    python3 tool/check_schema.py --json         # machine-readable summary
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Set, Tuple

ROOT = Path(__file__).resolve().parents[1]
SCHEMA_DART = ROOT / "lib" / "data" / "schema.dart"
LIB_DIR = ROOT / "lib"
SQL_DIRS = [
    ROOT / "supabase" / "migrations",
    ROOT / "supabase" / "legacy_migrations",
    ROOT / "supabase" / "sql",
]

# RPCs documented as live in supabase/README.md.  The legacy migrations only
# contain some of them, so this is the authoritative allow-list for RPC names.
# Columns that are present on every live table but intentionally omitted from
# the compact CRUD field lists in schema.dart.
COMMON_COLUMNS = {
    "id",
    "created_at",
    "updated_at",
    "deleted_at",
    "branch_id",
    "organization_id",
    "created_by",
    "updated_by",
}

# Public storage buckets used by the app.  These are storage objects, not
# PostgREST tables, so they are validated separately.
LIVE_STORAGE_BUCKETS = {"avatars"}

LIVE_RPCS = {
    "fn_close_day",
    "fn_generate_alerts",
    "fn_generate_payroll",
    "fn_generate_rent_invoices",
    "next_number",
    "has_admin",
    "customer_signup_allowed",
}

IDENT = r"[a-z_][a-z0-9_]*"


@dataclass
class TableInfo:
    name: str
    fields: Set[str] = field(default_factory=set)
    status_defaults: Set[str] = field(default_factory=set)
    status_options: Set[str] = field(default_factory=set)
    lookup_tables: Set[str] = field(default_factory=set)
    is_view: bool = False


@dataclass
class SqlSchema:
    tables: Dict[str, Set[str]] = field(default_factory=dict)
    views: Dict[str, Set[str]] = field(default_factory=dict)
    functions: Set[str] = field(default_factory=set)
    check_status: Dict[str, Set[str]] = field(default_factory=dict)


@dataclass
class Usage:
    path: str
    line: int
    kind: str
    name: str
    table: Optional[str] = None


def strip_sql_comments(sql: str) -> str:
    sql = re.sub(r"/\*.*?\*/", " ", sql, flags=re.S)
    sql = re.sub(r"--[^\n]*", " ", sql)
    return sql


def split_top_level(text: str, separator: str = ",") -> List[str]:
    parts: List[str] = []
    current: List[str] = []
    depth = 0
    quote: Optional[str] = None
    i = 0
    while i < len(text):
        ch = text[i]
        if quote:
            current.append(ch)
            if ch == quote:
                if i + 1 < len(text) and text[i + 1] == quote:
                    current.append(text[i + 1])
                    i += 1
                else:
                    quote = None
        elif ch in ("'", '"'):
            quote = ch
            current.append(ch)
        elif ch == "(":
            depth += 1
            current.append(ch)
        elif ch == ")":
            depth = max(0, depth - 1)
            current.append(ch)
        elif ch == separator and depth == 0:
            parts.append("".join(current).strip())
            current = []
        else:
            current.append(ch)
        i += 1
    if current:
        parts.append("".join(current).strip())
    return [part for part in parts if part]


def unquote_identifier(value: str) -> str:
    return value.strip().strip('"').strip("`").lower()


def parse_create_table(sql: str, schema: SqlSchema) -> None:
    pattern = re.compile(
        r"create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?(\"?[a-z_][a-z0-9_]*\"?)\s*\(",
        re.I,
    )
    for match in pattern.finditer(sql):
        name = unquote_identifier(match.group(1))
        start = match.end()
        depth = 1
        quote: Optional[str] = None
        i = start
        while i < len(sql) and depth > 0:
            ch = sql[i]
            if quote:
                if ch == quote:
                    quote = None
            elif ch in ("'", '"'):
                quote = ch
            elif ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            i += 1
        body = sql[start : i - 1]
        columns: Set[str] = set()
        for item in split_top_level(body):
            item = item.strip()
            if not item:
                continue
            first = item.split(None, 1)[0].lower()
            if first in {
                "constraint",
                "primary",
                "foreign",
                "unique",
                "check",
                "exclude",
                "like",
            }:
                # Still collect inline status checks below.
                pass
            else:
                column = unquote_identifier(first)
                if re.match(rf"^{IDENT}$", column):
                    columns.add(column)
            status_match = re.search(
                rf"\bstatus\b[^,;]*?\b(?:in\s*\(([^)]*)\)|=\s*any\s*\(\s*array\s*\[([^\]]*)\])",
                item,
                re.I | re.S,
            )
            if status_match:
                values = status_match.group(1) or status_match.group(2) or ""
                allowed = set(re.findall(r"'([^']+)'", values))
                if allowed:
                    schema.check_status.setdefault(name, set()).update(allowed)
        schema.tables[name] = columns


def parse_create_view(sql: str, schema: SqlSchema) -> None:
    pattern = re.compile(
        r"create\s+(?:or\s+replace\s+)?(?:materialized\s+)?view\s+(?:public\.)?(\"?[a-z_][a-z0-9_]*\"?)\s+as\s+",
        re.I,
    )
    for match in pattern.finditer(sql):
        name = unquote_identifier(match.group(1))
        rest = sql[match.end() :]
        from_match = re.search(r"\bfrom\b", rest, re.I)
        select_list = rest[: from_match.start()] if from_match else rest
        select_list = re.sub(r"^\s*select\s+", "", select_list, flags=re.I)
        columns: Set[str] = set()
        for item in split_top_level(select_list):
            alias = re.search(r"\bas\s+(\"?[a-z_][a-z0-9_]*\"?)\s*$", item, re.I)
            if alias:
                columns.add(unquote_identifier(alias.group(1)))
                continue
            simple = re.match(r"^(?:[a-z_][a-z0-9_]*\.)?(\"?[a-z_][a-z0-9_]*\"?)\s*$", item)
            if simple:
                columns.add(unquote_identifier(simple.group(1)))
        schema.views[name] = columns


def parse_alter_table(sql: str, schema: SqlSchema) -> None:
    pattern = re.compile(
        r"alter\s+table\s+(?:if\s+exists\s+)?(?:only\s+)?(?:public\.)?(\"?[a-z_][a-z0-9_]*\"?)\s+"
        r"(add\s+(?:column\s+)?(?:if\s+not\s+exists\s+)?(\"?[a-z_][a-z0-9_]*\"?)|"
        r"add\s+constraint\s+\S+\s+check\s*\(([^;]*)\))",
        re.I | re.S,
    )
    for match in pattern.finditer(sql):
        table = unquote_identifier(match.group(1))
        column = match.group(2)
        check = match.group(3)
        if column:
            schema.tables.setdefault(table, set()).add(unquote_identifier(column))
        if check:
            status_match = re.search(
                r"\bstatus\b[^,;]*?\b(?:in\s*\(([^)]*)\)|=\s*any\s*\(\s*array\s*\[([^\]]*)\])",
                check,
                re.I | re.S,
            )
            if status_match:
                values = status_match.group(1) or status_match.group(2) or ""
                allowed = set(re.findall(r"'([^']+)'", values))
                if allowed:
                    schema.check_status.setdefault(table, set()).update(allowed)


def parse_sql() -> SqlSchema:
    schema = SqlSchema()
    for directory in SQL_DIRS:
        if not directory.exists():
            continue
        for path in sorted(directory.rglob("*.sql")):
            sql = strip_sql_comments(path.read_text(encoding="utf-8", errors="replace"))
            parse_create_table(sql, schema)
            parse_create_view(sql, schema)
            parse_alter_table(sql, schema)
            for match in re.finditer(
                r"create\s+(?:or\s+replace\s+)?function\s+(?:public\.)?(\"?[a-z_][a-z0-9_]*\"?)",
                sql,
                re.I,
            ):
                schema.functions.add(unquote_identifier(match.group(1)))
    return schema


def parse_schema_dart() -> Dict[str, TableInfo]:
    text = SCHEMA_DART.read_text(encoding="utf-8")
    table_pattern = re.compile(r"^  '([a-z0-9_]+)': TableSpec\(", re.M)
    matches = list(table_pattern.finditer(text))
    tables: Dict[str, TableInfo] = {}
    for index, match in enumerate(matches):
        name = match.group(1)
        start = match.start()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        block = text[start:end]
        info = TableInfo(name=name)
        info.fields.update(
            re.findall(r"FieldSpec\(\s*'([a-z0-9_]+)'", block)
        )
        info.fields.update(
            re.findall(r"listColumns:\s*const\s*\[([^\]]*)\]", block, re.S)[0].split(",")
            if re.findall(r"listColumns:\s*const\s*\[([^\]]*)\]", block, re.S)
            else []
        )
        # The split above leaves quotes/spaces; normalise.
        info.fields = {field.strip().strip("'\" ") for field in info.fields if field.strip()}
        for lookup in re.findall(r"lookupTable:\s*'([a-z0-9_]+)'", block):
            info.lookup_tables.add(lookup)
        # Status fields are the only select fields whose values we can safely
        # compare with SQL CHECK constraints.
        for status_match in re.finditer(
            r"FieldSpec\(\s*'status'\s*,(.*?)\)\s*,", block, re.S
        ):
            body = status_match.group(1)
            default = re.search(r"defaultValue:\s*'([^']+)'", body)
            if default:
                info.status_defaults.add(default.group(1))
            options_match = re.search(r"options:\s*const\s*\{(.*?)\}", body, re.S)
            if options_match:
                info.status_options.update(
                    re.findall(r"'([^']+)'\s*:", options_match.group(1))
                )
        tables[name] = info
    return tables


def line_number(text: str, index: int) -> int:
    return text.count("\n", 0, index) + 1


def scan_dart_usages() -> List[Usage]:
    usages: List[Usage] = []
    for path in sorted(LIB_DIR.rglob("*.dart")):
        if "/l10n/" in path.as_posix():
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        from_positions: List[Tuple[int, str]] = []
        for match in re.finditer(r"\.from\(\s*['\"]([a-z0-9_]+)['\"]\s*\)", text):
            table = match.group(1)
            prefix = text[max(0, match.start() - 20) : match.start()]
            kind = "storage" if ".storage" in prefix else "from"
            if kind == "from":
                from_positions.append((match.start(), table))
            usages.append(
                Usage(
                    str(path.relative_to(ROOT)),
                    line_number(text, match.start()),
                    kind,
                    table,
                )
            )
        for match in re.finditer(r"\.rpc\(\s*['\"]([a-z0-9_]+)['\"]", text):
            usages.append(
                Usage(str(path.relative_to(ROOT)), line_number(text, match.start()), "rpc", match.group(1))
            )
        # Validate simple column references in filters/order calls against the
        # nearest preceding .from(...) in the same file.  This catches typos
        # without trying to become a full Dart parser.
        for match in re.finditer(
            r"\.(?:eq|neq|gt|gte|lt|lte|like|ilike|in_|is_|order|filter)\(\s*['\"]([a-z0-9_]+)['\"]",
            text,
        ):
            preceding = [item for item in from_positions if item[0] < match.start()]
            table = preceding[-1][1] if preceding else None
            usages.append(
                Usage(
                    str(path.relative_to(ROOT)),
                    line_number(text, match.start()),
                    "column",
                    match.group(1),
                    table=table,
                )
            )
    return usages


def run(strict_sql: bool) -> Tuple[int, Dict[str, object]]:
    tables = parse_schema_dart()
    sql = parse_sql()
    usages = scan_dart_usages()

    errors: List[str] = []
    warnings: List[str] = []

    known_objects = set(tables) | set(sql.tables) | set(sql.views)
    for usage in usages:
        if usage.kind == "from" and usage.name not in known_objects:
            errors.append(
                f"{usage.path}:{usage.line}: .from('{usage.name}') is not a known table or view."
            )
        if usage.kind == "storage" and usage.name not in LIVE_STORAGE_BUCKETS:
            errors.append(
                f"{usage.path}:{usage.line}: storage bucket '{usage.name}' is not documented."
            )
        if usage.kind == "rpc" and usage.name not in (LIVE_RPCS | sql.functions):
            errors.append(
                f"{usage.path}:{usage.line}: .rpc('{usage.name}') is not a documented live RPC or SQL function."
            )
        if (
            usage.kind == "column"
            and usage.table
            and usage.table in tables
            and usage.name not in COMMON_COLUMNS
        ):
            info = tables[usage.table]
            if info.fields and usage.name not in info.fields:
                errors.append(
                    f"{usage.path}:{usage.line}: column '{usage.name}' is not in the "
                    f"'{usage.table}' schema snapshot."
                )

    # Every schema-snapshot table should be a real object, and every lookup
    # target should exist.  Missing legacy SQL is a warning because the live
    # project is authoritative.
    for name, info in tables.items():
        if name not in sql.tables and name not in sql.views:
            message = (
                f"schema snapshot '{name}' is not present in the repository SQL "
                "(expected for live-only objects; legacy migrations are not replayed)."
            )
            if strict_sql:
                errors.append(message)
            else:
                warnings.append(message)
        for lookup in sorted(info.lookup_tables):
            if lookup not in tables and lookup not in sql.tables and lookup not in sql.views:
                errors.append(
                    f"schema snapshot '{name}' has lookupTable '{lookup}', which is not known."
                )
        if name in sql.check_status and info.status_options:
            allowed = sql.check_status[name]
            unknown = sorted(info.status_options - allowed)
            if unknown:
                errors.append(
                    f"schema snapshot '{name}' status options {unknown} are not allowed by "
                    f"the SQL CHECK constraint {sorted(allowed)}."
                )
        if name in sql.check_status and info.status_defaults:
            unknown_defaults = sorted(info.status_defaults - sql.check_status[name])
            if unknown_defaults:
                errors.append(
                    f"schema snapshot '{name}' status defaults {unknown_defaults} are not "
                    f"allowed by the SQL CHECK constraint {sorted(sql.check_status[name])}."
                )

    summary = {
        "schema_objects": len(tables),
        "sql_tables": len(sql.tables),
        "sql_views": len(sql.views),
        "sql_functions": len(sql.functions),
        "dart_from_usages": sum(1 for usage in usages if usage.kind == "from"),
        "dart_storage_usages": sum(1 for usage in usages if usage.kind == "storage"),
        "dart_rpc_usages": sum(1 for usage in usages if usage.kind == "rpc"),
        "dart_column_usages": sum(1 for usage in usages if usage.kind == "column"),
        "errors": errors,
        "warnings": warnings,
    }
    return (1 if errors else 0), summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--strict-sql",
        action="store_true",
        help="also fail when a live-only schema snapshot object is absent from repository SQL",
    )
    parser.add_argument("--json", action="store_true", help="print a JSON summary")
    args = parser.parse_args()

    code, summary = run(args.strict_sql)
    if args.json:
        print(json.dumps(summary, indent=2))
    else:
        print("Schema check")
        print(f"  schema snapshot objects : {summary['schema_objects']}")
        print(f"  SQL tables/views        : {summary['sql_tables']} / {summary['sql_views']}")
        print(f"  SQL functions           : {summary['sql_functions']}")
        print(
            f"  Dart usage checked      : {summary['dart_from_usages']} from, "
            f"{summary['dart_rpc_usages']} rpc, {summary['dart_column_usages']} column, "
            f"{summary['dart_storage_usages']} storage"
        )
        for warning in summary["warnings"]:
            print(f"  WARN  {warning}")
        for error in summary["errors"]:
            print(f"  ERROR {error}")
        print("  PASS" if code == 0 else "  FAIL")
    return code


if __name__ == "__main__":
    sys.exit(main())
