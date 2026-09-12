package org.keyvox.android.app.dictionary;

import android.os.Looper;
import android.util.Log;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.json.JSONArray;
import org.json.JSONObject;
import org.keyvox.android.engine.NativeEngine;

/** Process-owned presentation state backed exclusively by the Swift dictionary store. */
public final class DictionarySession {
    public enum Availability { LOADING, READY, UNAVAILABLE }

    public interface MutationCallback {
        void complete(boolean success, String errorMessage);
    }

    private final List<Runnable> observers = new ArrayList<>();
    private final Map<Long, MutationCallback> pendingMutations = new LinkedHashMap<>();
    private List<DictionaryEntry> entries = List.of();
    private String loadWarningMessage;
    private String saveErrorMessage;
    private Availability availability = Availability.LOADING;
    private long nextRequest;

    public List<DictionaryEntry> entries() { return Collections.unmodifiableList(entries); }
    public String loadWarningMessage() { return loadWarningMessage; }
    public String saveErrorMessage() { return saveErrorMessage; }
    public boolean ready() { return availability == Availability.READY; }
    public boolean unavailable() { return availability == Availability.UNAVAILABLE; }

    public void observe(Runnable observer) {
        requireMainThread();
        observers.add(observer);
        observer.run();
    }

    public void removeObserver(Runnable observer) {
        requireMainThread();
        observers.remove(observer);
    }

    public void refresh() {
        requireMainThread();
        NativeEngine.dictionaryList(++nextRequest);
    }

    public void add(String phrase, MutationCallback callback) {
        long request = register(callback);
        NativeEngine.dictionaryAdd(request, phrase);
    }

    public void update(DictionaryEntry entry, String phrase, MutationCallback callback) {
        long request = register(callback);
        NativeEngine.dictionaryUpdate(request, entry.id(), phrase);
    }

    public void delete(DictionaryEntry entry, MutationCallback callback) {
        long request = register(callback);
        NativeEngine.dictionaryDelete(request, entry.id());
    }

    public void clearWarnings() {
        requireMainThread();
        NativeEngine.dictionaryClearWarnings(++nextRequest);
    }

    public void engineInitializationFailed() {
        requireMainThread();
        if (availability == Availability.READY || availability == Availability.UNAVAILABLE) return;
        availability = Availability.UNAVAILABLE;
        publish();
    }

    public void receive(String json) {
        requireMainThread();
        try {
            JSONObject event = new JSONObject(json);
            boolean available = event.getBoolean("available");
            JSONArray payloadEntries = event.getJSONArray("entries");
            if (available) {
                List<DictionaryEntry> authoritativeEntries = new ArrayList<>(payloadEntries.length());
                for (int index = 0; index < payloadEntries.length(); index++) {
                    JSONObject item = payloadEntries.getJSONObject(index);
                    authoritativeEntries.add(new DictionaryEntry(
                        item.getString("id"),
                        item.getString("phrase")
                    ));
                }

                entries = authoritativeEntries;
                loadWarningMessage = nullableString(event, "loadWarningMessage");
                saveErrorMessage = nullableString(event, "saveErrorMessage");
                availability = Availability.READY;
            }

            long request = event.optLong("request", 0);
            MutationCallback callback = pendingMutations.remove(request);
            if (callback != null) {
                callback.complete(
                    event.optBoolean("success", false),
                    nullableString(event, "errorMessage")
                );
            }
            publish();
        } catch (Exception error) {
            Log.e("KeyVoxDictionary", "Invalid dictionary event", error);
        }
    }

    private long register(MutationCallback callback) {
        requireMainThread();
        long request = ++nextRequest;
        pendingMutations.put(request, callback);
        return request;
    }

    private void publish() {
        for (Runnable observer : new ArrayList<>(observers)) observer.run();
    }

    private static String nullableString(JSONObject object, String key) {
        return object.isNull(key) ? null : object.optString(key, null);
    }

    private static void requireMainThread() {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            throw new IllegalStateException("Dictionary session requires the main thread");
        }
    }
}
