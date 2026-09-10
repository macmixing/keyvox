package org.keyvox.android.app.navigation;

import android.os.Build;
import android.view.HapticFeedbackConstants;
import android.view.View;

/** Emits the selection and blocked-edge feedback used by containing-app tab navigation. */
final class AppTabHaptics {
    void selectionChanged(View source) {
        int feedback = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
            ? HapticFeedbackConstants.CONFIRM
            : HapticFeedbackConstants.VIRTUAL_KEY;
        source.performHapticFeedback(feedback);
    }

    void blockedEdgeSwipe(View source) {
        int feedback = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
            ? HapticFeedbackConstants.REJECT
            : HapticFeedbackConstants.LONG_PRESS;
        source.performHapticFeedback(feedback);
    }
}
