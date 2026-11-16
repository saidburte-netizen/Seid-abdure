#!/usr/bin/env python3
"""Install the release APK on an emulator and smoke-test the app.

The script uses the Android accessibility hierarchy so it does not depend on
screen coordinates. The app calls SemanticsBinding.ensureSemantics() at start
up, so the release build exposes its widgets to UIAutomator even when no
accessibility service is enabled on the emulator.

It always confirms the login screen and switches English -> Amharic -> Oromo ->
English. When SMOKE_EMAIL and SMOKE_PASSWORD are provided it also signs in,
opens the dashboard, and completes one POS cash sale. Without those credentials
the signed-in phase is skipped with an explicit warning, so a release is never
blocked by smoke-test credentials.

Every failure prints a GitHub ``::error::`` annotation with the real reason and
leaves a screenshot plus logcat in build/evidence/android-smoke, so a red run
is diagnosable from the public annotations API without downloading logs.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

PACKAGE = "net.bradeandcake.brade_and_cake_house"
ACTIVITY = ".MainActivity"
OUT_DIR = "build/evidence/android-smoke"
LANGUAGE_MENU_LABELS = {"Language", "ቋንቋ", "Afaan", "Change language"}
# The language button is always on the login screen; its tooltip is a reliable
# semantics label in every locale, unlike the text-field hints which Android
# exposes as hintText (not text/content-desc) on API <= 34.
LOGIN_MARKERS = {"Sign in", "ግባ", "Seeni", "Language", "ቋንቋ", "Afaan"}


def adb(*args: str, check: bool = True) -> str:
    result = subprocess.run(
        ["adb", *args],
        check=check,
        text=True,
        capture_output=True,
    )
    return result.stdout


def annotate(message: str) -> None:
    """Emit a GitHub Actions error annotation (publicly readable)."""
    clean = " ".join(str(message).split())
    clean = clean.replace("%", "pct")[:900]
    print(f"::error::SMOKE: {clean}", flush=True)


def dump_xml() -> ET.Element:
    for _ in range(12):
        adb("shell", "uiautomator", "dump", "/sdcard/window.xml", check=False)
        raw = adb("shell", "cat", "/sdcard/window.xml", check=False)
        if raw.lstrip().startswith("<?xml"):
            try:
                return ET.fromstring(raw)
            except ET.ParseError:
                pass
        time.sleep(1)
    raise RuntimeError("Could not read the Android UI hierarchy")


def visible_nodes(root: ET.Element) -> list[ET.Element]:
    return list(root.iter("node"))


def label(node: ET.Element) -> str:
    return f"{node.get('text') or ''} {node.get('content-desc') or ''}".strip()


def visible_labels(root: ET.Element) -> list[str]:
    labels = {
        label(node)
        for node in visible_nodes(root)
        if label(node)
    }
    return sorted(labels)


def find_text(root: ET.Element, text: str) -> ET.Element | None:
    for node in visible_nodes(root):
        if node.get("text") == text or node.get("content-desc") == text:
            return node
    return None


def first_node(*nodes: ET.Element | None) -> ET.Element | None:
    """Return the first node that exists.

    ``or`` cannot be used on ElementTree elements: an element with no children
    is falsy, so ``find_text(a) or find_text(b)`` would discard a match.
    """
    for node in nodes:
        if node is not None:
            return node
    return None


def find_edit_text(root: ET.Element, index: int) -> ET.Element | None:
    edits = [
        node
        for node in visible_nodes(root)
        if (node.get("class") or "").endswith("EditText")
    ]
    return edits[index] if len(edits) > index else None


def find_language_menu(root: ET.Element) -> ET.Element | None:
    for node in visible_nodes(root):
        description = node.get("content-desc") or ""
        text = node.get("text") or ""
        if description in LANGUAGE_MENU_LABELS or text in LANGUAGE_MENU_LABELS:
            return node
    for node in visible_nodes(root):
        description = (node.get("content-desc") or "").lower()
        if node.get("clickable") == "true" and (
            "language" in description
            or "ቋንቋ" in description
            or "afaan" in description
        ):
            return node
    return None


def bounds_of(node: ET.Element) -> list[int] | None:
    numbers = [int(value) for value in re.findall(r"\d+", node.get("bounds") or "")]
    return numbers if len(numbers) == 4 else None


def tap(node: ET.Element) -> None:
    numbers = bounds_of(node)
    if numbers is None:
        raise RuntimeError(f"UI node has no usable bounds: {node.get('bounds')}")
    x1, y1, x2, y2 = numbers
    adb("shell", "input", "tap", str((x1 + x2) // 2), str((y1 + y2) // 2))


def find_edit_text_above(root: ET.Element, anchor: ET.Element) -> ET.Element | None:
    """Return the text field closest above a button.

    Android exposes Flutter ``labelText`` as a hint, not text or content-desc,
    so fields such as "Amount paid" cannot be found by label. The field sits
    directly above its submit button, which is a stable position.
    """
    anchor_bounds = bounds_of(anchor)
    if anchor_bounds is None:
        return None
    candidates: list[tuple[int, ET.Element]] = []
    for node in visible_nodes(root):
        if not (node.get("class") or "").endswith("EditText"):
            continue
        node_bounds = bounds_of(node)
        if node_bounds is not None and node_bounds[3] <= anchor_bounds[1]:
            candidates.append((anchor_bounds[1] - node_bounds[3], node))
    if not candidates:
        return None
    return min(candidates, key=lambda item: item[0])[1]


def wait_for(predicate, description: str, timeout: int = 75) -> ET.Element:
    deadline = time.time() + timeout
    last_root: ET.Element | None = None
    while time.time() < deadline:
        last_root = dump_xml()
        node = predicate(last_root)
        if node is not None:
            return node
        time.sleep(1)
    labels = visible_labels(last_root) if last_root is not None else []
    raise RuntimeError(f"Timed out waiting for {description}. Visible labels: {labels}")


def screenshot(name: str) -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    image = subprocess.run(
        ["adb", "exec-out", "screencap", "-p"],
        check=True,
        capture_output=True,
    ).stdout
    path = os.path.join(OUT_DIR, name)
    with open(path, "wb") as handle:
        handle.write(image)
    print(f"SCREENSHOT {path} {len(image)} bytes")


def dump_logcat() -> None:
    try:
        output = adb("logcat", "-d", "-t", "300", check=False)
        os.makedirs(OUT_DIR, exist_ok=True)
        path = os.path.join(OUT_DIR, "logcat.txt")
        with open(path, "w", encoding="utf-8", errors="replace") as handle:
            handle.write(output)
        interesting = [
            line
            for line in output.splitlines()
            if "FATAL" in line
            or "AndroidRuntime" in line
            or "flutter" in line.lower()
            or "Exception" in line
        ]
        for line in interesting[-15:]:
            print(f"LOGCAT {line}")
    except Exception:  # noqa: BLE001 - diagnostics must never mask the failure
        pass


def assert_no_raw_errors(root: ET.Element) -> None:
    forbidden = [
        "SocketException",
        "ClientException",
        "Stack trace",
        "SUPABASE_URL",
        "service_role",
        "Exception:",
    ]
    labels = visible_labels(root)
    for token in forbidden:
        if any(token in text for text in labels):
            raise RuntimeError(f"Raw technical text is visible: {token}")


def choose_language(item_label: str, expected_label: str) -> None:
    root = dump_xml()
    menu = find_language_menu(root)
    if menu is None:
        raise RuntimeError(
            "Language menu was not exposed in the accessibility tree. "
            f"Visible labels: {visible_labels(root)}"
        )
    tap(menu)
    item = wait_for(
        lambda current: find_text(current, item_label),
        f"language menu item {item_label}",
    )
    tap(item)
    wait_for(
        lambda current: find_text(current, expected_label),
        f"{expected_label} after choosing {item_label}",
    )
    print(f"LANGUAGE {item_label} -> {expected_label} OK")


def find_clickable_label(root: ET.Element, labels: list[str]) -> ET.Element | None:
    wanted = set(labels)
    for node in visible_nodes(root):
        if node.get("clickable") == "true" and label(node) in wanted:
            return node
    for node in visible_nodes(root):
        if node.get("clickable") == "true" and any(
            text in label(node) for text in labels
        ):
            return node
    return None


def type_into(node: ET.Element, value: str) -> None:
    tap(node)
    # adb shell input text uses %s for a space and cannot reliably pass shell
    # metacharacters. Smoke credentials are documented as letters/digits only.
    escaped = value.replace(" ", "%s")
    adb("shell", "input", "text", escaped)


def sign_in_and_sell() -> None:
    email = os.environ.get("SMOKE_EMAIL", "").strip()
    password = os.environ.get("SMOKE_PASSWORD", "")
    if not email or not password:
        print(
            "SMOKE SKIP: SMOKE_EMAIL/SMOKE_PASSWORD are not set; "
            "signed-in dashboard and POS sale were not exercised."
        )
        return
    if not re.fullmatch(r"[A-Za-z0-9@._+\-]+", email) or not re.fullmatch(
        r"[A-Za-z0-9@._+\-]+", password
    ):
        raise RuntimeError(
            "SMOKE_EMAIL/SMOKE_PASSWORD must be letters, digits or @ . _ + - only."
        )

    email_field = wait_for(lambda r: find_edit_text(r, 0), "email field")
    type_into(email_field, email)
    password_field = wait_for(lambda r: find_edit_text(r, 1), "password field")
    type_into(password_field, password)
    # Enter submits the form through onFieldSubmitted and hides the keyboard,
    # so the sign-in button does not need to be visible above it.
    adb("shell", "input", "keyevent", "66")
    dashboard = wait_for(
        lambda r: first_node(
            find_text(r, "Dashboard"),
            find_text(r, "Point of sale"),
            find_text(r, "New sale"),
        ),
        "dashboard after sign-in",
        timeout=90,
    )
    screenshot("05-dashboard-en.png")
    assert_no_raw_errors(dashboard)

    menu = find_clickable_label(
        dashboard, ["Menu", "Open navigation menu", "Navigation menu"]
    )
    if menu is None:
        raise RuntimeError("Could not open the navigation drawer after sign-in.")
    tap(menu)
    pos = wait_for(
        lambda r: find_clickable_label(r, ["Point of sale", "POS"]),
        "POS navigation item",
    )
    tap(pos)
    wait_for(
        lambda r: first_node(
            find_text(r, "Current sale"),
            find_clickable_label(r, ["Complete sale"]),
        ),
        "POS product list",
    )
    screenshot("06-pos-before-sale.png")

    chrome = {
        "Point of sale", "Search products", "Current sale", "Customer",
        "Store", "Payment method", "Cash account", "Discount (ETB)",
        "Amount paid", "Notes", "Subtotal", "Discount", "Tax", "Total",
        "Complete sale", "Menu", "Back", "Notifications", "Sign out",
        "Walk-in", "Cash", "Clear cart",
    }
    product = None
    for node in visible_nodes(dump_xml()):
        if node.get("clickable") != "true":
            continue
        text = label(node)
        if not text or text in chrome or len(text) < 2:
            continue
        product = node
        break
    if product is None:
        raise RuntimeError("No product tile was available in the POS grid.")
    print(f"POS PRODUCT {label(product)!r}")
    tap(product)

    complete = wait_for(
        lambda r: find_clickable_label(r, ["Complete sale"]),
        "complete sale button",
    )
    paid = find_edit_text_above(dump_xml(), complete)
    if paid is not None:
        type_into(paid, "999999")
        adb("shell", "input", "keyevent", "4")  # hide the keyboard
        complete = wait_for(
            lambda r: find_clickable_label(r, ["Complete sale"]),
            "complete sale button after amount",
        )
    tap(complete)
    confirm = wait_for(
        lambda r: find_clickable_label(r, ["Complete"]),
        "sale confirmation dialog",
    )
    tap(confirm)
    wait_for(
        lambda r: first_node(
            find_text(r, "Sales receipt"),
            find_text(r, "Sale completed"),
            find_text(r, "Receipt"),
        ),
        "completed sale receipt",
        timeout=90,
    )
    screenshot("07-pos-sale-completed.png")
    print("SMOKE SIGNED-IN OK: dashboard opened and one POS cash sale completed.")


def run(apk: str) -> None:
    print(f"Installing {apk}")
    adb("install", "-r", apk)
    adb("shell", "pm", "clear", PACKAGE)
    adb("shell", "am", "start", "-W", "-n", f"{PACKAGE}/{ACTIVITY}")
    time.sleep(3)
    # Evidence before any assertion, so a timeout still leaves a screenshot.
    screenshot("00-launched.png")
    root = wait_for(
        lambda current: first_node(
            *[find_text(current, text) for text in LOGIN_MARKERS]
        ),
        "login screen",
        timeout=120,
    )
    screenshot("01-login-en.png")
    assert_no_raw_errors(root)

    choose_language("አማርኛ", "ግባ")
    screenshot("02-login-am.png")

    choose_language("Afaan Oromoo", "Seeni")
    screenshot("03-login-om.png")

    choose_language("English", "Sign in")
    screenshot("04-login-en-again.png")
    assert_no_raw_errors(dump_xml())

    sign_in_and_sell()

    print(
        "SMOKE OK: installed, launched, login screen shown, "
        "en -> am -> om -> en verified"
    )


def main() -> None:
    apk = sys.argv[1] if len(sys.argv) > 1 else "brade-cake-house.apk"
    try:
        run(apk)
    except Exception as exc:  # noqa: BLE001 - report and re-raise
        annotate(f"{type(exc).__name__}: {exc}")
        try:
            screenshot("99-failure.png")
        except Exception:  # noqa: BLE001
            pass
        dump_logcat()
        raise


if __name__ == "__main__":
    main()
