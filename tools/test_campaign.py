"""Validate campaign state and native scene wiring without claiming OS route acceptance."""
import os
import subprocess
import sys
from pathlib import Path
from qa_paths import evidence_path

root = Path(__file__).resolve().parents[1]
engine = 'C:/Software/Godot_v4.3-stable_win64.exe/Godot_v4.3-stable_win64_console.exe'
build = sys.argv[1] if len(sys.argv) > 1 else 'G3-002'
result = subprocess.run([engine, '--headless', '--path', str(root/'game'), '--script',
                         'res://scripts/test_campaign.gd', '--quit-after', '300'],
                        capture_output=True, timeout=45)
output = result.stdout.decode(errors='replace')+result.stderr.decode(errors='replace')
evidence_path(f'{build}-campaign-tests.log').write_text(output, encoding='utf-8')
print(output)
assert result.returncode == 0 and 'CAMPAIGN_TEST checks=' in output
assert 'failures=0' in output and 'SCRIPT ERROR' not in output and 'FAIL ' not in output
