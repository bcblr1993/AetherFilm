#!/usr/bin/env python3
"""Run a command against an isolated loopback SMB2 fixture.

Install the test-only dependency in a virtual environment:
    python3 -m pip install -r scripts/test-requirements.txt

Examples:
    python3 scripts/test_smb_integration.py -- swift test --package-path Packages/AetherFilmKit --filter SMB
    python3 scripts/test_smb_integration.py --media-folder Tests/Fixtures -- xcodebuild test -scheme AetherFilm-macOS ...

The command inherits AETHERFILM_SMB_TEST_PORT, AETHERFILM_SMB_TEST_PASSWORD,
and AETHERFILM_SMB_STALL_PORT. The test password is generated for each run,
kept only in process memory, and never written to a fixture or auth log.
With --media-folder, test media is copied to the FILMS share's media directory
and AETHERFILM_SMB_MEDIA_PATH is set to media. Symlinks and non-media files
are skipped; originals remain untouched.
This fixture verifies SMB2 bytes and errors; SMB3 encryption and real video
playback require their own acceptance tests.
"""

from __future__ import annotations

import argparse
import logging
import os
from pathlib import Path
import secrets
import signal
import shutil
import socket
import subprocess
import sys
import tempfile
import threading


def run_command(command: list[str], environment: dict[str, str]) -> int:
    with subprocess.Popen(command, env=environment, start_new_session=True) as process:
        try:
            return process.wait()
        except KeyboardInterrupt:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            return 130


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--media-folder", type=Path, help="Copy test video/subtitle fixtures into FILMS/media without modifying their originals")
    parser.add_argument("command", nargs=argparse.REMAINDER, help="Command to run, after --")
    arguments = parser.parse_args()
    command = arguments.command
    if command[:1] == ["--"]:
        command = command[1:]
    if not command:
        parser.error("provide a command after --")
    media_folder = arguments.media_folder
    if media_folder is not None:
        try:
            media_folder = media_folder.resolve(strict=True)
        except OSError:
            parser.error("--media-folder must be an existing directory")
        if not media_folder.is_dir():
            parser.error("--media-folder must be an existing directory")

    # Disable protocol/auth logging before importing the fixture server.
    logging.disable(logging.CRITICAL)
    try:
        from impacket import smbserver, smb3structs
        from impacket.nt_errors import STATUS_SUCCESS, STATUS_MORE_PROCESSING_REQUIRED
        from impacket.ntlm import compute_lmhash, compute_nthash
    except ImportError:
        print("Install test dependencies in a venv with: python3 -m pip install -r scripts/test-requirements.txt", file=sys.stderr)
        return 2

    with tempfile.TemporaryDirectory(prefix="aetherfilm-smb-fixture-") as temporary:
        root = Path(temporary)
        nested = root / "nested"
        nested.mkdir()
        (nested / "中文目录").mkdir()
        (nested / "sample.bin").write_bytes(bytes(index % 251 for index in range(1_048_649)))
        if media_folder is not None:
            allowed = {".mp4", ".m4v", ".mov", ".mkv", ".avi", ".webm", ".ts", ".m2ts", ".mpg", ".mpeg", ".wmv", ".flv", ".srt", ".ass", ".ssa", ".vtt", ".sub"}

            def ignore_non_media(directory: str, names: list[str]) -> list[str]:
                ignored = []
                for name in names:
                    item = Path(directory) / name
                    if item.is_symlink() or (not item.is_dir() and item.suffix.lower() not in allowed):
                        ignored.append(name)
                return ignored

            shutil.copytree(media_folder, root / "media", ignore=ignore_non_media)

        password = secrets.token_urlsafe(24)
        server = smbserver.SimpleSMBServer(listenAddress="127.0.0.1", listenPort=0)
        server.setSMB2Support(True)
        server.addShare("FILMS", str(root), "AetherFilm isolated protocol fixture", readOnly="yes")
        server.addCredential("aetherfilm-fixture", 1000, compute_lmhash(password), compute_nthash(password))

        def auth_result(smbServer, connData, **kwargs):
            if "AUTHENTICATE_MESSAGE" not in connData:
                connData["SignatureEnabled"] = False

        server.setAuthCallback(auth_result)

        # Impacket 0.13.0 encodes failed authentication as SessionSetup_Response.
        # A failure must use SMB2 Error, and has no valid shared signing key.
        original_setup = None

        def setup_reply(connId, smbServer, recvPacket):
            commands, packets, status = original_setup(connId, smbServer, recvPacket)
            if status not in (STATUS_SUCCESS, STATUS_MORE_PROCESSING_REQUIRED):
                connData = smbServer.getConnectionData(connId, False)
                connData["SignatureEnabled"] = False
                smbServer.setConnectionData(connId, connData)
                return [smb3structs.SMB2Error()], None, status
            return commands, packets, status

        original_setup = server.getServer().hookSmb2Command(smb3structs.SMB2_SESSION_SETUP, setup_reply)
        server_thread = threading.Thread(target=server.start, daemon=True)
        server_thread.start()

        stalled = socket.socket()
        stalled.bind(("127.0.0.1", 0))
        stalled.listen(8)
        stalled.settimeout(0.25)
        stalled_clients: list[socket.socket] = []
        clients_lock = threading.Lock()
        finished = threading.Event()

        def accept_stalled():
            while not finished.is_set():
                try:
                    client, _ = stalled.accept()
                    with clients_lock:
                        stalled_clients.append(client)
                except socket.timeout:
                    continue
                except OSError:
                    return

        stalled_thread = threading.Thread(target=accept_stalled, daemon=True)
        stalled_thread.start()
        environment = os.environ.copy()
        environment.update(
            AETHERFILM_SMB_TEST_PORT=str(server.getServer().server_address[1]),
            AETHERFILM_SMB_TEST_PASSWORD=password,
            AETHERFILM_SMB_STALL_PORT=str(stalled.getsockname()[1]),
        )
        if media_folder is not None:
            environment["AETHERFILM_SMB_MEDIA_PATH"] = "media"
        print("Isolated SMB2 fixture ready on loopback; ephemeral credentials remain in memory.", flush=True)
        try:
            return run_command(command, environment)
        except OSError:
            print("Unable to start the requested test command.", file=sys.stderr)
            return 2
        finally:
            finished.set()
            stalled.close()
            stalled_thread.join(timeout=1)
            with clients_lock:
                for client in stalled_clients:
                    client.close()
            server.getServer().shutdown()
            server.stop()
            server_thread.join(timeout=1)


if __name__ == "__main__":
    sys.exit(main())
