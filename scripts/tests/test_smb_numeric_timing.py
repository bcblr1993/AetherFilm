import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor


spec = importlib.util.spec_from_file_location("smb_fixture", Path(__file__).parents[1] / "test_smb_integration.py")
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)


class NumericTimingTests(unittest.TestCase):
    def test_retains_opening_and_late_failure_without_unbounded_growth(self):
        timing = fixture.NumericSMBTiming()
        for i in range(2000):
            timing.record("private-connection", 8, i, 0)
        snapshot = timing.snapshot()
        self.assertEqual(len(snapshot["events"]), 512)
        self.assertEqual(snapshot["totalEvents"], 2000)
        self.assertEqual(snapshot["omittedEvents"], 1488)
        self.assertEqual([x["sequence"] for x in snapshot["events"][:64]], list(range(1, 65)))
        self.assertEqual([x["sequence"] for x in snapshot["events"][64:]], list(range(1553, 2001)))
        self.assertNotIn("private-connection", json.dumps(snapshot))

    def test_parallel_recording_and_connection_limit_remain_bounded(self):
        timing = fixture.NumericSMBTiming()
        with ThreadPoolExecutor(max_workers=8) as executor:
            list(executor.map(lambda i: timing.record(str(i), 8, i, 1), range(1000)))
        self.assertEqual(len(timing.connections), 256)
        snapshot = timing.snapshot()
        self.assertEqual(snapshot["totalEvents"], 1000)
        self.assertEqual(snapshot["omittedEvents"], 488)
        self.assertEqual(len({x["sequence"] for x in snapshot["events"]}), 512)

    def test_handler_reads_only_numeric_message_identifier_and_preserves_result(self):
        class Packet:
            def __getitem__(self, key):
                if key != "MessageID":
                    raise AssertionError("Sensitive packet fields must not be read")
                return 7

        timing = fixture.NumericSMBTiming()
        result = ([], None, 0)
        self.assertIs(timing.call(lambda *args: result, 8, "secret", None, Packet()), result)
        self.assertEqual([x["phase"] for x in timing.snapshot()["events"]], [0, 1])
        self.assertNotIn("secret", json.dumps(timing.snapshot()))
        def fail(*args):
            raise RuntimeError("private detail")
        with self.assertRaises(RuntimeError):
            timing.call(fail, 8, "secret", None, Packet())
        self.assertEqual(timing.snapshot()["events"][-1]["phase"], 2)
        self.assertNotIn("private detail", json.dumps(timing.snapshot()))

    def test_durable_output_is_valid_and_cannot_overwrite_existing_evidence(self):
        timing = fixture.NumericSMBTiming()
        timing.record("connection", 8, 1, 1)
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / "Logs/timing.json"
            timing.save(output)
            original = output.read_bytes()
            self.assertEqual(json.loads(original)["events"][0]["messageID"], 1)
            with self.assertRaises(FileExistsError):
                timing.save(output)
            self.assertEqual(output.read_bytes(), original)

    def test_negotiate_hook_forwards_the_optional_smb1_compatibility_argument(self):
        class Server:
            def hookSmb2Command(self, command, handler):
                self.handler = handler
                return lambda connection, server, packet, compatibility: ([], None, int(compatibility))

        server = Server()
        timing = fixture.NumericSMBTiming()
        timing.install_one(server, 0)
        self.assertEqual(server.handler("connection", server, {"MessageID": 2}, True), ([], None, 1))
        self.assertEqual(timing.snapshot()["events"][-1]["status"], 1)


if __name__ == "__main__":
    unittest.main()
