package org.keyvox.android.accessibility;

import android.accessibilityservice.AccessibilityService;
import android.content.res.Configuration;
import android.view.accessibility.AccessibilityEvent;
import org.keyvox.android.app.KeyVoxApplication;
import org.keyvox.android.dictation.DictationResult;
import org.keyvox.android.dictation.DictationSession;

/** Coordinates bubble dictation with the editor that owned focus when recording began. */
public final class KeyVoxAccessibilityService extends AccessibilityService {
    private DictationSession session;
    private AccessibilityEditorLocator locator;
    private AccessibilityTextInsertion insertion;
    private DictationClipboard clipboard;
    private DictationBubbleController bubble;
    private Runnable observer;
    private AccessibilityEditorTarget target;
    private long ownedRequest = -1;
    private boolean delivering;

    @Override protected void onServiceConnected() {
        super.onServiceConnected();
        session = KeyVoxApplication.dictation(this);
        locator = new AccessibilityEditorLocator(this);
        clipboard = new DictationClipboard(this);
        insertion = new AccessibilityTextInsertion(locator, clipboard);
        bubble = new DictationBubbleController(this, this::toggleDictation);
        bubble.attach();
        observer = this::render;
        session.observe(observer);
    }

    private void toggleDictation() {
        if (delivering) return;
        if (session.phase() == DictationSession.Phase.STARTING
                || session.phase() == DictationSession.Phase.RECORDING) {
            session.stop();
            return;
        }
        if (!session.canStart()) return;
        AccessibilityEditorTarget currentTarget = locator.currentTarget();
        long request = session.start();
        if (request >= 0) {
            ownedRequest = request;
            target = currentTarget;
        }
    }

    private void render() {
        bubble.render(session);
        if (ownedRequest < 0) return;
        if (session.request() != ownedRequest) {
            clearDelivery();
            return;
        }
        DictationResult result = session.result();
        if (result == null || delivering) return;
        String transcript = result.text();
        if (transcript == null || transcript.trim().isEmpty()) {
            finishDelivery();
            return;
        }
        delivering = true;
        insertion.insert(target, transcript, inserted -> {
            if (!inserted) clipboard.copy(transcript);
            finishDelivery();
        });
    }

    private void finishDelivery() {
        session.acknowledgeResult(ownedRequest);
        clearDelivery();
    }

    private void clearDelivery() {
        ownedRequest = -1;
        target = null;
        delivering = false;
    }

    @Override public void onAccessibilityEvent(AccessibilityEvent event) {
        // Focus is read only when dictation begins and again when insertion is verified.
    }

    @Override public void onInterrupt() {}

    @Override public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
        if (bubble != null) bubble.configurationChanged();
    }

    @Override public void onDestroy() {
        if (session != null && observer != null) session.removeObserver(observer);
        if (bubble != null) bubble.detach();
        if (ownedRequest >= 0 && session != null
                && (session.phase() == DictationSession.Phase.STARTING
                    || session.phase() == DictationSession.Phase.RECORDING
                    || session.phase() == DictationSession.Phase.PROCESSING)) {
            session.cancel();
        }
        clearDelivery();
        super.onDestroy();
    }
}
