package org.keyvox.android.ime;

import android.app.Activity;
import android.app.Instrumentation;
import android.os.Bundle;
import android.view.inputmethod.InputConnection;
import java.lang.reflect.Proxy;

/** Platform instrumentation runner: no third-party test runtime is packaged. */
public final class ShellInstrumentation extends org.keyvox.android.engine.EngineInstrumentation {

    @Override public void onStart() {
        if (fixture != null) { super.onStart(); return; }
        Bundle result = new Bundle();
        try {
            if (captureChecks) org.keyvox.android.engine.CaptureInstrumentationChecks.run(this);
            verifyEditorLifetime();
            result.putString("stream", captureChecks ? "Capture and editor lifetime checks passed\n" : "Editor lifetime checks passed\n");
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
        final CharSequence[] preceding = {"x"};
        InputConnection connection = (InputConnection) Proxy.newProxyInstance(
            InputConnection.class.getClassLoader(), new Class<?>[] {InputConnection.class},
            (proxy, method, args) -> {
                switch (method.getName()) {
                    case "commitText": commits[0]++; return true;
                    case "getSelectedText": return selected[0];
                    case "getTextBeforeCursor":
                        check((int) args[0] == 2 && (int) args[1] == 0);
                        return preceding[0];
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
        check(owner.deletePreviousCodePoint());
        check(deletes[0] == 1);
        selected[0] = new String(Character.toChars(0x1F642));
        check(owner.commitDictation(second, ""));
        check(commits[0] == 2);
        check(owner.deletePreviousCodePoint());
        check(deletes[0] == 1 && commits[0] == 3);
        selected[0] = null;
        preceding[0] = "";
        check(!owner.deletePreviousCodePoint());
        check(deletes[0] == 1);
        preceding[0] = null;
        check(owner.deletePreviousCodePoint());
        check(deletes[0] == 2);
        owner.detach();
        check(!owner.commit(second, ""));
        check(!owner.deletePreviousCodePoint());
        check(commits[0] == 3 && deletes[0] == 2);
    }

    private static void check(boolean condition) {
        if (!condition) throw new AssertionError("Editor connection invariant failed");
    }
}
