"""Run the G4 C01-C06 / branch / ending / sidequest / skip route matrix.

Each variant is a real headless normal-input replay (Input.parse_input_event)
with a different branch order, ending, growth configuration, sidequest choice
or dialogue-skip mode. This tool only verifies; it does NOT claim the 60-minute
duration requirement is met.
"""
import json
import os
import re
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE = 'C:/Software/Godot_v4.3-stable_win64.exe/Godot_v4.3-stable_win64_console.exe'
VARIANTS = [
    ('A_restore', {}),
    ('B_seal', {'FUNGUS_BRANCH': 'B', 'FUNGUS_ENDING': 'seal'}),
    ('A_alt_seal', {'FUNGUS_ENDING': 'seal', 'FUNGUS_M1': 'light', 'FUNGUS_M2': 'guard', 'FUNGUS_M3': 'focus', 'FUNGUS_M4': 'step'}),
    ('B_alt_restore', {'FUNGUS_BRANCH': 'B', 'FUNGUS_M1': 'light', 'FUNGUS_M2': 'guard', 'FUNGUS_M3': 'focus', 'FUNGUS_M4': 'step'}),
    ('C05', {}),
    ('C06', {'FUNGUS_BRANCH': 'B', 'FUNGUS_ENDING': 'seal', 'FUNGUS_M1': 'light', 'FUNGUS_M2': 'guard', 'FUNGUS_M3': 'focus', 'FUNGUS_M4': 'step'}),
    ('sidequests', {'FUNGUS_BRANCH': 'B', 'FUNGUS_ENDING': 'seal', 'FUNGUS_SIDEQUEST': '1'}),
    ('skip', {'FUNGUS_SKIP_DIALOGUE': '1'}),
]

summary = {'build_id': 'G4-008', 'variants': [], 'fastest_seconds': None,
           'requirement_seconds': 1200, 'requirement_met': False}
pattern = re.compile(r'ROUTE(?:_SKIP)?_TEST checks=(\d+) failures=(\d+) seconds=([\d.]+)')
started = time.time()
for tag, env_extra in VARIANTS:
    env = {**os.environ, 'FUNGUS_ROUTE_TAG': tag, **env_extra}
    result = subprocess.run(
        [ENGINE, '--headless', '--path', str(ROOT / 'game'), '--script', 'res://scripts/route_test.gd'],
        capture_output=True, timeout=900, env=env)
    output = result.stdout.decode(errors='replace') + result.stderr.decode(errors='replace')
    match = pattern.search(output)
    row = {'tag': tag, 'exit': result.returncode,
           'checks': int(match.group(1)) if match else None,
           'failures': int(match.group(2)) if match else None,
           'seconds': float(match.group(3)) if match else None,
           'passed': result.returncode == 0 and match is not None and match.group(2) == '0'}
    summary['variants'].append(row)
    print(('PASS ' if row['passed'] else 'FAIL ') + tag,
          row['checks'], 'checks', row['seconds'], 'seconds')
    if not row['passed']:
        print(output[-800:])
summary['passed'] = all(v['passed'] for v in summary['variants'])
times = [v['seconds'] for v in summary['variants'] if v['seconds'] is not None]
summary['fastest_seconds'] = min(times) if times else None
summary['requirement_met'] = summary['fastest_seconds'] is not None and summary['fastest_seconds'] >= 1200.0
summary['seconds'] = round(time.time() - started, 2)
out = ROOT / 'qa' / 'evidence' / 'G4' / 'G4-008-route-matrix.json'
out.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
print('ROUTE_MATRIX', json.dumps({k: summary[k] for k in ['passed', 'fastest_seconds', 'requirement_met']}, ensure_ascii=False))
assert summary['passed'], summary
