package net.bradeandcake.smokea11y;

import android.accessibilityservice.AccessibilityService;
import android.view.accessibility.AccessibilityEvent;

/**
 * A deliberately inert accessibility service.
 *
 * <p>Android only exposes a Flutter app's semantics tree to UIAutomator while
 * accessibility is enabled. Enabling TalkBack would change how taps work, so
 * the smoke test installs this no-op service instead: it receives events but
 * never reads, stores, or acts on them.
 */
public final class SmokeAccessibilityService extends AccessibilityService {
    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        // Intentionally empty.
    }

    @Override
    public void onInterrupt() {
        // Intentionally empty.
    }
}
