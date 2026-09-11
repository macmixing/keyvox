package org.keyvox.android.ime;

import android.content.Intent;
import android.content.res.Configuration;
import android.inputmethodservice.InputMethodService;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.View;
import android.view.inputmethod.EditorInfo;
import org.keyvox.android.app.KeyVoxActivity;
import org.keyvox.android.app.KeyVoxApplication;
import org.keyvox.android.dictation.DictationResult;
import org.keyvox.android.dictation.DictationSession;

/** Android editor lifecycle adapter; the view owns neither capture nor inference. */
public final class KeyVoxInputMethodService extends InputMethodService {
    private final EditorConnectionOwner editor = new EditorConnectionOwner();
    private final DictationDestination dictationDestination = new DictationDestination();
    private DictationSession session;
    private KeyboardDictationChangeController dictationChanges;
    private KeyboardShellView shell;
    private long scheduledRetryDestination = -1;
    private long scheduledRetryRequest = -1;
    private Handler mainHandler;
    private final Runnable changed = this::render;
    private final Runnable settingsChanged = this::renderFormattingState;
    private final Runnable retryPendingDeletion = this::retryPendingDeletion;

    @Override public void onCreate() {
        super.onCreate();
        mainHandler = new Handler(Looper.getMainLooper());
        session = KeyVoxApplication.dictation(this);
        dictationChanges = new KeyboardDictationChangeController(
            editor,
            KeyVoxApplication.settings(this)
        );
        if (hasPendingInsertion()) {
            dictationDestination.recover(session.request());
            Log.i("KeyVoxIME", "Recovered dictation request=" + session.request());
        }
        session.observe(changed);
        KeyVoxApplication.settings(this).observe(settingsChanged);
    }

    @Override public void onDestroy() {
        session.removeObserver(changed);
        KeyVoxApplication.settings(this).removeObserver(settingsChanged);
        mainHandler.removeCallbacks(retryPendingDeletion);
        super.onDestroy();
    }

    private void openApp() {
        startActivity(new Intent(this, KeyVoxActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
    }

    private void toggleDictation() {
        if (session.phase() == DictationSession.Phase.RECORDING || session.phase() == DictationSession.Phase.STARTING) {
            session.stop();
        } else if (session.canStart()) {
            long request = session.start();
            dictationDestination.begin(request, editor.generation());
            Log.i("KeyVoxIME", "Started dictation request=" + request
                + " editor=" + editor.generation());
        } else openApp();
    }

    private void render() {
        if (shell != null) shell.render(session);
        long request = dictationDestination.request();
        long destination = dictationDestination.editorGeneration();
        if (request == session.request() && session.result() != null) {
            DictationResult result = session.result();
            KeyboardDictationInsertion insertion = editor.commitDictationResult(
                destination,
                request,
                result
            );
            if (insertion != null) {
                boolean hasPendingDeletion = editor.hasPendingDictation(destination, request);
                dictationChanges.recordInsertedDictation(insertion);
                long completed = request;
                dictationDestination.clear();
                scheduledRetryDestination = -1;
                scheduledRetryRequest = -1;
                if (hasPendingDeletion) {
                    scheduledRetryDestination = destination;
                    scheduledRetryRequest = request;
                    Log.i("KeyVoxIME", "Inserted dictation request=" + request
                        + " editor=" + destination + " with punctuation cleanup pending");
                    mainHandler.post(retryPendingDeletion);
                } else {
                    Log.i("KeyVoxIME", "Inserted dictation request=" + completed
                        + " editor=" + destination);
                }
                session.acknowledgeResult(completed);
                renderFormattingState();
            } else {
                Log.i("KeyVoxIME", "Waiting for editor for dictation request=" + request
                    + " destination=" + destination + " current=" + editor.generation());
            }
        }
    }

    private void retryPendingDeletion() {
        long request = scheduledRetryRequest;
        long destination = scheduledRetryDestination;
        scheduledRetryDestination = -1;
        scheduledRetryRequest = -1;
        if (!editor.retryPendingDictationDeletion(destination, request)) {
            Log.i("KeyVoxIME", "Punctuation cleanup unavailable for dictation request="
                + request + " editor=" + destination);
        }
    }

    private void renderFormattingState() {
        if (shell != null) shell.renderFormattingState();
    }

    @Override public void onStartInput(EditorInfo info, boolean restarting) {
        super.onStartInput(info, restarting);
        long generation = editor.attach(getCurrentInputConnection());
        if (hasPendingInsertion()
                && dictationDestination.request() == session.request()) {
            dictationDestination.follow(session.request(), generation);
            Log.i("KeyVoxIME", "Followed editor for dictation request=" + session.request()
                + " editor=" + generation);
            render();
        }
    }

    @Override public void onFinishInput() {
        editor.detach();
        super.onFinishInput();
    }

    @Override public void onUpdateSelection(
            int oldSelStart,
            int oldSelEnd,
            int newSelStart,
            int newSelEnd,
            int candidatesStart,
            int candidatesEnd) {
        super.onUpdateSelection(
            oldSelStart,
            oldSelEnd,
            newSelStart,
            newSelEnd,
            candidatesStart,
            candidatesEnd
        );
        renderFormattingState();
    }

    @Override public boolean onEvaluateFullscreenMode() { return false; }

    private boolean hasPendingInsertion() {
        DictationSession.Phase phase = session.phase();
        return phase == DictationSession.Phase.STARTING
            || phase == DictationSession.Phase.RECORDING
            || phase == DictationSession.Phase.PROCESSING
            || session.result() != null;
    }

    @Override public void onConfigurationChanged(Configuration configuration) {
        super.onConfigurationChanged(configuration);
        if (shell != null) shell.refreshAppearance();
    }

    @Override public View onCreateInputView() {
        shell = new KeyboardShellView(this,
            () -> switchToNextInputMethod(false),
            editor::deletePreviousCodePoint,
            text -> editor.commit(editor.generation(), text),
            this::toggleDictation,
            () -> session.cancel(),
            dictationChanges);
        render();
        return shell;
    }
}
