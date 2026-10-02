#!/usr/bin/env python3
"""Pass a non-secret loopback bootstrap URL to an existing playback test build."""

import argparse
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
from urllib.parse import urlsplit


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--xctestrun", required=True, type=Path)
    parser.add_argument("--destination", required=True)
    parser.add_argument("--result", required=True, type=Path)
    parser.add_argument("--target", default="AetherFilmPlaybackTests-iOS")
    parser.add_argument("--all-playback", action="store_true")
    args = parser.parse_args()
    address = os.environ.get("AETHERFILM_SMB_BOOTSTRAP_URL", "")
    url = urlsplit(address)
    if url.scheme != "http" or url.hostname != "127.0.0.1" or url.username or url.password or url.query:
        raise SystemExit("Run inside the SMB fixture launcher with --bootstrap-only.")
    original = args.xctestrun.resolve()
    configuration = plistlib.loads(original.read_bytes())
    if "TestConfigurations" in configuration:
        targets = [target for group in configuration["TestConfigurations"] for target in group.get("TestTargets", [])
                   if target.get("BlueprintName") == args.target]
    else:
        targets = [configuration[args.target]] if args.target in configuration else []
    if not targets:
        raise SystemExit("The requested playback target is absent from this build.")
    for target in targets:
        target.setdefault("EnvironmentVariables", {})["AETHERFILM_SMB_BOOTSTRAP_URL"] = address
    if args.result.exists():
        raise SystemExit("Choose a fresh result bundle path.")
    # Keeping the copy beside the original preserves __TESTROOT__ resolution.
    # It contains only the random loopback URL, never the fixture password.
    with tempfile.NamedTemporaryFile(prefix="AetherFilm-SMB-", suffix=".xctestrun", dir=original.parent, delete=False) as file:
        copy = Path(file.name)
        file.write(plistlib.dumps(configuration))
    try:
        result = subprocess.run([
            "xcodebuild", "test-without-building", "-xctestrun", str(copy), "-destination", args.destination,
            "-resultBundlePath", str(args.result),
            "-only-testing:" + args.target + ("" if args.all_playback else "/FilmPlaybackTests/testRealSMBStreamRepeatedSeekAndReopenReleasesReads"),
            "-parallel-testing-enabled", "NO", "-collect-test-diagnostics", "never"
        ], check=False)
        raise SystemExit(result.returncode)
    finally:
        copy.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
