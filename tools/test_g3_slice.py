"""Run the G3-006 slice checks (campaign, save, enemies, dialogue, props, normal-input route).

Each check runs the real Godot engine headlessly and writes its own evidence log.
This entry point does not replace human review and does not claim OS keyboard input.
"""
import json
import re
import subprocess
import sys
import time
from pathlib import Path
from qa_paths import evidence_path

root = Path(__file__).resolve().parents[1]
engine = 'C:/Software/Godot_v4.3-stable_win64.exe/Godot_v4.3-stable_win64_console.exe'
build = sys.argv[1] if len(sys.argv) > 1 else 'G3-006'

CHECKS = [
    ("campaign", "scripts/test_campaign.gd", r"CAMPAIGN_TEST checks=(\d+) failures=(\d+)", 180),
    ("save", "scripts/test_save.gd", r"SAVE_TEST checks=(\d+) failures=(\d+)", 120),
    ("enemies", "scripts/test_enemies.gd", r"ENEMY_TEST checks=(\d+) failures=(\d+)", 120),
    ("dialogue", "scripts/test_dialogue.gd", r"DIALOGUE_TEST checks=(\d+) failures=(\d+)", 120),
    ("props", "scripts/test_props.gd", r"PROP_TEST checks=(\d+) failures=(\d+)", 180),
    ("route", "scripts/route_test.gd", r"ROUTE_TEST checks=(\d+) failures=(\d+) seconds=([\d.]+)", 300),
]

summary = {"build_id": build, "engine": engine, "checks": [], "failures": 0}
started = time.time()
for name, script, pattern, timeout in CHECKS:
    at = time.time()
    try:
        result = subprocess.run(
            [engine, '--headless', '--path', str(root / 'game'), '--script', 'res://' + script],
            capture_output=True, timeout=timeout)
        output = result.stdout.decode(errors='replace') + result.stderr.decode(errors='replace')
        code = result.returncode
    except subprocess.TimeoutExpired as error:
        output = (error.stdout or b'').decode(errors='replace') + (error.stderr or b'').decode(errors='replace')
        code = 'timeout'
    evidence_path(f'{build}-{name}-tests.log').write_text(output, encoding='utf-8')
    match = re.search(pattern, output)
    passed = code == 0 and match is not None and match.group(2) == '0'
    if match is None:
        summary['failures'] += 1
    else:
        if match.group(2) != '0':
            summary['failures'] += 1
    if code != 0:
        summary['failures'] += 1
    expected = {'campaign': 137, 'save': 65, 'enemies': 35, 'dialogue': 175, 'props': 2059, 'route': 8}[name]
    enough = match is not None and int(match.group(1)) >= expected
    if not enough:
        summary['failures'] += 1
    row = {
        "check": name,
        "script": script,
        "exit": code,
        "checks": int(match.group(1)) if match else None,
        "failures": int(match.group(2)) if match else None,
        "expected_min_checks": expected,
        "seconds": round(time.time() - at, 2),
        "log": f'qa/evidence/G3/{build}-{name}-tests.log',
        "passed": passed and enough,
    }
    if name == 'route' and match:
        row['simulated_seconds'] = float(match.group(3))
    summary['checks'].append(row)
    print(('PASS ' if row['passed'] else 'FAIL ') + name, row['checks'], 'checks, failures', row['failures'])

summary['seconds'] = round(time.time() - started, 2)
summary['passed'] = summary['failures'] == 0 and all(row['passed'] for row in summary['checks'])
evidence_path(f'{build}-checks.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
print('G3_SLICE', 'PASS' if summary['passed'] else 'FAIL', json.dumps(summary['checks'], ensure_ascii=False))
assert summary['passed'], summary
