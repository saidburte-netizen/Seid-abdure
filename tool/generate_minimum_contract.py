#!/usr/bin/env python3
"""Generate the minimum-field repository payload contract.

The generated SQL is the executable form of the payloads that CrudTab and
BranchRepository.insert send for every create-capable form.  Each payload
contains only the required fields (plus the branch id that the repository adds
for branch-scoped tables).  Empty optional fields are absent.

Usage:
    python3 tool/generate_minimum_contract.py

Outputs:
    supabase/tests/integration/minimum_fields_seed.sql
    supabase/tests/integration/minimum_fields_contract.sql
"""
from __future__ import annotations

import json
import re
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCHEMA = ROOT / "lib" / "data" / "schema.dart"
SEED_OUT = ROOT / "supabase" / "tests" / "integration" / "minimum_fields_seed.sql"
CONTRACT_OUT = ROOT / "supabase" / "tests" / "integration" / "minimum_fields_contract.sql"

NAMESPACE = uuid.UUID("6ba7b810-9dad-11d1-80b4-00c04fd430c8")
BRANCH = "b0000000-0000-4000-8000-000000000001"
STORE = "b0000000-0000-4000-8000-000000000002"
STORE2 = "b0000000-0000-4000-8000-000000000003"
UNIT = "b0000000-0000-4000-8000-000000000004"
CATEGORY = "b0000000-0000-4000-8000-000000000005"
ITEM = "b0000000-0000-4000-8000-000000000006"
PRODUCT = "b0000000-0000-4000-8000-000000000007"
CUSTOMER = "b0000000-0000-4000-8000-000000000008"
SUPPLIER = "b0000000-0000-4000-8000-000000000009"
CASH = "b0000000-0000-4000-8000-00000000000a"
CASH2 = "b0000000-0000-4000-8000-00000000000b"
PROPERTY = "b0000000-0000-4000-8000-00000000000c"
TENANT = "b0000000-0000-4000-8000-00000000000d"
LEASE = "b0000000-0000-4000-8000-00000000000e"
EMPLOYEE = "b0000000-0000-4000-8000-00000000000f"
LEAVE_TYPE = "b0000000-0000-4000-8000-000000000010"
SHIFT = "b0000000-0000-4000-8000-000000000011"
PAYABLE = "b0000000-0000-4000-8000-000000000012"
RECEIVABLE = "b0000000-0000-4000-8000-000000000013"
SALE = "b0000000-0000-4000-8000-000000000014"
INVOICE = "b0000000-0000-4000-8000-000000000015"
ADMIN_USER = "b0000000-0000-4000-8000-000000000101"
MANAGER_USER = "b0000000-0000-4000-8000-000000000102"


def uid(key: str) -> str:
    return str(uuid.uuid5(NAMESPACE, f"brade/minimum/{key}"))


def specs() -> dict[str, dict[str, object]]:
    text = SCHEMA.read_text(encoding="utf-8")
    starts = list(re.finditer(r"'([^']+)': TableSpec\(", text))
    result: dict[str, dict[str, object]] = {}
    for index, match in enumerate(starts):
        end = starts[index + 1].start() if index + 1 < len(starts) else len(text)
        block = text[match.end() : end]
        result[match.group(1)] = {
            "canCreate": bool(re.search(r"canCreate:\s*true", block)),
            "branchScoped": not bool(re.search(r"branchScoped:\s*false", block)),
            "singular": (
                re.search(r"singular:\s*'([^']+)'", block).group(1)
                if re.search(r"singular:\s*'([^']+)'", block)
                else match.group(1).replace("_", " ").title()
            ),
        }
    return result


SPECS = specs()

# Every create-capable form. Values are rendered into the SQL payload and the
# printed "fields sent" JSON. @today and @today30 are resolved by PostgreSQL at
# test time so the contract never goes stale.
CASE_VALUES: dict[str, dict[str, object]] = {
    "branches": {"code": "@code", "name": "@name Branch"},
    "stores": {"name": "@name Store"},
    "units": {"code": "@code", "name": "@name Unit"},
    "categories": {"kind": "product", "name": "@name Category"},
    "employees": {"full_name": "@name Employee"},
    "leave_types": {"name": "@name Leave", "days_per_year": 0},
    "shifts": {"name": "@name Shift", "start_time": "08:00", "end_time": "17:00"},
    "items": {"name": "@name Item", "unit_id": UNIT},
    "products": {"name": "@name Product", "price": 0},
    "purchase_orders": {"supplier_id": SUPPLIER},
    "customers": {"full_name": "@name Customer"},
    "suppliers": {"name": "@name Supplier"},
    "cash_accounts": {"name": "@name Drawer"},
    "properties": {"name": "@name Property"},
    "tenants": {"full_name": "@name Tenant"},
    "leave_requests": {
        "employee_id": EMPLOYEE,
        "leave_type_id": LEAVE_TYPE,
        "start_date": "@todayRole",
        "end_date": "@today30",
    },
    "leases": {
        "property_id": PROPERTY,
        "tenant_id": TENANT,
        "start_date": "@today",
        "end_date": "@today30",
        "rent_amount": 100,
    },
    "payables": {"supplier_id": SUPPLIER, "amount": 100},
    "receivables": {"customer_id": CUSTOMER, "amount": 100},
    "sales": {},
    "approvals": {"entity_type": "product", "entity_id": PRODUCT},
    "attendance": {"employee_id": EMPLOYEE, "work_date": "@todayRole"},
    "bills": {"amount": 100},
    "cake_orders": {"quantity": 1},
    "cash_transactions": {"cash_account_id": CASH, "txn_type": "in", "amount": 100},
    "cash_transfers": {"from_account_id": CASH, "to_account_id": CASH2, "amount": 50},
    "departments": {"name": "@name Department"},
    "employee_advances": {"employee_id": EMPLOYEE, "amount": 10, "balance": 10},
    "employee_documents": {
        "employee_id": EMPLOYEE,
        "title": "@name Document",
        "file_url": "https://example.invalid/document.pdf",
    },
    "employee_shifts": {"employee_id": EMPLOYEE, "shift_id": SHIFT, "work_date": "@todayRole"},
    "expense_categories": {"name": "@name Expense"},
    "goods_receipts": {"store_id": STORE},
    "hr_notes": {"employee_id": EMPLOYEE, "title": "@name Note"},
    "maintenance_requests": {"property_id": PROPERTY, "title": "@name Request"},
    "payable_payments": {"payable_id": PAYABLE, "amount": 10},
    "payroll_runs": {"period_month": "@monthStart"},
    "production_batches": {"product_id": PRODUCT},
    "receivable_payments": {"receivable_id": RECEIVABLE, "amount": 10},
    "recipes": {"product_id": PRODUCT, "name": "@name Recipe"},
    "rent_payments": {"invoice_id": INVOICE, "amount": 10},
    "sale_returns": {"sale_id": SALE},
    "stock_counts": {"store_id": STORE},
    "stock_transfers": {
        "from_store_id": STORE,
        "to_store_id": STORE2,
        "item_id": ITEM,
        "quantity": 1,
    },
    "tax_brackets": {"min_amount": 0, "rate": 0},
    "write_offs": {"receivable_id": RECEIVABLE, "amount": 10},
}

ORDER = [
    "branches", "stores", "units", "categories", "employees", "leave_types",
    "shifts", "items", "products", "customers", "suppliers", "cash_accounts",
    "properties", "tenants", "leases", "leave_requests", "payables", "receivables",
    "sales", "purchase_orders",
    "approvals", "attendance", "bills", "cake_orders", "cash_transactions",
    "cash_transfers", "departments", "employee_advances", "employee_documents",
    "employee_shifts", "expense_categories", "goods_receipts", "hr_notes",
    "maintenance_requests", "payable_payments", "payroll_runs",
    "production_batches", "receivable_payments", "recipes", "rent_payments",
    "sale_returns", "stock_counts", "stock_transfers", "tax_brackets",
    "write_offs",
]

# Screen and action shown in the printed walkthrough table. These are the
# real navigation destinations and button labels used by the widget tests.
SCREEN_ACTION: dict[str, tuple[str, str]] = {
    "branches": ("Settings / Branches", "New branch"),
    "stores": ("Settings / Stores", "New store"),
    "units": ("Settings / Units", "New unit"),
    "categories": ("Settings / Categories", "New category"),
    "employees": ("HR / Employees", "New employee"),
    "leave_types": ("HR / Leave types", "New leave type"),
    "shifts": ("HR / Shifts", "New shift"),
    "items": ("Stock", "Add item"),
    "products": ("Products", "Add product"),
    "customers": ("Sales / Customers", "New customer"),
    "suppliers": ("Settings / Suppliers", "New supplier"),
    "cash_accounts": ("Cash", "New cash account"),
    "properties": ("Rentals / Properties", "New property"),
    "tenants": ("Rentals / Tenants", "New tenant"),
    "leases": ("Rentals / Leases", "New lease"),
    "leave_requests": ("HR / Leave", "Request leave"),
    "payables": ("Credit / Payables", "New payable"),
    "receivables": ("Credit / Receivables", "New receivable"),
    "sales": ("New sale", "Quick sale"),
    "purchase_orders": ("Inventory / Purchase orders", "New purchase order"),
    "approvals": ("Approvals", "New approval"),
    "attendance": ("HR / Attendance", "Quick attendance"),
    "bills": ("Cash / Bills", "New bill"),
    "cake_orders": ("Production / Orders", "New cake order"),
    "cash_transactions": ("Cash", "Cash in / cash out"),
    "cash_transfers": ("Cash", "New cash transfer"),
    "departments": ("HR / Departments", "New department"),
    "employee_advances": ("HR / Advances", "New advance"),
    "employee_documents": ("HR / Documents", "New document"),
    "employee_shifts": ("HR / Shifts", "Assign shift"),
    "expense_categories": ("Cash / Expenses", "New expense category"),
    "goods_receipts": ("Stock", "Receive stock"),
    "hr_notes": ("HR / Notes", "New HR note"),
    "maintenance_requests": ("Rentals / Maintenance", "New request"),
    "payable_payments": ("Cash", "Pay supplier"),
    "payroll_runs": ("Payroll", "Run payroll"),
    "production_batches": ("Production", "New batch"),
    "receivable_payments": ("Sales", "Receive payment"),
    "recipes": ("Production / Recipes", "New recipe"),
    "rent_payments": ("Rentals / Invoices", "Receive payment"),
    "sale_returns": ("Sales", "Record return"),
    "stock_counts": ("Stock", "Count stock"),
    "stock_transfers": ("Stock", "Transfer stock"),
    "tax_brackets": ("Payroll / Tax", "New tax bracket"),
    "write_offs": ("Credit", "New write-off"),
}

# A manager is a normal staff role. These forms are intentionally admin/HR only
# in the live RLS policy catalogue; a 42501 is the correct result for them.
MANAGER_DENIED = {
    "employee_advances", "employee_documents", "hr_notes",
    "leave_types", "payroll_runs", "tax_brackets",
}

EXPR = {
    "@today": "current_date",
    "@today1": "(current_date + interval '1 day')::date",
    "@today30": "(current_date + interval '30 days')::date",
    "@monthStart": "date_trunc('month', current_date)::date",
}


def sql_literal(value: object) -> str:
    if isinstance(value, str) and value in EXPR:
        return EXPR[value]
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    text = str(value)
    if text.startswith("@code"):
        text = "MIN" + text.removeprefix("@code")
    if text.startswith("@name"):
        text = "Minimum" + text.removeprefix("@name")
    return "'" + text.replace("'", "''") + "'"


def shown(value: object, role: str) -> object:
    if isinstance(value, str) and value in EXPR:
        return {
            "@today": "today in Ethiopian time",
            "@today1": "tomorrow in Ethiopian time",
            "@today30": "today + 30 days",
            "@monthStart": "first day of this month",
        }[value]
    if value == "@todayRole":
        return "today in Ethiopian time" if role == "admin" else "tomorrow in Ethiopian time"
    if isinstance(value, str) and value.startswith("@code"):
        return f"MIN-{role.upper()}"
    if isinstance(value, str) and value.startswith("@name"):
        return f"Minimum {role.title()} " + value.removeprefix("@name ")
    return value


def resolve(value: object, role: str) -> object:
    if not isinstance(value, str):
        return value
    if value == "@todayRole":
        return "@today" if role == "admin" else "@today1"
    return (
        value.replace("@code", f"MIN-{role.upper()}")
        .replace("@name", f"Minimum {role.title()} ")
    )


def statement(table: str, role: str) -> tuple[str, str]:
    values = dict(CASE_VALUES[table])
    if SPECS[table]["branchScoped"]:
        values["branch_id"] = BRANCH
    rendered = {key: resolve(value, role) for key, value in values.items()}
    columns = ", ".join(f'"{key}"' for key in rendered)
    literals = ", ".join(sql_literal(value) for value in rendered.values())
    fields = {key: shown(value, role) for key, value in values.items()}
    if not rendered:
        insert = f"insert into public.{table} default values"
    else:
        insert = f"insert into public.{table} ({columns}) values ({literals})"
    return (
        insert,
        json.dumps(fields, ensure_ascii=False, separators=(",", ":")),
    )


def seed_sql() -> str:
    lines = [
        "-- GENERATED by tool/generate_minimum_contract.py. Do not edit.",
        "-- Parent fixtures for the minimum-field payload contract.",
        "insert into auth.users (",
        "  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,",
        "  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,",
        "  confirmation_token, email_change, email_change_token_new, recovery_token",
        ") values",
    ]
    for user, role, email in [
        (ADMIN_USER, "admin", "minimum-admin@test.local"),
        (MANAGER_USER, "manager", "minimum-manager@test.local"),
    ]:
        comma = "," if user == ADMIN_USER else ";"
        lines.append(
            f"  ('{user}', '00000000-0000-0000-0000-000000000000', 'authenticated', "
            f"'authenticated', '{email}', 'test-hash', now(), "
            "'{\"provider\":\"email\",\"providers\":[\"email\"]}', "
            f"'{{\"full_name\":\"Minimum {role}\"}}', now(), now(), '', '', '', ''){comma}"
        )
    lines += [
        f"insert into public.branches (id, code, name, is_active) values "
        f"('{BRANCH}', 'MINROOT', 'Minimum branch', true) on conflict (id) do nothing;",
        f"update public.profiles set role_code = 'admin', branch_id = '{BRANCH}' "
        f"where id = '{ADMIN_USER}';",
        f"update public.profiles set role_code = 'manager', branch_id = '{BRANCH}' "
        f"where id = '{MANAGER_USER}';",
        f"insert into public.stores (id, branch_id, name, store_type, is_active) values "
        f"('{STORE}', '{BRANCH}', 'Minimum Shop', 'shop', true), "
        f"('{STORE2}', '{BRANCH}', 'Minimum Main', 'main', true) "
        "on conflict (id) do nothing;",
        f"insert into public.units (id, code, name) values "
        f"('{UNIT}', 'min_pcs', 'Minimum pieces') on conflict (id) do nothing;",
        f"insert into public.categories (id, kind, name, is_active) values "
        f"('{CATEGORY}', 'product', 'Minimum category', true) on conflict (id) do nothing;",
        f"insert into public.items (id, name, item_type, unit_id, cost_price, min_stock, is_active) values "
        f"('{ITEM}', 'Minimum item', 'raw_material', '{UNIT}', 1, 0, true) on conflict (id) do nothing;",
        f"insert into public.products (id, name, unit_id, price, cost, tax_rate, is_active) values "
        f"('{PRODUCT}', 'Minimum product', '{UNIT}', 0, 0, 0, true) on conflict (id) do nothing;",
        f"insert into public.customers (id, full_name, customer_type, credit_limit, is_active) values "
        f"('{CUSTOMER}', 'Minimum customer', 'retail', 0, true) on conflict (id) do nothing;",
        f"insert into public.suppliers (id, name, payment_terms_days, is_active) values "
        f"('{SUPPLIER}', 'Minimum supplier', 0, true) on conflict (id) do nothing;",
        f"insert into public.cash_accounts (id, branch_id, name, account_type, opening_balance, is_active) values "
        f"('{CASH}', '{BRANCH}', 'Minimum drawer', 'cash_drawer', 0, true), "
        f"('{CASH2}', '{BRANCH}', 'Minimum safe', 'safe', 0, true) "
        "on conflict (id) do nothing;",
        f"insert into public.tenants (id, full_name, is_active) values "
        f"('{TENANT}', 'Minimum tenant', true) on conflict (id) do nothing;",
        f"insert into public.properties (id, name, property_type, branch_id, monthly_rent, status, is_active) values "
        f"('{PROPERTY}', 'Minimum property', 'shop', '{BRANCH}', 100, 'vacant', true) on conflict (id) do nothing;",
        f"insert into public.leases (id, property_id, tenant_id, start_date, end_date, rent_amount, billing_frequency, status) values "
        f"('{LEASE}', '{PROPERTY}', '{TENANT}', current_date, (current_date + interval '30 days')::date, 100, 'monthly', 'active') on conflict (id) do nothing;",
        f"insert into public.employees (id, full_name, hire_date, employment_type, status, base_salary, transport_allowance, housing_allowance, other_allowance, pension_rate) values "
        f"('{EMPLOYEE}', 'Minimum employee', current_date, 'full_time', 'active', 0, 0, 0, 0, 0) on conflict (id) do nothing;",
        f"insert into public.leave_types (id, name, days_per_year, is_paid) values "
        f"('{LEAVE_TYPE}', 'Minimum leave', 0, true) on conflict (id) do nothing;",
        f"insert into public.shifts (id, name, start_time, end_time, is_active) values "
        f"('{SHIFT}', 'Minimum shift', '08:00', '17:00', true) on conflict (id) do nothing;",
        f"insert into public.payables (id, supplier_id, amount, paid_amount, due_date, status) values "
        f"('{PAYABLE}', '{SUPPLIER}', 100, 0, current_date, 'open') on conflict (id) do nothing;",
        f"insert into public.receivables (id, customer_id, amount, paid_amount, due_date, status) values "
        f"('{RECEIVABLE}', '{CUSTOMER}', 100, 0, current_date, 'open') on conflict (id) do nothing;",
        f"insert into public.sales (id, branch_id, store_id, sale_date, subtotal, discount_amount, tax_amount, total_amount, paid_amount, payment_status, status) values "
        f"('{SALE}', '{BRANCH}', '{STORE}', current_date, 0, 0, 0, 0, 0, 'unpaid', 'completed') on conflict (id) do nothing;",
        f"insert into public.rent_invoices (id, lease_id, tenant_id, property_id, invoice_no, period_start, period_end, due_date, amount, paid_amount, status) values "
        f"('{INVOICE}', '{LEASE}', '{TENANT}', '{PROPERTY}', 'MIN-INV', current_date, (current_date + interval '30 days')::date, current_date, 100, 0, 'unpaid') on conflict (id) do nothing;",
        "",
    ]
    return "\n".join(lines)


def contract_sql() -> str:
    all_forms = [name for name, spec in SPECS.items() if spec["canCreate"]]
    missing_order = set(all_forms) - set(ORDER)
    if missing_order:
        raise SystemExit(f"forms missing from ORDER: {sorted(missing_order)}")
    missing_cases = set(all_forms) - set(CASE_VALUES)
    if missing_cases:
        raise SystemExit(f"forms missing from CASE_VALUES: {sorted(missing_cases)}")
    extra_cases = set(CASE_VALUES) - set(all_forms)
    if extra_cases:
        raise SystemExit(f"case values without a create-capable form: {sorted(extra_cases)}")

    lines = [
        "-- GENERATED by tool/generate_minimum_contract.py. Do not edit.",
        "-- Saves every create-capable form with the exact payload a minimum-field",
        "-- save sends through BranchRepository.insert (branch id included for",
        "-- branch-scoped tables; empty optional fields omitted).",
        "begin;",
        "set local timezone = 'Africa/Addis_Ababa';",
        "create temp table min_save_results (",
        "  role_code text not null, form text not null, sqlstate text",
        ") on commit drop;",
        "grant all on min_save_results to authenticated;",
        "create or replace function pg_temp.min_save(",
        "  p_form text, p_role_code text, p_user uuid, p_table text,",
        "  p_screen text, p_action text, p_statement text, p_fields jsonb",
        ") returns void language plpgsql as $$",
        "begin",
        "  reset role;",
        "  perform set_config('request.jwt.claim.sub', p_user::text, true);",
        "  perform set_config('request.jwt.claim.role', 'authenticated', true);",
        "  execute format('set local role %I', 'authenticated');",
        "  begin",
        "    execute p_statement;",
        "    insert into min_save_results values (p_role_code, p_form, null);",
        "    raise notice 'SCREEN SAVE | % | % | % | % | PASS | Saved.',",
        "      p_role_code, p_screen, p_action, p_fields::text;",
        "  exception when others then",
        "    insert into min_save_results values (p_role_code, p_form, sqlstate);",
        "    raise notice 'SCREEN SAVE | % | % | % | % | SQLSTATE % | %',",
        "      p_role_code, p_screen, p_action, p_fields::text, sqlstate,",
        "      case when sqlstate = '42501' then 'You do not have permission to do this.'",
        "        else 'Something went wrong. Please try again.' end;",
        "  end;",
        "  reset role;",
        "end $$;",
        "",
    ]
    for role, user in [("admin", ADMIN_USER), ("manager", MANAGER_USER)]:
        lines.append(f"-- Minimum-field saves as the {role} role.")
        for table in all_forms:
            stmt, fields = statement(table, role)
            escaped_stmt = stmt.replace("'", "''")
            escaped_fields = fields.replace("'", "''")
            screen, action = SCREEN_ACTION[table]
            escaped_screen = screen.replace("'", "''")
            escaped_action = action.replace("'", "''")
            lines.append(
                "select pg_temp.min_save("
                f"'{SPECS[table]['singular']}', '{role}', '{user}', "
                f"'{table}', '{escaped_screen}', '{escaped_action}', "
                f"'{escaped_stmt}', '{escaped_fields}'::jsonb);"
            )
        lines.append("")

    lines += [
        "do $$",
        "declare",
        "  bad int;",
        "begin",
        "  select count(*) into bad from min_save_results",
        "   where role_code = 'admin' and sqlstate is not null;",
        "  if bad > 0 then",
        "    raise exception 'MINIMUM SAVE FAILED for admin: % form(s)', bad;",
        "  end if;",
        "  select count(*) into bad from min_save_results",
        "   where role_code = 'manager' and sqlstate is not null",
        "     and (",
        "       form not in (" + ", ".join(
            "'" + SPECS[name]["singular"].replace("'", "''") + "'"
            for name in sorted(MANAGER_DENIED)
        ) + ")",
        "       or sqlstate <> '42501'",
        "     );",
        "  if bad > 0 then",
        "    raise exception 'MINIMUM SAVE FAILED for manager: % unexpected result(s)', bad;",
        "  end if;",
        "end $$;",
        "do $$",
        "begin",
        "  raise notice 'SCREEN SAVE SUMMARY | admin | % PASS | % SQLSTATE',",
        "    (select count(*) from min_save_results where role_code = 'admin' and sqlstate is null),",
        "    (select count(*) from min_save_results where role_code = 'admin' and sqlstate is not null);",
        "  raise notice 'SCREEN SAVE SUMMARY | manager | % PASS | % SQLSTATE',",
        "    (select count(*) from min_save_results where role_code = 'manager' and sqlstate is null),",
        "    (select count(*) from min_save_results where role_code = 'manager' and sqlstate is not null);",
        "end $$;",
        "rollback;",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    SEED_OUT.write_text(seed_sql(), encoding="utf-8")
    CONTRACT_OUT.write_text(contract_sql(), encoding="utf-8")
    print(f"wrote {SEED_OUT.relative_to(ROOT)}")
    print(f"wrote {CONTRACT_OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
