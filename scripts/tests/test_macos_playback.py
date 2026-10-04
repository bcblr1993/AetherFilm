"""Failure-path tests for the Mac CI runner; no UI processes are launched."""

import importlib.util
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "test_macos_playback.py"
spec = importlib.util.spec_from_file_location("macos_playback_runner", SCRIPT)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class MacPlaybackRunnerTests(unittest.TestCase):
    def exercise(self, mode):
        with tempfile.TemporaryDirectory(prefix="AetherFilm-runner-test-") as temporary:
            folder = Path(temporary)
            products = folder / "Products"
            products.mkdir()
            original = products / "AetherFilm-macOS_test.xctestrun"
            original.write_bytes(plistlib.dumps({"AetherFilmPlaybackTests-macOS": {
                "TestingEnvironmentVariables": {"DYLD_INSERT_LIBRARIES": "libMainThreadChecker.dylib"}}}))
            original_bytes = original.read_bytes()
            result = folder / "Results.xcresult"
            bootouts = []

            def output(arguments, **kwargs):
                if arguments[0] == "sw_vers":
                    return "26.6.2\n"
                if arguments[0] == "stat":
                    return "501 qa\n"
                if arguments[0] == "ps":
                    return ""
                if arguments[0] == "dyld_info":
                    return "\n".join("[PlaybackTests testCase" + str(i) + "]" for i in range(42))
                if arguments[0] == "xcode-select":
                    return "/Applications/Xcode.app/Contents/Developer\n"
                if arguments[0] == "git":
                    return "0123456789\n"
                if arguments[:2] == ["xcrun", "swift-demangle"]:
                    return "PlaybackTests\n"
                raise AssertionError("Unexpected external command: " + repr(arguments))

            def execute(arguments, **kwargs):
                if arguments[:2] == ["launchctl", "bootstrap"]:
                    if mode == "bootstrap-failure":
                        raise subprocess.CalledProcessError(5, arguments)
                    agent = plistlib.loads(Path(arguments[-1]).read_bytes())
                    own = Path(agent["ProgramArguments"][1]).parent
                    (own / "exit-status.json").write_text('{"exitCode":0}')
                    (own / "test.log").write_text("")
                    (own / "stderr.log").write_text("Main Thread Checker:" if mode == "stderr-warning" else "")
                    if mode != "missing-result":
                        result.mkdir()
                elif arguments[:2] == ["launchctl", "bootout"]:
                    bootouts.append(arguments[-1])
                elif arguments[:4] == ["xcrun", "xcresulttool", "get", "test-results"]:
                    cases = [{"nodeType": "Test Case", "nodeIdentifier": "PlaybackTests/testCase" + str(i) + "()",
                              "result": "Passed"} for i in range(42)]
                    if mode == "duplicate-case":
                        cases[0] = dict(cases[1])
                    payload = ({"passedTests": 42, "failedTests": 0, "skippedTests": 0, "expectedFailures": 0}
                               if arguments[4] == "summary" else {"testNodes": cases})
                    json.dump(payload, kwargs["stdout"])
                elif arguments[0] != "codesign":
                    raise AssertionError("Unexpected external command: " + repr(arguments))
                return subprocess.CompletedProcess(arguments, 0, stdout="", stderr="")

            error = None
            code = None
            with patch.object(runner.sys, "argv", [str(SCRIPT), "--products", str(products), "--result", str(result)]), \
                    patch.object(runner.os, "getuid", return_value=501), \
                    patch.object(runner.getpass, "getuser", return_value="qa"), \
                    patch.dict(runner.os.environ, {"AETHERFILM_SMB_BOOTSTRAP_URL": "http://127.0.0.1:12345/configuration"}), \
                    patch.object(runner.subprocess, "check_output", side_effect=output), \
                    patch.object(runner.subprocess, "run", side_effect=execute):
                try:
                    code = runner.main()
                except (RuntimeError, subprocess.CalledProcessError) as failure:
                    error = failure
            self.assertEqual(original.read_bytes(), original_bytes)
            self.assertEqual(list(products.glob("MacPlayback-*.xctestrun")), [])
            self.assertEqual(len(bootouts), 1)
            self.assertTrue(bootouts[0].startswith("gui/501/com.aethernative.qa.macplayback."))
            return code, error

    def test_success_status_without_actual_result_is_rejected(self):
        code, error = self.exercise("missing-result")
        self.assertIsNone(code)
        self.assertIsInstance(error, RuntimeError)
        self.assertIn("no actual xcresult", str(error))

    def test_partial_bootstrap_failure_cleans_owned_configuration(self):
        code, error = self.exercise("bootstrap-failure")
        self.assertIsNone(code)
        self.assertIsInstance(error, subprocess.CalledProcessError)

    def test_stderr_main_thread_checker_warning_rejects_success(self):
        code, error = self.exercise("stderr-warning")
        self.assertIsNone(error)
        self.assertEqual(code, 1)

    def test_equal_count_with_duplicate_and_missing_case_is_rejected(self):
        code, error = self.exercise("duplicate-case")
        self.assertIsNone(error)
        self.assertEqual(code, 1)

    def test_complete_matching_result_can_pass(self):
        code, error = self.exercise("complete-result")
        self.assertIsNone(error)
        self.assertEqual(code, 0)


if __name__ == "__main__":
    unittest.main()
