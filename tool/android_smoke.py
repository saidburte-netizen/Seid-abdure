#!/usr/bin/env python3
"""Install the release APK on an emulator and smoke-test the app.

The script uses the Android accessibility hierarchy so it does not depend on
screen coordinates. It always confirms the login screen and switches
English -> Amharic -> Oromo -> English. When SMOKE_EMAIL and SMOKE_PASSWORD
are provided it also signs in, opens the dashboard, and completes one POS
cash sale. Without those credentials the signed-in phase is skipped with an
explicit warning, so a release is never blocked by smoke-test credentials.
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


def adb(*args: str, check: bool = True) -> str:
    result = subprocess.run(
        ["adb", *args],
        check=check,
        text=True,
        capture_output=True,
    )
    return result.stdout


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


def tap(node: ET.Element) -> None:
    bounds = node.get("bounds") or ""
    numbers = [int(value) for value in re.findall(r"\d+", bounds)]
    if len(numbers) != 4:
        raise RuntimeError(f"UI node has no usable bounds: {bounds}")
    x1, y1, x2, y2 = numbers
    adb("shell", "input", "tap", str((x1 + x2) // 2), str((y1 + y2) // 2))


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

    email_field = wait_for(lambda r: find_text(r, "Email"), "email field")
    type_into(email_field, email)
    password_field = wait_for(lambda r: find_text(r, "Password"), "password field")
    type_into(password_field, password)
    sign_in = wait_for(lambda r: find_text(r, "Sign in"), "sign in button")
    tap(sign_in)
    dashboard = wait_for(
        lambda r: (
            find_text(r, "Dashboard")
            or find_text(r, "Point of sale")
            or find_text(r, "New sale")
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
    wait_for(lambda r: find_text(r, "Search products"), "POS product list")
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

    paid = wait_for(lambda r: find_text(r, "Amount paid"), "amount paid field")
    type_into(paid, "999999")
    complete = wait_for(
        lambda r: find_clickable_label(r, ["Complete sale"]),
        "complete sale button",
    )
    tap(complete)
    confirm = wait_for(
        lambda r: find_clickable_label(r, ["Complete"]),
        "sale confirmation dialog",
    )
    tap(confirm)
    wait_for(
        lambda r: (
            find_text(r, "Sales receipt")
            or find_text(r, "Sale completed")
            or find_text(r, "Receipt")
        ),
        "completed sale receipt",
        timeout=90,
    )
    screenshot("07-pos-sale-completed.png")
    print("SMOKE SIGNED-IN OK: dashboard opened and one POS cash sale completed.")


def main() -> None:
    apk = sys.argv[1] if len(sys.argv) > 1 else "brade-cake-house.apk"
    print(f"Installing {apk}")
    adb("install", "-r", apk)
    adb("shell", "pm", "clear", PACKAGE)
    adb("shell", "am", "start", "-W", "-n", f"{PACKAGE}/{ACTIVITY}")
    root = wait_for(
        lambda current: (
            find_text(current, "Email")
            or find_text(current, "Password")
            or find_text(current, "Sign in")
        ),
        "login screen",
        timeout=90,
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


if __name__ == "__main__":
    main()
