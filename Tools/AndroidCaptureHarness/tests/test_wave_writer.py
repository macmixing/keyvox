import os
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
import wave


class WaveWriterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workspace = tempfile.TemporaryDirectory(prefix="keyvox-wave-writer-")
        cls.output = Path(cls.workspace.name)
        cls.java = Path(os.environ["KEYVOX_JAVA_HOME"]) / "bin"
        source = Path(__file__).resolve().parents[1] / "src/org/keyvox/platformlab/capture/WaveWriter.java"
        helper = cls.output / "SampleWriter.java"
        helper.write_text("""package org.keyvox.platformlab.capture;
import java.io.File;
public final class SampleWriter {
    public static void main(String[] args) throws Exception {
        try (WaveWriter writer = new WaveWriter(new File(args[0]), Integer.parseInt(args[1]))) {
            if (Boolean.parseBoolean(args[2])) {
                writer.write(new short[] { Short.MIN_VALUE, -1 }, 2);
                writer.write(new short[] { 0, 1, Short.MAX_VALUE }, 3);
            }
        }
    }
}
""")
        subprocess.run([str(cls.java / "javac"), "-d", str(cls.output), str(source), str(helper)], check=True)

    @classmethod
    def tearDownClass(cls):
        cls.workspace.cleanup()

    def verify_wave(self, sample_rate, populated):
        path = self.output / f"capture-{sample_rate}-{populated}.wav"
        subprocess.run([str(self.java / "java"), "-cp", str(self.output),
                        "org.keyvox.platformlab.capture.SampleWriter", str(path), str(sample_rate),
                        str(populated).lower()], check=True)
        expected = [-(1 << 15), -1, 0, 1, (1 << 15) - 1] if populated else []
        with wave.open(str(path), "rb") as decoded:
            self.assertEqual(decoded.getnchannels(), 1)
            self.assertEqual(decoded.getsampwidth(), 2)
            self.assertEqual(decoded.getframerate(), sample_rate)
            self.assertEqual(decoded.getnframes(), len(expected))
            self.assertEqual(decoded.readframes(len(expected)), struct.pack("<" + "h" * len(expected), *expected))

    def test_signed_pcm_round_trips_across_multiple_writes(self):
        for rate in [8000, 16000, 48000]:
            with self.subTest(rate=rate):
                self.verify_wave(rate, True)

    def test_immediate_stop_produces_valid_empty_wave(self):
        self.verify_wave(16000, False)


if __name__ == "__main__":
    unittest.main()
