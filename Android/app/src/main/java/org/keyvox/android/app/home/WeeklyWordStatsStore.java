package org.keyvox.android.app.home;

import android.content.Context;
import android.content.SharedPreferences;
import java.time.Clock;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.TemporalAdjusters;

/** Owns the current device's persisted ISO-week spoken-word total. */
public final class WeeklyWordStatsStore {
    private static final String PREFERENCES = "keyvox_weekly_word_stats";
    private static final String WEEK_START = "weekStartEpochDay";
    private static final String WORD_COUNT = "wordCount";

    private final SharedPreferences preferences;
    private final Clock clock;

    public WeeklyWordStatsStore(Context context) {
        this(context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE), Clock.systemUTC());
    }

    WeeklyWordStatsStore(SharedPreferences preferences, Clock clock) {
        this.preferences = preferences;
        this.clock = clock;
        refreshIfNeeded();
    }

    public int wordCount() {
        refreshIfNeeded();
        return Math.max(0, preferences.getInt(WORD_COUNT, 0));
    }

    public void record(String text) {
        refreshIfNeeded();
        int added = countWords(text);
        if (added == 0) return;
        long total = (long) wordCount() + added;
        preferences.edit().putInt(WORD_COUNT, (int) Math.min(total, Integer.MAX_VALUE)).apply();
    }

    public void refreshIfNeeded() {
        long currentWeek = currentWeekStart().toEpochDay();
        if (preferences.getLong(WEEK_START, Long.MIN_VALUE) == currentWeek) return;
        preferences.edit().putLong(WEEK_START, currentWeek).putInt(WORD_COUNT, 0).apply();
    }

    private LocalDate currentWeekStart() {
        return LocalDate.now(clock.withZone(ZoneOffset.UTC))
            .with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
    }

    private static int countWords(String text) {
        int count = 0;
        boolean insideWord = false;
        for (int offset = 0; offset < text.length();) {
            int codePoint = text.codePointAt(offset);
            boolean whitespace = Character.isWhitespace(codePoint) || Character.isSpaceChar(codePoint);
            if (whitespace) {
                insideWord = false;
            } else if (!insideWord) {
                count++;
                insideWord = true;
            }
            offset += Character.charCount(codePoint);
        }
        return count;
    }
}
