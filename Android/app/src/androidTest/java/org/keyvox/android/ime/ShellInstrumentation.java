package org.keyvox.android.ime;

import android.app.Activity;
import android.app.Instrumentation;
import android.os.Bundle;
import android.view.inputmethod.InputConnection;
import java.lang.reflect.Proxy;

/** Platform instrumentation runner: no third-party test runtime is packaged. */
public final class ShellInstrumentation extends Instrumentation {
    @Override public void onCreate(Bundle arguments) { super.onCreate(arguments); start(); }

    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            verifyEditorLifetime();
            result.putString("stream", "Editor lifetime checks passed\n");
            finish(Activity.RESULT_OK, result);
        } catch (Throwable failure) {
            result.putString("stream", failure.toString());
            finish(Activity.RESULT_CANCELED, result);
        }
    }

    private void verifyEditorLifetime() {
        final int[] commits = {0};
        final int[] deletes = {0};
        final String[] selected = {null};
        InputConnection connection = (InputConnection) Proxy.newProxyInstance(
            InputConnection.class.getClassLoader(), new Class<?>[] {InputConnection.class},
            (proxy, method, args) -> {
                switch (method.getName()) {
                    case "commitText": commits[0]++; return true;
                    case "getSelectedText": return selected[0];
                    case "deleteSurroundingTextInCodePoints":
                        check((int) args[0] == 1 && (int) args[1] == 0);
                        deletes[0]++; return true;
                    default: throw new AssertionError(method.getName());
                }
            });
        EditorConnectionOwner owner = new EditorConnectionOwner();
        long first = owner.attach(connection);
        check(owner.commit(first, ""));
        long second = owner.attach(connection);
        check(!owner.commit(first, ""));
        check(owner.commit(second, ""));
        owner.deletePreviousCodePoint();
        check(deletes[0] == 1);
        selected[0] = new String(Character.toChars(0x1F642));
        owner.deletePreviousCodePoint();
        check(deletes[0] == 1 && commits[0] == 3);
        owner.detach();
        check(!owner.commit(second, ""));
        owner.deletePreviousCodePoint();
        check(commits[0] == 3 && deletes[0] == 1);
    }

    private static void check(boolean condition) {
        if (!condition) throw new AssertionError("Editor connection invariant failed");
    }
}
