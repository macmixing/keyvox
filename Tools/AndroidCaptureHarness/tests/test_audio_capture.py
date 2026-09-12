import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class AudioCaptureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workspace = tempfile.TemporaryDirectory(prefix="keyvox-capture-lifecycle-")
        cls.output = Path(cls.workspace.name)
        cls.java = Path(os.environ["KEYVOX_JAVA_HOME"]) / "bin"
        tests = Path(__file__).resolve().parent
        source = tests.parent / "src/org/keyvox/platformlab/capture"
        files = [source / "AudioCapture.java", source / "WaveWriter.java", *sorted((tests / "java").rglob("*.java"))]
        subprocess.run([str(cls.java / "javac"), "-d", str(cls.output), *map(str, files)], check=True)

    @classmethod
    def tearDownClass(cls):
        cls.workspace.cleanup()

    def test_capture_ownership_and_recoverable_failures(self):
        for scenario in ["startup", "normal", "read-failure", "release-failure"]:
            with self.subTest(scenario=scenario):
                subprocess.run([str(self.java / "java"), "-cp", str(self.output),
                                "org.keyvox.platformlab.capture.CaptureLifecycleChecks", scenario,
                                str(self.output / scenario)], check=True, timeout=30)


if __name__ == "__main__":
    unittest.main()
