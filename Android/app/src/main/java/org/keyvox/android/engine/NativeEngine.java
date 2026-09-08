package org.keyvox.android.engine;

import android.os.Looper;
import java.nio.charset.StandardCharsets;
import java.util.function.Consumer;

/** Main-thread entry point to the Swift library; presentation never sees JNI. */
public final class NativeEngine {
    static { System.loadLibrary("KeyVoxAndroidEngine"); }
    private static Consumer<String> listener;
    private NativeEngine() {}

    public static void setListener(Consumer<String> value) {
        if (Looper.myLooper() != Looper.getMainLooper()) throw new IllegalStateException("Engine initialization requires the main thread");
        listener = value;
    }
    public static native boolean initialize(String resources, String models, String dictionary);
    public static native void transcribe(String path, long request);
    public static native void cancel();
    public static native void download();

    // Called by JNI with ordinary UTF-8, preserving non-BMP text without JNI modified UTF-8 conversion.
    public static void receive(byte[] data) {
        if (Looper.myLooper() != Looper.getMainLooper()) throw new IllegalStateException("Engine callback left the main thread");
        if (listener != null) listener.accept(new String(data, StandardCharsets.UTF_8));
    }
}
