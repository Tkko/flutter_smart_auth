#!/usr/bin/env python3
"""Host-side regression tests for the SMS harness and its CI wrapper."""

import os
from pathlib import Path
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[2]
HARNESS = ROOT / "example/integration_test/run_sms_tests.sh"

FLUTTER = r"""
import os
from pathlib import Path
import signal
import sys
import time

root = Path(os.environ["MOCK_DIR"])
mode = os.environ.get("MOCK_MODE")
if "--reporter" not in sys.argv or sys.argv[sys.argv.index("--reporter") + 1] != "expanded":
    sys.exit("Readiness markers require the expanded reporter")
if mode == "flutter-failure":
    sys.exit(7)
if mode == "flutter-hang":
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    print("Flutter is stuck", flush=True)
    while True:
        time.sleep(1)
for marker, ack in [
    ("HINT_READY", "hint"),
    ("SMS_SIGNATURE=abcdefghijk", "retriever"),
    ("SMS_CONSENT_READY", "consent"),
]:
    print(marker, flush=True)
    deadline = time.monotonic() + 3
    while not (root / ack).exists():
        if time.monotonic() >= deadline:
            sys.exit("adb did not react before test completion: " + marker)
        time.sleep(.01)
print("All tests passed!", flush=True)
"""

ADB = r"""
import os
from pathlib import Path
import sys
import time

root = Path(os.environ["MOCK_DIR"])
args = sys.argv[1:]
assert args[:2] == ["-s", "emulator-5554"], args
command = args[2:]
with (root / "adb.log").open("a") as log:
    log.write(" ".join(command) + "\n")
mode = os.environ.get("MOCK_MODE")
if command == ["shell", "input", "keyevent", "KEYCODE_BACK"]:
    if mode == "adb-failure":
        sys.exit(9)
    if mode == "adb-hang":
        time.sleep(60)
    (root / "hint").touch()
elif command[:3] == ["emu", "sms", "send"]:
    assert command[3] == "5551234", command
    if command[4].startswith("<#>"):
        assert command[4] == "<#> Your code is 123456 abcdefghijk", command
        (root / "retriever").touch()
    else:
        assert command[4] == "Your code is 654321", command
elif command == ["shell", "cat", "/sdcard/ui.xml"]:
    if mode != "missing-allow":
        print('<node text="Allow" bounds="[10,20][30,60]" />')
elif command[:3] == ["shell", "input", "tap"]:
    assert command[3:] == ["20", "40"], command
    (root / "consent").touch()
elif command == ["exec-out", "screencap", "-p"]:
    if mode == "diagnostics-hang":
        time.sleep(60)
    print("screenshot")
elif command == ["logcat", "-d"]:
    if mode == "diagnostics-hang":
        time.sleep(60)
    if mode == "diagnostics-failure":
        sys.exit(6)
    print("SmsRetriever: diagnostic")
"""


class SmsHarnessTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.env = dict(os.environ, MOCK_DIR=self.temp.name,
                        RUNNER_TEMP=self.temp.name, GITHUB_ACTIONS="true")
        self.env["PATH"] = self.temp.name + os.pathsep + os.environ["PATH"]
        self.executable("flutter", f"#!{sys.executable}\n" + FLUTTER)
        self.executable("adb", f"#!{sys.executable}\n" + ADB)
        self.executable("sleep", "#!/usr/bin/env bash\nexit 0\n")

    def executable(self, name, content):
        path = self.directory / name
        path.write_text(content)
        path.chmod(0o755)

    def run_command(self, command, mode="", expected=0):
        self.env["MOCK_MODE"] = mode
        process = subprocess.Popen(
            command, cwd=HARNESS.parent.parent, env=self.env,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, start_new_session=True,
        )
        try:
            output, _ = process.communicate(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            output, _ = process.communicate()
            self.fail("Harness exceeded the regression test deadline:\n" + output)
        self.assertEqual(process.returncode, expected, output)
        return output

    def ci_command(self, duration="8s"):
        timeout = shutil.which("timeout") or shutil.which("gtimeout")
        self.assertIsNotNone(timeout, "GNU timeout is required (brew install coreutils on macOS)")
        # Exercise the actual folded shell command from CI, with shorter limits.
        workflow = (ROOT / ".github/workflows/ci.yml").read_text()
        script = workflow.split("          script: >-\n", 1)[1]
        lines = []
        for line in script.splitlines():
            if not line.startswith("            "):
                break
            lines.append(line.strip())
        command = shlex.split(" ".join(lines))
        self.assertEqual(command[:4], ["bash", "-o", "pipefail", "-c"])
        command[4] = command[4].replace("15m", duration)
        command[4] = command[4].replace("15s", "1s").replace("5s", "0.2s")
        self.executable("timeout", f"#!/usr/bin/env bash\nexec {shlex.quote(timeout)} \"$@\"\n")
        return command

    def test_markers_are_handled_before_flutter_completes(self):
        output = self.run_command(["bash", str(HARNESS)])
        self.assertIn("All tests passed!", output)
        self.assertTrue((self.directory / "consent").exists())

    def test_flutter_failure_propagates_through_tee_and_collects_diagnostics(self):
        self.run_command(self.ci_command(), mode="flutter-failure", expected=7)
        self.assertTrue((self.directory / "sms-tests.log").exists())
        self.assertIn("screenshot", (self.directory / "sms-failure.png").read_text())
        self.assertIn("SmsRetriever", (self.directory / "sms-logcat.txt").read_text())

    def test_success_through_ci_wrapper_does_not_collect_failure_diagnostics(self):
        self.run_command(self.ci_command())
        self.assertIn("All tests passed!", (self.directory / "sms-tests.log").read_text())
        self.assertFalse((self.directory / "sms-failure.png").exists())

    def test_adb_failure_propagates(self):
        self.run_command(["bash", str(HARNESS)], mode="adb-failure", expected=9)

    def test_missing_consent_button_fails_explicitly(self):
        output = self.run_command(["bash", str(HARNESS)], mode="missing-allow", expected=1)
        self.assertIn("SMS consent dialog has no Allow button", output)

    def test_flutter_hang_is_killed_and_collects_diagnostics(self):
        started = time.monotonic()
        # SIGKILL must also stop children that ignore SIGTERM.
        self.run_command(self.ci_command("1s"), mode="flutter-hang", expected=137)
        self.assertLess(time.monotonic() - started, 5)
        self.assertTrue((self.directory / "sms-logcat.txt").exists())

    def test_adb_hang_is_bounded_too(self):
        self.run_command(self.ci_command("1s"), mode="adb-hang", expected=137)
        self.assertTrue((self.directory / "sms-failure.png").exists())

    def test_diagnostic_failure_preserves_original_status(self):
        # An absent Allow button fails the harness; failing diagnostics must not
        # replace that exit status with adb's status.
        command = self.ci_command()
        command[4] = command[4].replace(
            'status=$?;', 'status=$?; export MOCK_MODE=diagnostics-failure;'
        )
        self.run_command(command, mode="missing-allow", expected=1)

    def test_diagnostic_hangs_are_bounded_and_preserve_original_status(self):
        command = self.ci_command()
        command[4] = command[4].replace(
            'status=$?;', 'status=$?; export MOCK_MODE=diagnostics-hang;'
        )
        started = time.monotonic()
        self.run_command(command, mode="flutter-failure", expected=7)
        self.assertLess(time.monotonic() - started, 5)


if __name__ == "__main__":
    unittest.main()
