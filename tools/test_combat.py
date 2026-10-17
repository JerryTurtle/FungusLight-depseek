"""Fail on Godot script errors as well as assertion failures, with a timeout."""
from qa_paths import evidence_path
import re
import sys
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
engine = 'C:/Software/Godot_v4.3-stable_win64.exe/Godot_v4.3-stable_win64_console.exe'
result = subprocess.run([engine,'--headless','--path',str(root/'game'),'--script','res://scripts/test_combat.gd','--quit-after','300'],capture_output=True,timeout=30)
output = result.stdout.decode(errors='replace')+result.stderr.decode(errors='replace')
(evidence_path(f'{sys.argv[1]}-model-tests.log' if len(sys.argv) > 1 else 'g1-batch-tests.log')).write_text(output,encoding='utf-8')
print(output)
assert result.returncode == 0, result.returncode
assert 'SCRIPT ERROR' not in output and 'FAIL ' not in output
match = re.search(r'checks=(\d+) failures=0',output)
assert match and int(match[1]) >= 549, 'Missing or incomplete test summary'

