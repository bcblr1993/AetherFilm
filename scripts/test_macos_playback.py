#!/usr/bin/env python3
"""Run the complete built Mac playback target in its user's Aqua session."""

import argparse
from collections import Counter
import getpass
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import time
from urllib.parse import urlsplit
import uuid
import importlib.util


def retain_native_crashes(since, output):
    specification = importlib.util.spec_from_file_location(
        "playback_crashes", Path(__file__).with_name("collect_playback_crashes.py"))
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    module.collect(Path.home() / "Library/Logs/DiagnosticReports", since, output)


def test_cases(tree):
    rows = []

    def visit(value):
        if isinstance(value, dict):
            if value.get("nodeType") == "Test Case":
                rows.append((value["nodeIdentifier"], value["result"]))
            for child in value.values():
                visit(child)
        elif isinstance(value, list):
            for child in value:
                visit(child)

    visit(tree)
    return rows


def owns_console_session(console=None):
    uid, user = os.getuid(), getpass.getuser()
    if uid == 0:
        return False
    if console is None:
        console = subprocess.check_output(["stat", "-f", "%u %Su", "/dev/console"], text=True).strip().split()
    if console == [str(uid), user]:
        return True
    # /dev/console can remain root-owned during an active Screen Sharing
    # session. Consult the current ConsoleUser state, retaining both identity
    # and completed foreground-login requirements before launching in Aqua.
    state = subprocess.check_output(["scutil"], input="show State:/Users/ConsoleUser\n", text=True)
    name = re.search(r"^\s*Name\s*:\s*(\S+)\s*$", state, re.MULTILINE)
    owner = re.search(r"^\s*UID\s*:\s*(\d+)\s*$", state, re.MULTILINE)
    return bool(name and owner and name.group(1) == user and int(owner.group(1)) == uid
                and re.search(r"kCGSSessionOnConsoleKey\s*:\s*TRUE\b", state)
                and re.search(r"kCGSessionLoginDoneKey\s*:\s*TRUE\b", state))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--products", required=True, type=Path)
    parser.add_argument("--result", required=True, type=Path)
    parser.add_argument("--require-os-major", type=int)
    args = parser.parse_args()
    products, result = args.products.resolve(), args.result.resolve()
    root = Path(__file__).resolve().parent.parent
    target = "AetherFilmPlaybackTests-macOS"
    runs = list(products.glob("AetherFilm-macOS_*.xctestrun"))
    if len(runs) != 1 or not products.is_dir() or os.path.lexists(result):
        parser.error("Use built Mac products and a fresh result path.")
    version = subprocess.check_output(["sw_vers", "-productVersion"], text=True).strip()
    console = subprocess.check_output(["stat", "-f", "%u %Su", "/dev/console"], text=True).strip().split()
    if not owns_console_session(console):
        parser.error("The test user must own the real Aqua console session.")
    if args.require_os_major is not None and int(version.split(".")[0]) != args.require_os_major:
        parser.error("The actual OS does not match the requested runtime gate.")
    address = os.environ.get("AETHERFILM_SMB_BOOTSTRAP_URL", "")
    url = urlsplit(address)
    if url.scheme != "http" or url.hostname != "127.0.0.1" or url.username or url.password or url.query:
        parser.error("Run through the SMB fixture launcher with --bootstrap-only.")
    processes = subprocess.check_output(["ps", "-axo", "args"], text=True)
    if any(re.search(r"(?:/xcodebuild .*test|UITests.*Runner|/xctest(?:\s|$))", line) for line in processes.splitlines()):
        parser.error("Another test session is active; use the Aqua session exclusively.")
    result.parent.mkdir(parents=True, exist_ok=True)
    own = result.parent / (result.stem + "-runner")
    own.mkdir()
    original_bytes = runs[0].read_bytes()
    configuration = plistlib.loads(original_bytes)
    if "TestConfigurations" in configuration:
        targets = [t for c in configuration["TestConfigurations"] for t in c.get("TestTargets", [])
                   if t.get("BlueprintName") == target]
    else:
        targets = [configuration[target]] if target in configuration else []
    if len(targets) != 1 or targets[0].get("OnlyTestIdentifiers") or targets[0].get("SkipTestIdentifiers"):
        parser.error("The complete original playback target is required.")
    environment = {**targets[0].get("EnvironmentVariables", {}),
                   **targets[0].get("TestingEnvironmentVariables", {})}
    if ("libMainThreadChecker.dylib" not in environment.get("DYLD_INSERT_LIBRARIES", "")
            or any(re.search(r"MTC_.*(?:DISABLE|SUPPRESS)", key)
                   and str(value).lower() not in ("", "0", "false") for key, value in environment.items())):
        parser.error("Keep the original Main Thread Checker enabled.")
    app = products / "Debug/AetherFilm.app"
    bundle = app / ("Contents/PlugIns/" + target + ".xctest/Contents/MacOS/" + target)
    metadata = subprocess.check_output(["dyld_info", "-objc", str(bundle)], text=True)
    compiled = re.findall(r"\[(\S+) (test\w+?)(?:AndReturnError:|WithCompletionHandler:)?\]", metadata)
    if len(compiled) < 42 or len(set(compiled)) != len(compiled):
        parser.error("The original Mac playback cases must be present exactly once.")
    classes = sorted({name for name, _ in compiled})
    demangled = subprocess.check_output(["xcrun", "swift-demangle", "--compact", *classes], text=True).splitlines()
    if len(demangled) != len(classes):
        parser.error("Cannot resolve the actual compiled test classes.")
    class_names = dict(zip(classes, (name.rsplit(".", 1)[-1] for name in demangled)))
    expected_cases = Counter(class_names[name] + "/" + method + "()" for name, method in compiled)
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    session = uuid.uuid4().hex
    targets[0]["CommandLineArguments"] = ["--ui-testing", "--ui-test-session=MacPlayback-" + session]
    targets[0].setdefault("EnvironmentVariables", {})["AETHERFILM_SMB_BOOTSTRAP_URL"] = address
    runtime = products / ("MacPlayback-" + session + ".xctestrun")
    command = ["/usr/bin/xcodebuild", "test-without-building", "-xctestrun", str(runtime),
               "-destination", "platform=macOS,arch=arm64", "-resultBundlePath", str(result),
               "-only-testing:" + target, "-parallel-testing-enabled", "NO", "-collect-test-diagnostics", "never",
               "-test-timeouts-enabled", "YES", "-default-test-execution-time-allowance", "120",
               "-maximum-test-execution-time-allowance", "180"]
    status = own / "exit-status.json"
    crash_evidence_start = time.time()
    child = own / "run.py"
    agent = own / "launchagent.plist"
    label = "com.aethernative.qa.macplayback." + session
    attempted_bootstrap = False
    loaded = False
    runtime_created = False
    try:
        with runtime.open("xb") as output:
            runtime_created = True
            output.write(plistlib.dumps(configuration))
        (own / "original.xctestrun").write_bytes(original_bytes)
        (own / "runtime.xctestrun").write_bytes(runtime.read_bytes())
        child.write_text("import json,subprocess\nfrom pathlib import Path\n"
                         + "result=subprocess.run(" + repr(command) + ",check=False)\n"
                         + "Path(" + repr(str(status)) + ").write_text(json.dumps({'exitCode':result.returncode}))\n")
        agent.write_bytes(plistlib.dumps({"Label": label,
            "ProgramArguments": [sys.executable, str(child)], "WorkingDirectory": str(root), "RunAtLoad": True,
            "LimitLoadToSessionType": "Aqua", "AbandonProcessGroup": False,
            "EnvironmentVariables": {
                "DEVELOPER_DIR": subprocess.check_output(["xcode-select", "-p"], text=True).strip()},
            "StandardOutPath": str(own / "test.log"), "StandardErrorPath": str(own / "stderr.log")}))
        (own / "context.json").write_text(json.dumps({"osVersion": version, "console": console,
            "sourceCommit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
            "command": command, "target": target, "compiledCases": compiled}, indent=2) + "\n")
        attempted_bootstrap = True
        subprocess.run(["launchctl", "bootstrap", "gui/" + str(os.getuid()), str(agent)], check=True)
        loaded = True
        deadline = time.monotonic() + 900
        while not status.exists():
            if time.monotonic() >= deadline:
                raise TimeoutError("The owned Mac playback session exceeded its overall runtime limit.")
            time.sleep(5)
        code = json.loads(status.read_text())["exitCode"]
        if not result.is_dir():
            raise RuntimeError("The test session produced no actual xcresult.")
        for kind in ("summary", "tests"):
            with (own / (kind + ".json")).open("w") as output:
                subprocess.run(["xcrun", "xcresulttool", "get", "test-results", kind, "--path", str(result)],
                               stdout=output, check=True)
        summary = json.loads((own / "summary.json").read_text())
        cases = test_cases(json.loads((own / "tests.json").read_text()))
        raw = "\n".join((own / name).read_text(errors="replace") for name in ("test.log", "stderr.log"))
        if (summary.get("passedTests") != len(compiled) or summary.get("failedTests") != 0
                or summary.get("skippedTests") != 0 or summary.get("expectedFailures", 0)
                or Counter(name for name, _ in cases) != expected_cases
                or any(value != "Passed" for _, value in cases)
                or any(text in raw for text in ("Main Thread Checker:", "UI API called on a background thread",
                                                "GL_INVALID_FRAMEBUFFER_OPERATION"))):
            code = code or 1
        subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
        return code
    finally:
        try:
            retain_native_crashes(crash_evidence_start, own / "native-crashes.json")
        except Exception:
            # Do not disclose parser input or prevent removal of the owned agent.
            print("Native crash evidence collection failed; original test status is retained.", file=sys.stderr)
        try:
            if attempted_bootstrap:
                cleanup = subprocess.run(["launchctl", "bootout", "gui/" + str(os.getuid()) + "/" + label],
                                         capture_output=True, text=True, check=False)
                (own / "cleanup.json").write_text(json.dumps({"exitCode": cleanup.returncode,
                    "stdout": cleanup.stdout, "stderr": cleanup.stderr}) + "\n")
                if loaded and cleanup.returncode:
                    raise RuntimeError("The owned Aqua agent could not be removed.")
        finally:
            if runtime_created:
                runtime.unlink(missing_ok=True)
        if runs[0].read_bytes() != original_bytes:
            raise RuntimeError("The original test configuration changed during execution.")


if __name__ == "__main__":
    sys.exit(main())
