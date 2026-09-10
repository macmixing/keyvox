package org.keyvox.android.app;

import android.app.Application;
import android.content.Context;
import org.keyvox.android.dictation.DictationSession;
import org.keyvox.android.app.home.LastTranscriptionStore;
import org.keyvox.android.app.home.WeeklyWordStatsStore;
import org.keyvox.android.app.dictionary.DictionarySession;
import org.keyvox.android.app.promotion.PromotionSession;
import org.keyvox.android.engine.NativeEngine;

public final class KeyVoxApplication extends Application {
    private DictationSession dictation;
    private WeeklyWordStatsStore weeklyWordStats;
    private LastTranscriptionStore lastTranscription;
    private PromotionSession promotions;
    private DictionarySession dictionary;
    @Override public void onCreate() {
        super.onCreate();
        weeklyWordStats = new WeeklyWordStatsStore(this);
        lastTranscription = new LastTranscriptionStore(this);
        promotions = new PromotionSession();
        dictionary = new DictionarySession();
        dictation = new DictationSession(this, text -> {
            weeklyWordStats.record(text);
            lastTranscription.record(text);
        });
        dictation.observe(() -> {
            if (dictation.phase() == DictationSession.Phase.FAILED) {
                dictionary.engineInitializationFailed();
            }
        });
        NativeEngine.setListener(json -> {
            dictation.receive(json);
            promotions.receive(json);
        });
        NativeEngine.setDictionaryListener(dictionary::receive);
        dictation.initializeEngine();
    }
    public static DictationSession dictation(Context context) {
        return ((KeyVoxApplication) context.getApplicationContext()).dictation;
    }
    public static WeeklyWordStatsStore weeklyWordStats(Context context) {
        return ((KeyVoxApplication) context.getApplicationContext()).weeklyWordStats;
    }
    public static LastTranscriptionStore lastTranscription(Context context) {
        return ((KeyVoxApplication) context.getApplicationContext()).lastTranscription;
    }
    public static PromotionSession promotions(Context context) {
        return ((KeyVoxApplication) context.getApplicationContext()).promotions;
    }
    public static DictionarySession dictionary(Context context) {
        return ((KeyVoxApplication) context.getApplicationContext()).dictionary;
    }
}
