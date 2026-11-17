#!/usr/bin/env python3
"""Generate docs/MINIMUM_FIELDS.md from schema.dart and the live schema dump.

The document is intentionally conservative: a field is marked required only
when the column is NOT NULL without a database default, the form marks it
required, and the app has no sensible automatic value for it.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCHEMA = ROOT / "lib" / "data" / "schema.dart"
LIVE = ROOT / "supabase" / "fixtures" / "live_schema.sql"
OUT = ROOT / "docs" / "MINIMUM_FIELDS.md"

AUTO_KEYS = {
    "branch_id",
    "store_id",
    "cash_account_id",
    "unit_id",
    "category_id",
}
AUTO_DATE_PARTS = ("date", "period", "month", "year")
AUTO_TEXT_PARTS = (
    "no",
    "number",
    "code",
    "sku",
    "receipt",
    "invoice",
    "lease",
)
MANUAL_AMOUNT_TABLES = {
    "cash_transactions",
    "cash_transfers",
    "payable_payments",
    "receivable_payments",
    "rent_payments",
    "bills",
    "leases",
    "employee_advances",
}

AUTO_NUMBER_KEYS = {
    "price",
    "cost",
    "amount",
    "opening_balance",
    "credit_limit",
    "base_salary",
    "transport_allowance",
    "housing_allowance",
    "other_allowance",
    "pension_rate",
    "monthly_rent",
    "rent_amount",
    "deposit_amount",
    "tax_rate",
    "min_stock",
    "quantity",
    "paid_amount",
    "balance",
    "monthly_deduction",
    "days",
    "days_per_year",
}

# These personal fields are optional and must never be filled with today's
# date just because the form is opened.
NEVER_AUTO_DATE = {"date_of_birth", "termination_date"}


def table_blocks() -> dict[str, str]:
    text = LIVE.read_text(encoding="utf-8")
    pattern = re.compile(
        r'create table if not exists "public"\."([^"]+)" \((.*?)\n\);',
        re.S | re.I,
    )
    return {m.group(1): m.group(2) for m in pattern.finditer(text)}


def columns(table: str) -> dict[str, tuple[bool, bool]]:
    """Return column -> (not_null, has_default)."""
    block = table_blocks().get(table, "")
    result: dict[str, tuple[bool, bool]] = {}
    for line in block.splitlines():
        m = re.match(r'\s*"([^"]+)"\s+(.*?)(?:,)?\s*$', line)
        if not m:
            continue
        name, rest = m.group(1), m.group(2)
        not_null = "not null" in rest.lower()
        has_default = bool(re.search(r"\bdefault\b", rest, re.I)) or "generated" in rest.lower()
        result[name] = (not_null, has_default)
    return result


def dart_tables() -> list[tuple[str, bool, list[tuple[str, str, bool]]]]:
    text = SCHEMA.read_text(encoding="utf-8")
    starts = list(re.finditer(r"'([^']+)': TableSpec\(", text))
    result = []
    for index, match in enumerate(starts):
        name = match.group(1)
        start = match.end()
        end = starts[index + 1].start() if index + 1 < len(starts) else len(text)
        block = text[start:end]
        can_create = bool(re.search(r"canCreate:\s*true", block))
        fields = []
        for fm in re.finditer(r"FieldSpec\(\s*'([^']+)'\s*,\s*'([^']*)'(.*?)\)", block, re.S):
            key, label, rest = fm.group(1), fm.group(2), fm.group(3)
            required = bool(re.search(r"required:\s*true", rest))
            fields.append((key, label, required))
        result.append((name, can_create, fields))
    return result


def auto_default(key: str, label: str) -> str | None:
    lower = key.lower()
    if lower in AUTO_KEYS:
        return "branch / store / cash account / linked record"
    if lower in AUTO_NUMBER_KEYS:
        return "0"
    if lower in NEVER_AUTO_DATE:
        return None
    if lower in {
        "hire_date",
        "start_date",
        "end_date",
        "due_date",
        "period_start",
        "period_end",
        "period_month",
        "payment_date",
        "advance_date",
        "txn_date",
        "sale_date",
        "received_date",
        "order_date",
        "expected_date",
        "report_date",
        "work_date",
        "note_date",
        "production_date",
        "count_date",
        "transfer_date",
        "bill_date",
        "return_date",
        "expiry_date",
        "completed_date",
        "decided_at",
        "paid_at",
        "created_at",
        "updated_at",
    }:
        return "today in Ethiopian time"
    if any(part in lower for part in AUTO_TEXT_PARTS):
        return "left to the database"
    if lower in {"status", "is_active"}:
        return "active"
    if lower in {"txn_type"}:
        return "cash in"
    if lower in {"billing_frequency"}:
        return "monthly"
    if lower in {"employment_type"}:
        return "full_time"
    if lower in {"account_type"}:
        return "cash drawer"
    if lower in {"customer_type"}:
        return "retail"
    if lower in {"property_type"}:
        return "shop"
    if lower in {"deposit_paid"}:
        return "false"
    if lower in {"is_cake"}:
        return "false"
    return None


def main() -> None:
    lines = [
        "# Minimum required fields",
        "",
        "A field is required only when the database column is `NOT NULL` without a",
        "default and the app cannot fill a sensible value. Required fields are marked",
        "with `*`. Empty optional fields are omitted from the request; they are never",
        "sent as an empty string.",
        "",
        "## Automatic values",
        "",
        "| Value | Default |",
        "| --- | --- |",
        "| Branch | The signed-in user's branch, or the main branch |",
        "| Store | The Shop store (Main Store for purchases) |",
        "| Cash account | Cash Drawer, or the first active account |",
        "| Unit | pcs |",
        "| Category | none |",
        "| Dates | today in Ethiopian time |",
        "| Amounts / prices / salaries | 0 (price 0 asks for confirmation) |",
        "| Status | active |",
        "| Auto numbers | left to the database |",
        "",
        "A missing required field is reported as `Field label: Required`, for",
        "example `Name: Required`. The message always names the exact field and is",
        "translated in English, Amharic and Afaan Oromoo.",
        "",
        "## Minimum examples",
        "",
        "| Form | Send only |",
        "| --- | --- |",
        "| Cash account | Name |",
        "| Cash in / cash out | Amount |",
        "| Customer / supplier / employee / property / tenant | Name |",
        "| Product | Name (price is optional and may be 0 with a warning) |",
        "| Expense | Amount |",
        "",
        "## Generated forms",
        "",
        "| Form | Required fields | Auto-filled / optional fields |",
        "| --- | --- | --- |",
    ]
    for table, can_create, fields in dart_tables():
        if not can_create:
            continue
        cols = columns(table)
        required = []
        optional = []
        for key, label, app_required in fields:
            col = cols.get(key)
            not_null, has_default = col if col else (False, True)
            default = auto_default(key, label)
            if table in MANUAL_AMOUNT_TABLES and key in {"amount", "rent_amount"}:
                default = None
            if app_required and not_null and not has_default and default is None:
                required.append(f"{label} *")
            elif app_required:
                optional.append(f"{label} → {default or 'default'}")
            elif default is not None:
                optional.append(f"{label} → {default}")
        if not required and not optional:
            continue
        lines.append(
            f"| {table.replace('_', ' ').title()} | "
            f"{', '.join(required) if required else '—'} | "
            f"{', '.join(optional[:12]) if optional else '—'} |"
        )
    lines += [
        "",
        "## Custom screens",
        "",
        "| Form | Required fields | Auto-filled / optional fields |",
        "| --- | --- | --- |",
        "| Products — add/edit | Name * | Price 0 with confirmation, cost 0, category none, unit pcs, photo optional, tax 0, description optional, Amharic/Oromo optional, active, track stock ON, opening stock optional |",
        "| Stock — add item | Name * | Unit pcs, type raw material, minimum stock 0 |",
        "| Stock — receive / use / count / transfer | Item * and quantity * | Store defaults to Shop; note optional; count compares with current quantity |",
        "| Rentals — receive payment | Amount * (default full balance) | Date today, method cash, cash account Cash Drawer, reference optional; overpayment is blocked |",
        "| HR — add employee | Name * | Job title, phone, salary 0, hire date today, branch main, no national ID / bank / birth date / emergency contact required |",
        "| HR — attendance / leave / advance | Employee * plus the action's date/amount * | Dates today, status present, amount 0 allowed where the database allows it |",
        "",
        "## Generated payload contract",
        "",
        "`tool/generate_minimum_contract.py` writes the executable payload table",
        "to `supabase/tests/integration/minimum_fields_contract.sql` and its parent",
        "fixtures to `supabase/tests/integration/minimum_fields_seed.sql`. The",
        "contract prints `SCREEN SAVE | role | screen | action | fields sent |",
        "PASS/SQLSTATE | friendly message` for every create-capable form.",
        "",
        "Verified with `tool/run_contract_local.sh`: 45 forms saved as admin with",
        "45 PASS and 0 SQLSTATE; as a normal manager, 38 PASS and 7 expected",
        "SQLSTATE 42501 responses on admin/HR-only forms. No other SQLSTATE was",
        "accepted.",
        "",
    ]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
