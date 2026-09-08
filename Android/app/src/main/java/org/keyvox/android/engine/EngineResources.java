package org.keyvox.android.engine;

import android.content.Context;
import android.content.res.AssetManager;
import java.io.*;
import java.nio.charset.StandardCharsets;

/** Installs immutable bundled resources separately from downloaded models and user data. */
public final class EngineResources {
    private EngineResources() {}

    public static File prepare(Context context) throws IOException {
        AssetManager assets = context.getAssets();
        String version;
        try (InputStream input = assets.open("engine-resources-id")) {
            ByteArrayOutputStream bytes = new ByteArrayOutputStream();
            byte[] buffer = new byte[128]; int count;
            while ((count = input.read(buffer)) != -1) bytes.write(buffer, 0, count);
            version = bytes.toString(StandardCharsets.UTF_8.name()).trim();
        }
        if (!version.matches("[a-f0-9]{64}")) throw new IOException("Invalid resource identity");
        File root = new File(context.getFilesDir(), "bundled/" + version);
        File ready = new File(root, ".ready");
        if (!ready.isFile()) {
            copyDirectory(assets, "swift-resources", root);
            if (!ready.createNewFile()) throw new IOException("Cannot publish resources");
        }
        return root;
    }

    private static void copyDirectory(AssetManager assets, String source, File destination) throws IOException {
        if (!destination.isDirectory() && !destination.mkdirs()) throw new IOException("Cannot create resource directory");
        String[] children = assets.list(source);
        if (children == null) throw new IOException("Missing resource directory");
        for (String child : children) {
            String path = source + "/" + child;
            String[] descendants = assets.list(path);
            File output = new File(destination, child);
            if (descendants != null && descendants.length > 0) copyDirectory(assets, path, output);
            else try (InputStream input = assets.open(path); OutputStream stream = new FileOutputStream(output)) {
                byte[] bytes = new byte[32768]; int count;
                while ((count = input.read(bytes)) != -1) stream.write(bytes, 0, count);
            }
        }
    }
}
