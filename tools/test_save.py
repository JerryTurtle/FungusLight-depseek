"""Run persistence cases in the real Godot runtime, using isolated test files."""
from qa_paths import evidence_path
import re
import sys
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
engine = 'C:/Software/Godot_v4.3-stable_win64.exe/Godot_v4.3-stable_win64_console.exe'
result = subprocess.run(
    [engine, '--headless', '--path', str(root / 'game'),
     '--script', 'res://scripts/test_save.gd', '--quit-after', '120'],
    capture_output=True, timeout=30,
)
output = result.stdout.decode(errors='replace') + result.stderr.decode(errors='replace')
(evidence_path(f'{sys.argv[1] if len(sys.argv) > 1 else "G3-001"}-save-tests.log')).write_text(output, encoding='utf-8')
print(output)
assert result.returncode == 0, result.returncode
assert 'SCRIPT ERROR' not in output and 'FAIL ' not in output
errors = [line for line in output.splitlines() if line.startswith('ERROR:')]
assert len(errors) == 1 and 'Could not create directory:' in errors[0] and '/blocked/subdir' in errors[0], errors
assert re.search(r'SAVE_TEST checks=\d+ failures=0', output), 'Missing test summary'
