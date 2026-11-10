"""Headless guard structure only, never a claim of Android or pixel privacy."""
from pathlib import Path
import subprocess
import sys

Path('build').mkdir(exist_ok=True)
for enabled in (False, True):
    command = [sys.argv[1], '--headless', '--path', '.', '--script', 'res://tests/privacy_test_guard_test.gd']
    if enabled:
        command += ['--', '--privacy-guard-test']
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding='utf-8', errors='replace', timeout=120)
    Path('build', 'privacy-guard-' + ('active' if enabled else 'normal') + '.log').write_text(result.stdout, encoding='utf-8')
    print(result.stdout, flush=True)
    required = 'PRIVACY_TEST_GUARD_STRUCTURE_PASS' if enabled else 'PRIVACY_TEST_GUARD_PRODUCTION_PASS'
    if result.returncode or 'SCRIPT ERROR' in result.stdout or 'ERROR:' in result.stdout or required not in result.stdout:
        raise SystemExit('Privacy guard structure check failed')
