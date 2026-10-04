#!/usr/bin/env python3
"""Plan or run one ARM64 core build from a separately prepared source tree.

This parameterized entry point has not undergone a full portable rebuild.
It never installs tools, alters HOME/RUSTUP_HOME or replaces an earlier output.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import signal
import subprocess
import time

PACKAGE = Path(__file__).resolve().parents[1]
PLATFORMS = {"mac": ("macosx27.0", "aarch64-apple-darwin"),
             "sim": ("iphonesimulator27.0", "aarch64-apple-ios-sim"),
             "device": ("iphoneos27.0", "aarch64-apple-ios")}


def require(ok, message):
    if not ok:
        raise ValueError(message)


def digest(path):
    value = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def read_command(argv, env=None):
    result = subprocess.run(argv, env=env, capture_output=True, text=True, timeout=30)
    require(result.returncode == 0, result.stderr or f"Command failed: {argv}")
    return result.stdout.strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True, help="Fresh pinned VLC source with all local patches applied")
    parser.add_argument("--output", type=Path, required=True, help="New owned build/output directory")
    parser.add_argument("--platform", choices=PLATFORMS, required=True)
    parser.add_argument("--rust-bin", type=Path, required=True, help="Existing Rust1.96.0 bin directory")
    parser.add_argument("--gmake", type=Path, required=True, help="Existing GNU make executable")
    parser.add_argument("--host-tools-bin", type=Path, required=True, help="Existing pinned VLC extras/tools build/bin")
    parser.add_argument("--execute", action="store_true", help="Run the build; default only prints the checked plan")
    args = parser.parse_args()
    source, output = args.source.resolve(), args.output.resolve()
    require(source.is_dir() and not output.exists(), "Source missing or output already exists")
    require(output.parent.is_dir(), "Create the owned output parent directory first")
    require(output != source and source not in output.parents, "Build output must be outside source")
    inputs = json.loads((PACKAGE / "Provenance/local-inputs.json").read_text())
    for relative, expected in inputs["native8TouchedSourceSHA256"].items():
        require(digest(source / relative) == expected, f"Patched source differs: {relative}")
    config = PACKAGE / "Configuration/build26.conf"
    expected_config = next(row for row in inputs["files"] if row["path"] == "Configuration/build26.conf")
    require(digest(config) == expected_config["sha256"], "Build configuration differs")
    sdk, rust_target = PLATFORMS[args.platform]
    require(read_command(["xcrun", "--sdk", sdk, "--show-sdk-version"]) == "27.0", "SDK27.0 required")
    require("GNU Make" in read_command([str(args.gmake.resolve()), "--version"]), "GNU make required")
    rust_bin = args.rust_bin.resolve()
    require(read_command([str(rust_bin / "rustc"), "--version"]).startswith("rustc 1.96.0 "), "Rust1.96.0 required")
    require(read_command([str(rust_bin / "cargo"), "--version"]).startswith("cargo 1.96.0 "), "Cargo1.96.0 required")
    target_lib = Path(read_command([str(rust_bin / "rustc"), "--print", "target-libdir", "--target", rust_target]))
    require(any(target_lib.glob("libstd-*.rlib")), f"Installed Rust standard library missing: {rust_target}")
    script = source / "extras/package/apple/build.sh"
    require(script.is_file() and (source / "contrib/tarballs/lua-5.4.4.tar.gz").is_file(), "Prepared source materials missing")
    host_tools = args.host_tools_bin.resolve()
    require((host_tools / "meson").is_file(), "Pinned existing Meson host tool required")
    command = ["/bin/bash", str(script), "--arch=arm64", "--sdk=" + sdk,
               "--config=" + str(config), "--disable-debug", "-j4"]
    plan = {"scope": "PARAMETERIZED_REBUILD_NOT_PREVIOUSLY_EXECUTED", "command": command,
            "cwd": str(output), "platform": args.platform, "sdk": sdk, "minimum": "26.0",
            "rustTarget": rust_target, "sourceMatchesThirteenNative8TouchedFiles": True,
            "fullTreeIdentityRequiresVerifiedSourceArchive": True, "releaseAccepted": False}
    if not args.execute:
        print(json.dumps(plan, indent=2))
        return
    require(shutil.disk_usage(output.parent).free >= 12 * 1024**3, "Less than 12 GiB free")
    output.mkdir(mode=0o700)
    caches = output / "Caches"
    for name in ["bin", "cargo", "ccache", "pip", "xdg", "clang-modules", "tmp"]:
        (caches / name).mkdir(parents=True)
    tmp = str(caches / "tmp") + "/"
    # contrib can invoke meson through env -i; preserve this owned temporary path.
    meson = caches / "bin/meson"
    meson.write_text("#!/bin/sh\nTMPDIR=" + shlex.quote(tmp) + "\nPYTHONDONTWRITEBYTECODE=1\n"
                     "export TMPDIR PYTHONDONTWRITEBYTECODE\nexec " + shlex.quote(str(host_tools / "meson")) + ' "$@"\n')
    meson.chmod(0o700)
    additions = {"MAKE": str(args.gmake.resolve()), "MAKEFLAGS": "-j4 CMAKEFLAGS=--parallel=4 MAKEFLAGS=-j4",
                 "CARGO_HOME": str(caches / "cargo"), "CCACHE_DIR": str(caches / "ccache"),
                 "PIP_CACHE_DIR": str(caches / "pip"), "XDG_CACHE_HOME": str(caches / "xdg"),
                 "CLANG_MODULE_CACHE_PATH": str(caches / "clang-modules"), "TMPDIR": tmp,
                 "PYTHONDONTWRITEBYTECODE": "1", "RUSTUP_AUTO_INSTALL": "0",
                 "RUSTUP_AUTO_UPDATE_DISABLED": "1", "RUSTUP_TOOLCHAIN": "1.96.0-aarch64-apple-darwin",
                 "RUSTC": str(rust_bin / "rustc"), "MESON_BUILD": "--jobs=4",
                 "CARGO_BUILD_JOBS": "4", "CMAKE_BUILD_PARALLEL_LEVEL": "4", "GIT_OPTIONAL_LOCKS": "0"}
    environment = os.environ.copy()
    environment.update(additions)
    environment["PATH"] = ":".join([str(caches / "bin"), str(rust_bin), str(host_tools),
                                    str(caches / "cargo/bin"), environment.get("PATH", "/usr/bin:/bin")])
    (output / "run-input.json").write_text(json.dumps({**plan, "ownedEnvironment": additions}, indent=2) + "\n")
    process, reason, started = None, None, time.monotonic()
    try:
        with (output / "build.log").open("xb") as log:
            process = subprocess.Popen(command, cwd=output, env=environment, stdout=log,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            while process.poll() is None:
                if shutil.disk_usage(output).free < 12 * 1024**3:
                    reason = "below 12 GiB reserve"; break
                if time.monotonic() - started > 4 * 60 * 60:
                    reason = "four-hour build deadline"; break
                time.sleep(0.5)
    finally:
        if process is not None and process.poll() is None:
            for sig in [signal.SIGTERM, signal.SIGKILL]:
                try:
                    os.killpg(process.pid, sig)
                    process.wait(timeout=3)
                    break
                except ProcessLookupError:
                    break
                except subprocess.TimeoutExpired:
                    continue
    exit_code = process.returncode if process else None
    archive = output / "static-lib/libvlc-full-static.a"
    report = {"exitCode": exit_code, "stopReason": reason,
              "archivePresent": archive.is_file(), "compilerCommandCompleted": exit_code == 0 and reason is None,
              "archivePlatformModuleAndLicenseReviewRequired": True, "wrapperAppAndReleaseAccepted": False}
    (output / "outcome.json").write_text(json.dumps(report, indent=2) + "\n")
    require(report["compilerCommandCompleted"] and report["archivePresent"], "Core build failed; original output preserved")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
