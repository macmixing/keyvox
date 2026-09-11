package org.keyvox.android.app;

import android.content.Context;
import android.content.SharedPreferences;
import java.util.ArrayList;
import java.util.List;

/** Owns persisted containing-app settings. */
public final class AppSettingsStore {
    private static final String PREFERENCES = "keyvox_app_settings";
    private static final String AUTO_PARAGRAPHS_ENABLED = "autoParagraphsEnabled";
    private static final String LIST_FORMATTING_ENABLED = "listFormattingEnabled";

    private final SharedPreferences preferences;
    private final List<Runnable> observers = new ArrayList<>();

    public AppSettingsStore(Context context) {
        preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE);
    }

    public boolean autoParagraphsEnabled() {
        return preferences.getBoolean(AUTO_PARAGRAPHS_ENABLED, true);
    }

    public boolean listFormattingEnabled() {
        return preferences.getBoolean(LIST_FORMATTING_ENABLED, true);
    }

    public void setAutoParagraphsEnabled(boolean enabled) {
        if (autoParagraphsEnabled() == enabled) return;
        preferences.edit().putBoolean(AUTO_PARAGRAPHS_ENABLED, enabled).apply();
        publish();
    }

    public void setListFormattingEnabled(boolean enabled) {
        if (listFormattingEnabled() == enabled) return;
        preferences.edit().putBoolean(LIST_FORMATTING_ENABLED, enabled).apply();
        publish();
    }

    public void observe(Runnable observer) {
        observers.add(observer);
        observer.run();
    }

    public void removeObserver(Runnable observer) {
        observers.remove(observer);
    }

    private void publish() {
        for (Runnable observer : new ArrayList<>(observers)) observer.run();
    }
}
