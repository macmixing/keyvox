package org.keyvox.android.app;

import android.app.Application;
import android.content.Context;
import org.keyvox.android.dictation.DictationSession;

public final class KeyVoxApplication extends Application {
    private DictationSession dictation;
    @Override public void onCreate() {
        super.onCreate();
        dictation = new DictationSession(this);
        dictation.initializeEngine();
    }
    public static DictationSession dictation(Context context) {
        return ((KeyVoxApplication) context.getApplicationContext()).dictation;
    }
}
