package org.keyvox.android.engine;

import android.system.ErrnoException;
import android.system.Os;
import android.util.Log;
import java.io.File;

/** Process-level DSP lookup setup; optional acceleration failures retain CPU inference. */
public final class AccelerationRuntime {
    private AccelerationRuntime() {}

    public static void prepare(File resources) {
        File directory = new File(resources, "KeyVoxQnnRuntime.resources");
        if (!directory.isDirectory()) return;
        try {
            String existing = Os.getenv("ADSP_LIBRARY_PATH");
            Os.setenv("ADSP_LIBRARY_PATH", directory.getAbsolutePath()
                + (existing == null || existing.isEmpty() ? "" : ";" + existing), true);
        } catch (ErrnoException error) {
            Log.w("KeyVoxEngine", "DSP runtime setup unavailable", error);
        }
    }
}
