"""Run the G4 campaign checks (campaign, save, enemies, dialogue, props, pressure, normal-input route).

Each check runs the real Godot engine headlessly and writes its own evidence log.
This entry point does not replace human review and does not claim OS keyboard input.
"""
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from qa_paths import evidence_path

root = Path(__file__).resolve().parents[1]
engine = 'C:/Software/Godot_v4.3-stable_win64.exe/Godot_v4.3-stable_win64_console.exe'
build = sys.argv[1] if len(sys.argv) > 1 else 'G6-010'

CHECKS = [
    ("campaign", "scripts/test_g4_campaign.gd", r"G4_CAMPAIGN_TEST checks=(\d+) failures=(\d+)", 180),
    ("g6_release", "scripts/test_g6_release.gd", r"G6_RELEASE_TEST checks=(\d+) failures=(\d+)", 120),
    ("g4_state", "scripts/test_g4.gd", r"G4_TEST checks=(\d+) failures=(\d+)", 120),
    ("g4_boss", "scripts/test_g4_boss.gd", r"G4_BOSS_TEST checks=(\d+) failures=(\d+)", 120),
    ("g4_death", "scripts/test_g4_death.gd", r"G4_DEATH_TEST checks=(\d+) failures=(\d+)", 120),
    ("g4_visual", "scripts/test_g4_visual.gd", r"G4_VISUAL_TEST checks=(\d+) failures=(\d+)", 120),
    ("g4_presentation", "scripts/test_g4_presentation.gd", r"G4_PRESENTATION_TEST checks=(\d+) failures=(\d+)", 120),
    ("save", "scripts/test_save.gd", r"SAVE_TEST checks=(\d+) failures=(\d+)", 120),
    ("enemies", "scripts/test_enemies.gd", r"ENEMY_TEST checks=(\d+) failures=(\d+)", 120),
    ("dialogue", "scripts/test_dialogue.gd", r"DIALOGUE_TEST checks=(\d+) failures=(\d+)", 120),
    ("props", "scripts/test_props.gd", r"PROP_TEST checks=(\d+) failures=(\d+)", 180),
    ("pressure", "scripts/test_pressure.gd", r"PRESSURE_TEST checks=(\d+) failures=(\d+)", 180),
    ("route", "scripts/route_test.gd", r"ROUTE_TEST checks=(\d+) failures=(\d+) seconds=([\d.]+)", 480),
    ("skip_route", "scripts/route_test.gd", r"ROUTE_SKIP_TEST checks=(\d+) failures=(\d+) seconds=([\d.]+)", 480, {"FUNGUS_SKIP_DIALOGUE":"1"}),
]

summary = {"build_id": build, "engine": engine, "checks": [], "failures": 0}
started = time.time()
for entry in CHECKS:
    name, script, pattern, timeout = entry[:4]
    extra_env = entry[4] if len(entry) > 4 else {}
    at = time.time()
    try:
        result = subprocess.run(
            [engine, '--headless', '--path', str(root / 'game'), '--script', 'res://' + script],
            capture_output=True, timeout=timeout, env={**os.environ, 'FUNGUS_BUILD_ID': build, **extra_env})
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
    expected = {'campaign': 95, 'g6_release': 39, 'g4_state': 48, 'g4_boss': 71, 'g4_death': 5, 'g4_visual': 15, 'g4_presentation': 48, 'save': 65, 'enemies': 73, 'dialogue': 175, 'props': 2464, 'pressure': 5, 'route': 9, 'skip_route': 9}[name]
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
        "log": f'qa/evidence/{build[:2]}/{build}-{name}-tests.log',
        "passed": passed and enough,
    }
    if name in ('route','skip_route') and match:
        row['simulated_seconds'] = float(match.group(3))
    summary['checks'].append(row)
    print(('PASS ' if row['passed'] else 'FAIL ') + name, row['checks'], 'checks, failures', row['failures'])

summary['seconds'] = round(time.time() - started, 2)
summary['passed'] = summary['failures'] == 0 and all(row['passed'] for row in summary['checks'])
evidence_path(f'{build}-checks.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
print('G3_SLICE', 'PASS' if summary['passed'] else 'FAIL', json.dumps(summary['checks'], ensure_ascii=False))
assert summary['passed'], summary
