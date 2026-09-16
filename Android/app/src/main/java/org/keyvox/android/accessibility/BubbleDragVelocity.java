package org.keyvox.android.accessibility;

import android.graphics.PointF;
import java.util.ArrayList;
import java.util.List;

/** Samples recent drag movement and calculates release velocity. */
final class BubbleDragVelocity {
    private static final long SAMPLING_WINDOW_MILLIS = 120;
    private static final long MINIMUM_SAMPLE_DURATION_MILLIS = 8;

    private static final class Sample {
        final float x;
        final float y;
        final long timeMillis;

        Sample(float x, float y, long timeMillis) {
            this.x = x;
            this.y = y;
            this.timeMillis = timeMillis;
        }
    }

    private final List<Sample> samples = new ArrayList<>();

    void begin(float x, float y, long timeMillis) {
        samples.clear();
        samples.add(new Sample(x, y, timeMillis));
    }

    void append(float x, float y, long timeMillis) {
        if (samples.isEmpty()) return;
        samples.add(new Sample(x, y, timeMillis));
    }

    PointF releaseVelocity() {
        if (samples.size() < 2) return null;
        Sample last = samples.get(samples.size() - 1);
        long windowStart = last.timeMillis - SAMPLING_WINDOW_MILLIS;
        Sample first = samples.get(0);
        for (Sample sample : samples) {
            if (sample.timeMillis >= windowStart) {
                first = sample;
                break;
            }
        }

        long durationMillis = last.timeMillis - first.timeMillis;
        if (durationMillis <= MINIMUM_SAMPLE_DURATION_MILLIS) return null;
        float deltaX = last.x - first.x;
        float deltaY = last.y - first.y;
        if (Math.hypot(deltaX, deltaY) <= 1) return null;
        float seconds = durationMillis / 1_000f;
        return new PointF(deltaX / seconds, deltaY / seconds);
    }

    void clear() {
        samples.clear();
    }
}
