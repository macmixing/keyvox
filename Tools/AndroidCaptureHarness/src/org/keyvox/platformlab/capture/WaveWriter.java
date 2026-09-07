package org.keyvox.platformlab.capture;

import java.io.Closeable;
import java.io.File;
import java.io.IOException;
import java.io.RandomAccessFile;

/** First-party PCM16 mono interchange writer; no codec dependency. */
final class WaveWriter implements Closeable {
    private final RandomAccessFile file;
    private final int sampleRate;
    private long dataBytes;

    WaveWriter(File destination, int sampleRate) throws IOException {
        this.sampleRate = sampleRate;
        file = new RandomAccessFile(destination, "rw");
        try {
            file.write(new byte[44]);
        } catch (IOException error) {
            try { file.close(); } catch (IOException closing) { error.addSuppressed(closing); }
            throw error;
        }
    }

    void write(short[] samples, int count) throws IOException {
        long addedBytes = (long) count * Short.BYTES;
        if (dataBytes + addedBytes > 0xffffffffL - 36) {
            throw new IOException("RIFF size overflow");
        }
        byte[] bytes = new byte[count * Short.BYTES];
        for (int i = 0; i < count; i++) {
            bytes[i * 2] = (byte) samples[i];
            bytes[i * 2 + 1] = (byte) (samples[i] >>> 8);
        }
        file.write(bytes);
        dataBytes += addedBytes;
    }

    private void uint32(long value) throws IOException {
        file.writeInt(Integer.reverseBytes((int) value));
    }

    private void uint16(int value) throws IOException {
        file.writeShort(Short.reverseBytes((short) value));
    }

    @Override public void close() throws IOException {
        try {
            file.seek(0);
            file.writeBytes("RIFF"); uint32(36 + dataBytes); file.writeBytes("WAVE");
            file.writeBytes("fmt "); uint32(16); uint16(1); uint16(1);
            uint32(sampleRate); uint32((long) sampleRate * Short.BYTES);
            uint16(Short.BYTES); uint16(Short.SIZE);
            file.writeBytes("data"); uint32(dataBytes);
        } finally {
            file.close();
        }
    }
}
