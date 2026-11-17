#!/usr/bin/env python3
"""Fail when a database write bypasses the shared save flow.

Every Supabase mutation in ``lib/`` must be inside ``SaveFlow.write`` or go
through ``BranchRepository``, whose write methods use the same flow. A small
allow-list covers calls that are not database mutations at all, and every entry
must explain why it is safe.

Usage:
    python3 tool/check_save_flow.py          # check, print the audit table
    python3 tool/check_save_flow.py --quiet  # check only
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"

RAW_CALL = re.compile(r"\.\s*(insert|update|upsert|delete|rpc)\s*\(")
FLOW_CALL = re.compile(r"SaveFlow\.(write|read)\s*\(")
REPOSITORY_RECEIVER = re.compile(r"(?:_repo|repo)\s*$")

# file, operation -> reason. Keep this list short and specific.
ALLOWED = {
    (
        "lib/auth/secure_local_storage.dart",
        "delete",
    ): "removes a local secure-storage key; it is not a database write",
    (
        "lib/core/logging/error_log.dart",
        "insert",
    ): "inserts into the in-memory diagnostics list; it is not a database write",
    (
        "lib/core/logging/save_trace.dart",
        "insert",
    ): "inserts into the in-memory trace list; it is not a database write",
}


def _match_paren(text: str, open_index: int) -> int:
    """Return the index just after the parenthesis matching ``open_index``."""
    depth = 0
    index = open_index
    quote: str | None = None
    triple = False
    escaped = False
    line_comment = False
    block_comment = False

    while index < len(text):
        char = text[index]
        nxt = text[index + 1] if index + 1 < len(text) else ""

        if line_comment:
            if char == "\n":
                line_comment = False
            index += 1
            continue
        if block_comment:
            if char == "*" and nxt == "/":
                block_comment = False
                index += 2
            else:
                index += 1
            continue
        if quote is not None:
            if triple:
                if text.startswith(quote * 3, index):
                    quote = None
                    triple = False
                    index += 3
                else:
                    index += 1
                continue
            if escaped:
                escaped = False
                index += 1
                continue
            if char == "\\":
                escaped = True
                index += 1
                continue
            if char == quote:
                quote = None
                index += 1
                continue
            index += 1
            continue

        if char == "/" and nxt == "/":
            line_comment = True
            index += 2
            continue
        if char == "/" and nxt == "*":
            block_comment = True
            index += 2
            continue
        if char in ("'", '"'):
            if text.startswith(char * 3, index):
                quote = char
                triple = True
                index += 3
            else:
                quote = char
                triple = False
                index += 1
            continue
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return index + 1
        index += 1
    return len(text)


def _mask_code(text: str) -> str:
    """Blank strings and comments while preserving offsets and newlines."""
    result = list(text)
    index = 0
    quote: str | None = None
    triple = False
    escaped = False

    while index < len(text):
        char = text[index]
        nxt = text[index + 1] if index + 1 < len(text) else ""
        if quote is not None:
            if triple:
                if text.startswith(quote * 3, index):
                    for offset in range(3):
                        result[index + offset] = " "
                    index += 3
                    quote = None
                    triple = False
                else:
                    if char != "\n":
                        result[index] = " "
                    index += 1
                continue
            if escaped:
                result[index] = " "
                escaped = False
                index += 1
                continue
            if char == "\\":
                result[index] = " "
                escaped = True
                index += 1
                continue
            if char == quote:
                result[index] = " "
                quote = None
                index += 1
                continue
            if char != "\n":
                result[index] = " "
            index += 1
            continue

        if char == "/" and nxt == "/":
            while index < len(text) and text[index] != "\n":
                result[index] = " "
                index += 1
            continue
        if char == "/" and nxt == "*":
            result[index] = " "
            result[index + 1] = " "
            index += 2
            while index < len(text):
                if text[index] == "*" and index + 1 < len(text) and text[index + 1] == "/":
                    result[index] = " "
                    result[index + 1] = " "
                    index += 2
                    break
                if text[index] != "\n":
                    result[index] = " "
                index += 1
            continue
        if char in ("'", '"'):
            if text.startswith(char * 3, index):
                for offset in range(3):
                    result[index + offset] = " "
                quote = char
                triple = True
                index += 3
            else:
                result[index] = " "
                quote = char
                triple = False
                index += 1
            continue
        index += 1
    return "".join(result)


def _flow_ranges(text: str) -> list[tuple[int, int, str]]:
    ranges = []
    for match in FLOW_CALL.finditer(text):
        open_index = match.end() - 1
        end = _match_paren(text, open_index)
        ranges.append((open_index, end, match.group(1)))
    return ranges


def audit() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for path in sorted(LIB.rglob("*.dart")):
        text = path.read_text()
        masked = _mask_code(text)
        relative = path.relative_to(ROOT).as_posix()
        ranges = _flow_ranges(text)
        for match in RAW_CALL.finditer(masked):
            operation = match.group(1)
            index = match.start()
            line = text.count("\n", 0, index) + 1
            flow = next(
                (kind for start, end, kind in ranges if start <= index < end),
                None,
            )
            if flow is not None:
                shared = f"yes ({flow})"
                bump = "yes" if flow == "write" else "no (read-only)"
                note = "SaveFlow"
            elif REPOSITORY_RECEIVER.search(masked[max(0, index - 40) : index]):
                shared = "yes (BranchRepository)"
                bump = "yes"
                note = "BranchRepository write method"
            else:
                reason = ALLOWED.get((relative, operation))
                if reason is not None:
                    shared = "allow-list"
                    bump = "no"
                    note = reason
                else:
                    shared = "NO"
                    bump = "NO"
                    note = "unwrapped database write"
            rows.append(
                {
                    "file": relative,
                    "line": line,
                    "operation": operation,
                    "shared": shared,
                    "bump": bump,
                    "note": note,
                }
            )
    return rows


def main() -> int:
    quiet = "--quiet" in sys.argv[1:]
    rows = audit()
    if not quiet:
        print(f"{'FILE':<52} {'LINE':>4} {'CALL':<7} {'SHARED FLOW':<24} {'BUMP':<15} NOTE")
        print("-" * 132)
        for row in rows:
            print(
                f"{row['file']:<52} {row['line']:>4} {row['operation']:<7} "
                f"{row['shared']:<24} {row['bump']:<15} {row['note']}"
            )
    failing = [row for row in rows if row["shared"] == "NO"]
    print(
        f"\nSAVE FLOW SUMMARY | writes={len(rows)} "
        f"wrapped={sum(str(row['shared']).startswith('yes') for row in rows)} "
        f"allow-listed={sum(row['shared'] == 'allow-list' for row in rows)} "
        f"unwrapped={len(failing)}"
    )
    if failing:
        print("\nFAIL: these database writes bypass SaveFlow.write:", file=sys.stderr)
        for row in failing:
            print(f"  {row['file']}:{row['line']} .{row['operation']}(", file=sys.stderr)
        return 1
    print("PASS: every database write uses the shared save flow or an explained allow-list entry.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
