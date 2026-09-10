package org.keyvox.android.app.home;

import android.content.Context;
import android.content.SharedPreferences;

/** Owns the most recent successful final transcription on this device. */
public final class LastTranscriptionStore {
    private static final String PREFERENCES = "keyvox_last_transcription";
    private static final String LAST_TRANSCRIPTION = "lastTranscription";

    private final SharedPreferences preferences;

    public LastTranscriptionStore(Context context) {
        this(context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE));
    }

    LastTranscriptionStore(SharedPreferences preferences) {
        this.preferences = preferences;
    }

    public String text() {
        String value = preferences.getString(LAST_TRANSCRIPTION, null);
        if (value == null || value.trim().isEmpty()) return null;
        return value;
    }

    public void record(String text) {
        if (text == null || text.trim().isEmpty()) return;
        preferences.edit().putString(LAST_TRANSCRIPTION, text).apply();
    }
}
