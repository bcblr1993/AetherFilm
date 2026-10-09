#!/usr/bin/env python3
"""Read-only NAS acceptance; credentials exist only in memory, never argv/results."""
import argparse
import getpass
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import logging
from pathlib import Path
import plistlib
import secrets
import subprocess
import tempfile
import threading


def discover(host, username, password, selection="largest"):
    from impacket.smbconnection import SMBConnection
    logging.getLogger("impacket").disabled = True
    client = SMBConnection(host, host, timeout=12)
    try:
        client.login(username, password)
        shares = [entry["shi1_netname"][:-1] for entry in client.listShares()
                  if entry["shi1_type"] == 0 and not entry["shi1_netname"][:-1].endswith("$")]
        candidates = []
        visited = 0
        for share in shares:
            queue = [("", 0)]
            while queue and visited < 40 and len(candidates) < 3:
                path, depth = queue.pop(0)
                visited += 1
                try:
                    entries = client.listPath(share, (path + "/" if path else "") + "*")
                except Exception:
                    continue
                for entry in entries:
                    name = entry.get_longname()
                    if name in (".", ".."):
                        continue
                    child = (path + "/" if path else "") + name
                    if entry.is_directory():
                        if depth < 3:
                            queue.append((child, depth + 1))
                    elif name.rsplit(".", 1)[-1].lower() in ("mp4", "mkv", "mov", "avi", "m4v") and entry.get_filesize() > 1_048_576:
                        candidates.append((entry.get_filesize(), share, child))
                        if len(candidates) == 3:
                            break
            if len(candidates) == 3:
                break
        if not candidates:
            raise ValueError("No media found within the bounded read-only search.")
        ranked = sorted(candidates)
        size, share, path = ranked[0] if selection == "smallest" else ranked[len(ranked) // 2] if selection == "middle" else ranked[-1]
        tree = client.connectTree(share)
        file_id = client.openFile(tree, path, desiredAccess=1, shareMode=1)
        expected_ranges = []
        try:
            for offset in [0, min(40_806, size - 1), size // 2, max(0, size - 524_288)]:
                count = min(524_288, size - offset)
                data = client.readFile(tree, file_id, offset=offset, bytesToRead=count, singleCall=False)
                if len(data) != count:
                    raise ValueError("Independent bounded range was incomplete.")
                expected_ranges.append({"offset": offset, "count": count, "sha256": hashlib.sha256(data).hexdigest()})
        finally:
            client.closeFile(tree, file_id)
            client.disconnectTree(tree)
        return {"host": host, "username": username, "password": password,
                "share": share, "path": path, "size": size, "expectedRanges": expected_ranges}
    finally:
        client.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--xctestrun", required=True, type=Path)
    parser.add_argument("--destination", required=True)
    parser.add_argument("--result", required=True, type=Path)
    parser.add_argument("--selection", choices=("largest", "smallest", "middle"), default="largest")
    parser.add_argument("--platform", choices=("iOS", "macOS"), default="iOS")
    args = parser.parse_args()
    if args.result.exists():
        parser.error("Use a fresh result path; existing results are preserved.")
    host = input("NAS host: ")
    username = input("NAS user: ")
    password = getpass.getpass("NAS password: ")
    try:
        media = discover(host, username, password, args.selection)
    except Exception as error:
        print("Read-only discovery failed: " + type(error).__name__)
        return 1
    password = None
    route = "/" + secrets.token_hex(24)

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_GET(self):
            if self.path != route:
                self.send_error(404)
                return
            data = json.dumps(media).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

    original = args.xctestrun.resolve()
    configuration = plistlib.loads(original.read_bytes())
    target_name = "AetherFilmPlaybackTests-" + args.platform
    targets = [target for group in configuration.get("TestConfigurations", [])
               for target in group.get("TestTargets", [])
               if target.get("BlueprintName") == target_name]
    if not targets and target_name in configuration:
        targets = [configuration[target_name]]
    if not targets:
        parser.error("The requested playback target is absent from this build.")
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    server.daemon_threads = True
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    address = "http://127.0.0.1:" + str(server.server_port) + route
    for target in targets:
        target.setdefault("EnvironmentVariables", {})["AETHERFILM_NAS_BOOTSTRAP_URL"] = address
    copy = None
    try:
        with tempfile.NamedTemporaryFile(prefix="AetherFilm-NAS-", suffix=".xctestrun",
                                         dir=original.parent, delete=False) as file:
            copy = Path(file.name)
            file.write(plistlib.dumps(configuration))
        print("Private NAS discovered; running read-only production-provider playback acceptance.", flush=True)
        return subprocess.run([
            "xcodebuild", "test-without-building", "-xctestrun", str(copy),
            "-destination", args.destination, "-resultBundlePath", str(args.result),
            "-only-testing:" + target_name + "/UserNASPlaybackTests",
            "-parallel-testing-enabled", "NO", "-collect-test-diagnostics", "never",
        ], check=False).returncode
    finally:
        if copy:
            copy.unlink(missing_ok=True)
        server.shutdown()
        server.server_close()
        thread.join()
        media.clear()


if __name__ == "__main__":
    raise SystemExit(main())
