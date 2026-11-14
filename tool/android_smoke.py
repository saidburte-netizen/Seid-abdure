#!/usr/bin/env python3
"""Install the release APK on an emulator and smoke-test the login screen.

The script uses the Android accessibility hierarchy so it does not depend on
screen coordinates. It confirms the login screen, switches English -> Amharic
-> Oromo -> English, and captures a screenshot after each language change.
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

    print(
        "SMOKE OK: installed, launched, login screen shown, "
        "en -> am -> om -> en verified"
    )


if __name__ == "__main__":
    main()
