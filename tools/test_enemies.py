"""Run deterministic campaign enemy mechanics against the actual Godot model."""
import subprocess
import sys
from pathlib import Path
from qa_paths import evidence_path

root = Path(__file__).resolve().parents[1]
engine = 'C:/Software/Godot_v4.3-stable_win64.exe/Godot_v4.3-stable_win64_console.exe'
result = subprocess.run([engine, '--headless', '--path', str(root/'game'), '--script',
                         'res://scripts/test_enemies.gd', '--quit-after', '300'],
                        capture_output=True, timeout=45)
output = result.stdout.decode(errors='replace')+result.stderr.decode(errors='replace')
build = sys.argv[1] if len(sys.argv) > 1 else 'G3-004'
evidence_path(f'{build}-enemy-tests.log').write_text(output, encoding='utf-8')
print(output)
assert result.returncode == 0 and 'ENEMY_TEST checks=' in output
assert 'failures=0' in output and 'SCRIPT ERROR' not in output and 'FAIL ' not in output
