"""Drive real Aftergrowth game processes through the --autotest command channel.

Each Instance is a separate Godot process with its own user folder
(--instance=<name>). Commands are appended to autotest_inbox.txt; results are
read from autotest_outbox.json. See src/dev/autotest_driver.gd.
"""
import json, os, shutil, subprocess, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", "godot")
USER_DIR = os.environ.get("AFTERGROWTH_USER_DIR", os.path.expanduser("~/.local/share/Aftergrowth"))
LOG_DIR = os.path.join(ROOT, "tests", "_out")


class Instance:
    def __init__(self, name, headless=True, extra_args=None, display_env=None):
        self.name = name
        self.headless = headless
        self.extra = extra_args or []
        self.env = dict(os.environ, **(display_env or {}))
        self.root = os.path.join(USER_DIR, "instances", name)
        self.proc = None
        self.seq = 0

    @property
    def inbox(self):
        return os.path.join(self.root, "autotest_inbox.txt")

    @property
    def outbox(self):
        return os.path.join(self.root, "autotest_outbox.json")

    def wipe(self):
        shutil.rmtree(self.root, ignore_errors=True)

    def start(self, timeout=40):
        os.makedirs(self.root, exist_ok=True)
        for p in (self.inbox, self.outbox):
            if os.path.exists(p):
                os.remove(p)
        os.makedirs(LOG_DIR, exist_ok=True)
        args = [GODOT]
        if self.headless:
            args.append("--headless")
        args += ["--path", ROOT] + self.extra + ["--", f"--instance={self.name}", "--autotest"]
        self.log = open(os.path.join(LOG_DIR, f"{self.name}.log"), "a")
        self.log.write(f"\n===== start {time.ctime()} {' '.join(args)}\n")
        self.log.flush()
        self.proc = subprocess.Popen(args, stdout=self.log, stderr=subprocess.STDOUT, env=self.env)
        self.seq = 0
        self._wait(0, timeout)
        return self

    def _wait(self, seq, timeout):
        end = time.time() + timeout
        while time.time() < end:
            if self.proc.poll() is not None and not os.path.exists(self.outbox):
                raise RuntimeError(f"{self.name}: process exited ({self.proc.returncode})")
            try:
                with open(self.outbox) as f:
                    d = json.load(f)
                if d.get("seq") == seq:
                    return d
            except (OSError, ValueError):
                pass
            time.sleep(0.05)
        raise TimeoutError(f"{self.name}: no answer for seq {seq}")

    def cmd(self, line, timeout=30):
        with open(self.inbox, "a") as f:
            f.write(line + "\n")
        self.seq += 1
        d = self._wait(self.seq, timeout)
        return d

    def state(self):
        return self.cmd("report")["state"]

    def quit(self, timeout=15):
        if self.proc and self.proc.poll() is None:
            try:
                with open(self.inbox, "a") as f:
                    f.write("quit\n")
                self.proc.wait(timeout)
            except Exception:
                self.proc.kill()
        self.proc = None

    def kill(self):
        if self.proc and self.proc.poll() is None:
            self.proc.kill()
            self.proc.wait()
        self.proc = None
