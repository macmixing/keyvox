package org.keyvox.android.accessibility;

import android.graphics.Rect;
import android.os.Build;
import android.view.accessibility.AccessibilityNodeInfo;
import java.util.Objects;

/** Identity captured for the editor that owned focus when dictation began. */
final class AccessibilityEditorTarget {
    private final String packageName;
    private final int windowId;
    private final String uniqueId;
    private final String viewId;
    private final String className;
    private final Rect bounds;

    private AccessibilityEditorTarget(
            String packageName,
            int windowId,
            String uniqueId,
            String viewId,
            String className,
            Rect bounds) {
        this.packageName = packageName;
        this.windowId = windowId;
        this.uniqueId = uniqueId;
        this.viewId = viewId;
        this.className = className;
        this.bounds = bounds;
    }

    static AccessibilityEditorTarget capture(AccessibilityNodeInfo node) {
        Rect bounds = new Rect();
        node.getBoundsInScreen(bounds);
        return new AccessibilityEditorTarget(
            string(node.getPackageName()),
            node.getWindowId(),
            Build.VERSION.SDK_INT >= 33 ? node.getUniqueId() : null,
            node.getViewIdResourceName(),
            string(node.getClassName()),
            bounds
        );
    }

    boolean matches(AccessibilityNodeInfo node) {
        if (!sameWindow(node)) return false;
        if (Build.VERSION.SDK_INT >= 33 && uniqueId != null) {
            return uniqueId.equals(node.getUniqueId());
        }
        if (viewId != null) return viewId.equals(node.getViewIdResourceName());
        Rect currentBounds = new Rect();
        node.getBoundsInScreen(currentBounds);
        return Objects.equals(className, string(node.getClassName()))
            && bounds.equals(currentBounds);
    }

    boolean sameWindow(AccessibilityNodeInfo node) {
        return windowId == node.getWindowId()
            && Objects.equals(packageName, string(node.getPackageName()));
    }

    private static String string(CharSequence value) {
        return value == null ? null : value.toString();
    }
}
