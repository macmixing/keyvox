package org.keyvox.android.accessibility;

import android.accessibilityservice.AccessibilityService;
import android.view.accessibility.AccessibilityNodeInfo;
import android.view.accessibility.AccessibilityWindowInfo;
import java.util.ArrayList;
import java.util.List;

/** Finds only the currently focused editable node exposed by the foreground app. */
final class AccessibilityEditorLocator {
    private final AccessibilityService service;

    AccessibilityEditorLocator(AccessibilityService service) {
        this.service = service;
    }

    AccessibilityEditorTarget currentTarget() {
        AccessibilityNodeInfo node = currentEditor();
        return node == null ? null : AccessibilityEditorTarget.capture(node);
    }

    AccessibilityNodeInfo currentEditor(AccessibilityEditorTarget expected) {
        AccessibilityNodeInfo node = currentEditor();
        return node != null && expected != null && expected.matches(node) ? node : null;
    }

    private AccessibilityNodeInfo currentEditor() {
        AccessibilityNodeInfo root = service.getRootInActiveWindow();
        AccessibilityNodeInfo focused = root == null
            ? null
            : root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT);
        if (isEligibleEditor(focused)) return focused;
        AccessibilityNodeInfo descendant = findFocusedEditor(root, new int[] {0});
        if (descendant != null) return descendant;
        descendant = findUniqueEditor(root);
        if (descendant != null) return descendant;

        List<AccessibilityWindowInfo> windows = service.getWindows();
        for (AccessibilityWindowInfo window : windows) {
            AccessibilityNodeInfo windowRoot = window.getRoot();
            AccessibilityNodeInfo candidate = windowRoot == null
                ? null
                : windowRoot.findFocus(AccessibilityNodeInfo.FOCUS_INPUT);
            if (isEligibleEditor(candidate)) return candidate;
            descendant = findFocusedEditor(windowRoot, new int[] {0});
            if (descendant != null) return descendant;
            descendant = findUniqueEditor(windowRoot);
            if (descendant != null) return descendant;
        }
        return null;
    }

    AccessibilityNodeInfo currentEditorInWindow(AccessibilityEditorTarget expected) {
        AccessibilityNodeInfo node = currentEditor();
        return node != null && expected != null && expected.sameWindow(node) ? node : null;
    }

    private static boolean isEligibleEditor(AccessibilityNodeInfo node) {
        if (node == null || !node.isEditable() || !node.isEnabled()
                || !node.isVisibleToUser() || node.isPassword()) {
            return false;
        }
        int actions = node.getActions();
        return (actions & AccessibilityNodeInfo.ACTION_SET_TEXT) != 0
            || (actions & AccessibilityNodeInfo.ACTION_PASTE) != 0;
    }

    private static AccessibilityNodeInfo findFocusedEditor(
            AccessibilityNodeInfo node,
            int[] visited) {
        if (node == null || visited[0]++ >= 500) return null;
        if (node.isFocused() && isEligibleEditor(node)) return node;
        for (int index = 0; index < node.getChildCount(); index++) {
            AccessibilityNodeInfo match = findFocusedEditor(node.getChild(index), visited);
            if (match != null) return match;
        }
        return null;
    }

    private static AccessibilityNodeInfo findUniqueEditor(AccessibilityNodeInfo root) {
        List<AccessibilityNodeInfo> candidates = new ArrayList<>();
        collectEditors(root, candidates, new int[] {0});
        return candidates.size() == 1 ? candidates.get(0) : null;
    }

    private static void collectEditors(
            AccessibilityNodeInfo node,
            List<AccessibilityNodeInfo> candidates,
            int[] visited) {
        if (node == null || visited[0]++ >= 500 || candidates.size() > 1) return;
        if (isEligibleEditor(node)) candidates.add(node);
        for (int index = 0; index < node.getChildCount(); index++) {
            collectEditors(node.getChild(index), candidates, visited);
        }
    }

}
