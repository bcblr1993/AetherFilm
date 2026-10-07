import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("crashes", Path(__file__).parents[1] / "collect_playback_crashes.py")
crashes = importlib.util.module_from_spec(spec)
spec.loader.exec_module(crashes)


class CrashEvidenceTests(unittest.TestCase):
    def test_symbolication_survives_without_paths_or_private_values(self):
        report = {"procName": "AetherFilm", "pid": 42, "faultingThread": 0,
                  "procPath": "/private/user/app", "environment": {"password": "private-secret"},
                  "exception": {"type": "EXC_BAD_ACCESS", "signal": "SIGSEGV", "rawCodes": [1, 0]},
                  "threads": [{"triggered": True, "queue": "private-directory", "frames": [
                      {"imageIndex": 0, "imageOffset": 128, "symbol": "smb2_read_data", "sourceFile": "private-file"}]}],
                  "usedImages": [{"name": "VLCKit", "uuid": "123", "base": 4096, "size": 1024,
                                  "path": "/private/user/VLCKit"}]}
        result = crashes.sanitized_report('{}\n' + json.dumps(report))
        self.assertEqual(result["threads"][0]["frames"][0]["symbol"], "smb2_read_data")
        self.assertEqual(result["usedImages"][0]["base"], 4096)
        self.assertNotIn("private", json.dumps(result))

    def test_unrelated_and_incomplete_reports_do_not_hide_valid_crash(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "AetherFilm-incomplete.ips").write_text("{truncated")
            (root / "AetherFilm-valid.ips").write_text(json.dumps({"procName": "AetherFilm", "pid": 42}))
            (root / "Other.ips").write_text(json.dumps({"procName": "Other"}))
            output = root / "result.json"
            crashes.collect(root, 0, output)
            result = json.loads(output.read_text())
            self.assertEqual(result["unreadable"], 1)
            self.assertEqual([x["pid"] for x in result["reports"]], [42])
