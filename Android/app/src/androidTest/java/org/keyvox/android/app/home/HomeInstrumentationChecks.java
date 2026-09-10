package org.keyvox.android.app.home;

import android.app.Instrumentation;
import android.content.Context;
import android.content.SharedPreferences;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

/** Deterministic device checks for Home's persisted state owners. */
public final class HomeInstrumentationChecks {
    private HomeInstrumentationChecks() {}

    public static void run(Instrumentation instrumentation) {
        Context context = instrumentation.getTargetContext();
        String suffix = Long.toString(System.nanoTime());
        SharedPreferences weeklyPreferences = context.getSharedPreferences(
            "home_weekly_checks_" + suffix,
            Context.MODE_PRIVATE
        );
        SharedPreferences transcriptionPreferences = context.getSharedPreferences(
            "home_transcription_checks_" + suffix,
            Context.MODE_PRIVATE
        );
        try {
            Clock firstWeek = Clock.fixed(Instant.parse("2026-09-09T12:00:00Z"), ZoneOffset.UTC);
            WeeklyWordStatsStore weekly = new WeeklyWordStatsStore(weeklyPreferences, firstWeek);
            check(weekly.wordCount() == 0);
            weekly.record("one two\u00a0three\nfour");
            check(weekly.wordCount() == 4);
            check(new WeeklyWordStatsStore(weeklyPreferences, firstWeek).wordCount() == 4);

            Clock nextWeek = Clock.fixed(Instant.parse("2026-09-14T00:00:00Z"), ZoneOffset.UTC);
            check(new WeeklyWordStatsStore(weeklyPreferences, nextWeek).wordCount() == 0);

            LastTranscriptionStore last = new LastTranscriptionStore(transcriptionPreferences);
            check(last.text() == null);
            last.record("   ");
            check(last.text() == null);
            last.record("A finished transcription.");
            check("A finished transcription.".equals(
                new LastTranscriptionStore(transcriptionPreferences).text()
            ));
        } finally {
            weeklyPreferences.edit().clear().commit();
            transcriptionPreferences.edit().clear().commit();
        }
    }

    private static void check(boolean condition) {
        if (!condition) throw new AssertionError("Home state invariant failed");
    }
}
