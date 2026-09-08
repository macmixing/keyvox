package org.keyvox.android.engine;

import java.io.*;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

/** Extracts one explicitly named, size-bounded model member to a host-owned temporary file. */
public final class ModelArchiveExtractor {
    private ModelArchiveExtractor() {}

    public static boolean extract(String archive, String member, String destination, long expectedSize) {
        File output = new File(destination);
        boolean created = false;
        boolean completed = false;
        try (ZipFile zip = new ZipFile(archive)) {
            ZipEntry entry = zip.getEntry(member);
            if (entry == null || entry.isDirectory() || expectedSize <= 0 || entry.getSize() != expectedSize) return false;
            if (!output.createNewFile()) return false;
            created = true;
            try (InputStream input = zip.getInputStream(entry); OutputStream stream = new FileOutputStream(output)) {
                byte[] buffer = new byte[32768];
                long written = 0;
                int count;
                while ((count = input.read(buffer)) != -1) {
                    if (count > expectedSize - written) return false;
                    stream.write(buffer, 0, count);
                    written += count;
                }
                if (written != expectedSize) return false;
            }
            completed = true;
            return true;
        } catch (IOException | RuntimeException error) {
            return false;
        } finally {
            if (created && !completed) output.delete();
        }
    }
}
