import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[3]
RESOURCE_PATH = Path("Packages/KeyVoxCore/Sources/KeyVoxCore/Resources/Pronunciation")
spec = importlib.util.spec_from_file_location("verify_artifacts", ROOT / "Tools/Pronunciation/verify_artifacts.py")
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class ArtifactIdentityTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="keyvox-license-check-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.resources = self.root / RESOURCE_PATH
        shutil.copytree(ROOT / RESOURCE_PATH, self.resources)

    def test_current_snapshot_passes(self):
        audit.verify(self.root)

    def test_changed_dataset_or_notice_fails(self):
        sources = json.loads((self.resources / "sources.lock.json").read_text())
        licenses = json.loads((self.resources / "licenses.lock.json").read_text())
        for artifact in sources["artifacts"] + licenses["notices"]:
            with self.subTest(path=artifact["path"]):
                path = self.root / artifact["path"]
                original = path.read_bytes()
                path.write_bytes(original + b"\n")
                with self.assertRaises(ValueError):
                    audit.verify(self.root)
                path.write_bytes(original)

    def test_stale_row_count_fails(self):
        path = self.resources / "sources.lock.json"
        lock = json.loads(path.read_text())
        lock["artifacts"][0]["rows"] += 1
        path.write_text(json.dumps(lock))
        with self.assertRaises(ValueError):
            audit.verify(self.root)

    def test_missing_notice_and_wrong_source_revision_fail(self):
        path = self.resources / "licenses.lock.json"
        original = json.loads(path.read_text())
        missing = dict(original, notices=original["notices"][1:])
        path.write_text(json.dumps(missing))
        with self.assertRaises(ValueError):
            audit.verify(self.root)
        original["notices"][0]["url"] = ""
        path.write_text(json.dumps(original))
        with self.assertRaises(ValueError):
            audit.verify(self.root)


if __name__ == "__main__":
    unittest.main()
