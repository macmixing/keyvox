package org.keyvox.android.dictation;

/** Converts captured PCM into the same visual meter scale used by the iOS keyboard. */
final class MicrophoneLevelMeter {
    private static final float SAMPLE_RATE = 16000;
    private static final float HIGH_PASS_CUTOFF = 120;
    private static final float ACTIVE_RMS_THRESHOLD = 0.003f;
    private static final float VISUAL_THRESHOLD_MULTIPLIER = 1.85f;
    private static final float VISUAL_GAIN = 4.7f;
    private static final float HIGH_PASS_TIME_CONSTANT = (float) (1 / (2 * Math.PI * HIGH_PASS_CUTOFF));
    private static final float HIGH_PASS_COEFFICIENT = HIGH_PASS_TIME_CONSTANT
        / (HIGH_PASS_TIME_CONSTANT + 1 / SAMPLE_RATE);

    private float previousInput;
    private float previousOutput;

    float level(short[] samples, int count) {
        if (count <= 0) return 0;
        float visualSumSquares = 0;
        for (int index = 0; index < count; index++) {
            float input = samples[index] / 32768.0f;
            float output = HIGH_PASS_COEFFICIENT * (previousOutput + input - previousInput);
            visualSumSquares += output * output;
            previousInput = input;
            previousOutput = output;
        }
        float visualRms = (float) Math.sqrt(visualSumSquares / count);
        float visualThreshold = ACTIVE_RMS_THRESHOLD * VISUAL_THRESHOLD_MULTIPLIER;
        float scaled = (float) Math.sqrt(Math.max(visualRms - visualThreshold, 0)) * VISUAL_GAIN;
        return Math.min(Math.max(scaled, 0), 1);
    }
}
