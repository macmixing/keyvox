package org.keyvox.android.dictation;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/** Carries one selected transcription and its existing paragraph/list alternatives. */
public final class DictationResult {
    public static final class FormatState {
        public final boolean paragraphsEnabled;
        public final boolean listsEnabled;

        public FormatState(boolean paragraphsEnabled, boolean listsEnabled) {
            this.paragraphsEnabled = paragraphsEnabled;
            this.listsEnabled = listsEnabled;
        }

        public FormatState togglingParagraphs() {
            return new FormatState(!paragraphsEnabled, listsEnabled);
        }

        public FormatState togglingLists() {
            return new FormatState(paragraphsEnabled, !listsEnabled);
        }

        @Override public boolean equals(Object value) {
            if (this == value) return true;
            if (!(value instanceof FormatState)) return false;
            FormatState other = (FormatState) value;
            return paragraphsEnabled == other.paragraphsEnabled
                && listsEnabled == other.listsEnabled;
        }

        @Override public int hashCode() {
            return Objects.hash(paragraphsEnabled, listsEnabled);
        }
    }

    private final String text;
    private final FormatState baseState;
    private final Map<FormatState, String> deterministicVariants;

    private DictationResult(
            String text,
            FormatState baseState,
            Map<FormatState, String> deterministicVariants) {
        this.text = text;
        this.baseState = baseState;
        this.deterministicVariants = Collections.unmodifiableMap(
            new LinkedHashMap<>(deterministicVariants));
    }

    public static DictationResult from(JSONObject event) throws JSONException {
        String text = event.optString("text", "");
        FormatState baseState = event.has("baseParagraphsEnabled")
                && event.has("baseListsEnabled")
            ? new FormatState(
                event.getBoolean("baseParagraphsEnabled"),
                event.getBoolean("baseListsEnabled"))
            : null;
        Map<FormatState, String> variants = new LinkedHashMap<>();
        JSONArray payload = event.optJSONArray("deterministicVariants");
        if (payload != null) {
            for (int index = 0; index < payload.length(); index++) {
                JSONObject variant = payload.getJSONObject(index);
                variants.put(
                    new FormatState(
                        variant.getBoolean("paragraphsEnabled"),
                        variant.getBoolean("listsEnabled")),
                    variant.getString("text")
                );
            }
        }
        return new DictationResult(text, baseState, variants);
    }

    public static DictationResult textOnly(String text) {
        return new DictationResult(text, null, Collections.emptyMap());
    }

    public String text() { return text; }
    public FormatState baseState() { return baseState; }
    public Map<FormatState, String> deterministicVariants() { return deterministicVariants; }
}
