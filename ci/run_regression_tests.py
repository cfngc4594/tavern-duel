"""Run focused CPU regressions; this is not Android device verification."""
import subprocess
import sys
from pathlib import Path

godot = sys.argv[1]
tests = sys.argv[2:]
if not tests:
    raise SystemExit("Specify at least one test script")
Path("build").mkdir(exist_ok=True)
for test in tests:
    result = subprocess.run(
        [godot, "--headless", "--path", ".", "--script", "res://tests/" + test],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
        encoding="utf-8", errors="replace", timeout=120,
    )
    Path("build", test + ".log").write_text(result.stdout, encoding="utf-8")
    print(result.stdout, flush=True)
    if result.returncode or "SCRIPT ERROR" in result.stdout or "ERROR:" in result.stdout or "_PASS" not in result.stdout:
        raise SystemExit("Regression failed: " + test)
