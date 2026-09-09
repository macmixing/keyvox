package org.keyvox.android.engine;

import android.os.Looper;
import java.nio.charset.StandardCharsets;
import java.util.function.Consumer;
import org.json.JSONObject;

/** Main-thread entry point to the Swift library; presentation never sees JNI. */
public final class NativeEngine {
    static { System.loadLibrary("KeyVoxAndroidEngine"); }
    private static Consumer<String> listener;
    private NativeEngine() {}

    public static void setListener(Consumer<String> value) {
        if (Looper.myLooper() != Looper.getMainLooper()) throw new IllegalStateException("Engine initialization requires the main thread");
        listener = value;
    }
    public static native boolean initialize(String resources, String models, String dictionary, String runtime, String soc);
    public static boolean extractModelMember(String archive, String member, String destination, long size) {
        return ModelArchiveExtractor.extract(archive, member, destination, size);
    }
    public static native void transcribe(String path, long request);
    public static native void cancel();
    public static native void download();

    public static final class Composition {
        public final String text;
        public final boolean deleteFollowingCodePoint;

        private Composition(String text, boolean deleteFollowingCodePoint) {
            this.text = text;
            this.deleteFollowingCodePoint = deleteFollowingCodePoint;
        }
    }

    public static Composition compose(
            String transcript,
            String precedingText,
            boolean precedingTextIsTruncated,
            String followingText,
            boolean followingTextIsTruncated) {
        byte[] payload = composeUTF8(
            transcript.getBytes(StandardCharsets.UTF_8),
            precedingText == null ? null : precedingText.getBytes(StandardCharsets.UTF_8),
            precedingTextIsTruncated,
            followingText == null ? null : followingText.getBytes(StandardCharsets.UTF_8),
            followingTextIsTruncated);
        if (payload == null) return null;
        try {
            JSONObject json = new JSONObject(new String(payload, StandardCharsets.UTF_8));
            return new Composition(
                json.getString("text"),
                json.getBoolean("deleteFollowingCodePoint"));
        } catch (Exception invalidPayload) {
            return null;
        }
    }

    private static native byte[] composeUTF8(
        byte[] transcript,
        byte[] precedingText,
        boolean precedingTextIsTruncated,
        byte[] followingText,
        boolean followingTextIsTruncated);

    // Called by JNI with ordinary UTF-8, preserving non-BMP text without JNI modified UTF-8 conversion.
    public static void receive(byte[] data) {
        if (Looper.myLooper() != Looper.getMainLooper()) throw new IllegalStateException("Engine callback left the main thread");
        if (listener != null) listener.accept(new String(data, StandardCharsets.UTF_8));
    }
}
