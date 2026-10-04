#!/usr/bin/env python3
"""Run a command against an isolated loopback SMB2 fixture.

Install the test-only dependency in a virtual environment:
    python3 -m pip install -r scripts/test-requirements.txt

Examples:
    python3 scripts/test_smb_integration.py -- swift test --package-path Packages/AetherFilmKit --filter SMB
    python3 scripts/test_smb_integration.py --bootstrap-only --media-folder Tests/Fixtures -- xcodebuild test -scheme AetherFilm-macOS ...

The command inherits AETHERFILM_SMB_TEST_PORT, AETHERFILM_SMB_TEST_PASSWORD,
and AETHERFILM_SMB_STALL_PORT. The test password is generated for each run,
kept only in process memory, and never written to a fixture or auth log.
With --bootstrap-only, Xcode test runners inherit AETHERFILM_SMB_BOOTSTRAP_URL, a
non-secret loopback URL whose GET JSON supplies port, username, password,
share and mediaPath, without any password in their launch environment. Do
not put the password in a scheme or .xctestrun file.
With --media-folder, test media is copied to the FILMS share's media directory
and AETHERFILM_SMB_MEDIA_PATH is set to media. Symlinks and non-media files
are skipped; originals remain untouched.
This fixture verifies SMB2 bytes and errors; SMB3 encryption and real video
playback require their own acceptance tests.
"""

from __future__ import annotations

import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import ipaddress
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
import time


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


class NumericSMBTiming:
    """Bounded command-handler timings; never read command bodies or auth fields."""

    commands = (0, 1, 3, 5, 6, 8, 13, 16)

    def __init__(self):
        self.origin = time.monotonic()
        self.lock = threading.Lock()
        self.connections = {}
        self.events = []
        self.total = 0
        self.omitted = 0

    def record(self, connection, command, message_id, phase, status=None, duration=None):
        with self.lock:
            ordinal = self.connections.get(connection)
            if ordinal is None and len(self.connections) < 256:
                ordinal = len(self.connections) + 1
                self.connections[connection] = ordinal
            self.total += 1
            if len(self.events) == 512:
                self.omitted += 1
                return
            self.events.append({"sequence": self.total, "connection": ordinal or 0,
                                "command": command, "messageID": message_id, "phase": phase,
                                "elapsedSeconds": time.monotonic() - self.origin,
                                "status": status, "durationSeconds": duration})

    def call(self, original, command, connection, server, packet):
        try:
            value = packet["MessageID"]
            message_id = int(value) if isinstance(value, int) else None
        except (KeyError, TypeError):
            message_id = None
        began = time.monotonic()
        self.record(connection, command, message_id, 0)
        try:
            result = original(connection, server, packet)
        except BaseException:
            self.record(connection, command, message_id, 2, duration=time.monotonic() - began)
            raise
        status = result[2] if isinstance(result, tuple) and len(result) == 3 and isinstance(result[2], int) else None
        self.record(connection, command, message_id, 1, status=status, duration=time.monotonic() - began)
        return result

    def install_one(self, server, command):
        original = None

        def measured(connection, current_server, packet):
            return self.call(original, command, connection, current_server, packet)

        original = server.hookSmb2Command(command, measured)
        if original is None:
            raise RuntimeError("Missing expected SMB2 numeric command handler")

    def snapshot(self):
        with self.lock:
            return {"schemaVersion": 1, "commands": list(self.commands), "capacity": 512,
                    "connectionCapacity": 256, "totalEvents": self.total,
                    "omittedEvents": self.omitted, "events": list(self.events)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--listen-address", default="127.0.0.1", help="Exact owned host IPv4 for physical tests; default loopback")
    parser.add_argument("--bootstrap-only", action="store_true", help="Keep the password out of the command environment; fetch credentials from the loopback bootstrap URL in memory")
    parser.add_argument("--media-folder", type=Path, help="Copy test video/subtitle fixtures into FILMS/media without modifying their originals")
    parser.add_argument("--numeric-transport-diagnostics", action="store_true", help="Print bounded numeric SMB2 command-handler timings; no credentials, paths or payloads")
    parser.add_argument("command", nargs=argparse.REMAINDER, help="Command to run, after --")
    arguments = parser.parse_args()
    try:
        listen_address = str(ipaddress.IPv4Address(arguments.listen_address))
        address = ipaddress.IPv4Address(listen_address)
        allowed = (listen_address == "127.0.0.1" or any(address in ipaddress.IPv4Network(n) for n in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16")))
        if not allowed:
            parser.error("--listen-address must be loopback or an exact owned LAN IPv4")
    except ipaddress.AddressValueError:
        parser.error("--listen-address must be a literal IPv4 address")
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
        server = smbserver.SimpleSMBServer(listenAddress=listen_address, listenPort=0)
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
        timing = NumericSMBTiming() if arguments.numeric_transport_diagnostics else None
        if timing is not None:
            for command_id in timing.commands:
                timing.install_one(server.getServer(), command_id)
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
        configuration = {
            "host": listen_address,
            "port": server.getServer().server_address[1],
            "username": "aetherfilm-fixture",
            "password": password,
            "share": "FILMS",
            "mediaPath": "media" if media_folder is not None else None,
        }

        class BootstrapHandler(BaseHTTPRequestHandler):
            def setup(self):
                super().setup()
                self.connection.settimeout(5)

            def do_GET(self):
                if self.path != "/configuration":
                    self.send_response(404)
                    self.send_header("Content-Length", "0")
                    self.end_headers()
                    return
                payload = json.dumps(configuration).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(payload)))
                self.send_header("Cache-Control", "no-store")
                self.end_headers()
                try:
                    self.wfile.write(payload)
                except (BrokenPipeError, ConnectionResetError):
                    pass

            def log_message(self, format, *args):
                # Never record bootstrap requests or credential responses.
                pass

        bootstrap = ThreadingHTTPServer((listen_address, 0), BootstrapHandler)
        bootstrap.daemon_threads = True
        bootstrap_thread = threading.Thread(target=bootstrap.serve_forever, daemon=True)
        bootstrap_thread.start()
        environment = os.environ.copy()
        environment.pop("AETHERFILM_SMB_TEST_PASSWORD", None)
        environment.pop("AETHERFILM_SMB_MEDIA_PATH", None)
        environment.update(
            AETHERFILM_SMB_TEST_PORT=str(server.getServer().server_address[1]),
            AETHERFILM_SMB_STALL_PORT=str(stalled.getsockname()[1]),
            AETHERFILM_SMB_BOOTSTRAP_URL=f"http://{listen_address}:{bootstrap.server_port}/configuration",
            AETHERFILM_SMB_TEST_HOST=listen_address,
        )
        if not arguments.bootstrap_only:
            environment["AETHERFILM_SMB_TEST_PASSWORD"] = password
        if media_folder is not None:
            environment["AETHERFILM_SMB_MEDIA_PATH"] = "media"
        print("Isolated SMB2 fixture ready on the exact owned IPv4 interface; ephemeral credentials remain in memory.", flush=True)
        try:
            return run_command(command, environment)
        except OSError:
            print("Unable to start the requested test command.", file=sys.stderr)
            return 2
        finally:
            bootstrap.shutdown()
            bootstrap.server_close()
            bootstrap_thread.join(timeout=1)
            finished.set()
            stalled.close()
            stalled_thread.join(timeout=1)
            with clients_lock:
                for client in stalled_clients:
                    client.close()
            server.getServer().shutdown()
            server.stop()
            server_thread.join(timeout=1)
            if timing is not None:
                print("SMB2 numeric timing " + json.dumps(timing.snapshot(), separators=(",", ":")), flush=True)


if __name__ == "__main__":
    sys.exit(main())
