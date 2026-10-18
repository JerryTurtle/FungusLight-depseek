"""Sequential native-window replays with fixed 60 Hz physics, comparing every tick."""
from qa_paths import evidence_path
import collections
import json
import os
import statistics
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
build = sys.argv[1] if len(sys.argv)>1 else 'G1-006'
env = os.environ.copy()
env['APPDATA'] = str(root/'qa/runtime-profile')
results = []
baseline = None
for fps in (30,60,144):
    destination = evidence_path(f'{build}-replay-{fps}.json')
    env['FUNGUS_REPLAY_OUTPUT'] = str(destination)
    qa_dir = root / f'deliverables/{build}-QA'
    binary = qa_dir / 'FungusLight.exe' if qa_dir.exists() else root / f'deliverables/{build}/FungusLight.exe'
    run = subprocess.run([str(binary),'--max-fps',str(fps),'--','--replay'],env=env,capture_output=True,timeout=25)
    output = run.stdout.decode(errors='replace')+run.stderr.decode(errors='replace')
    (evidence_path(f'{build}-replay-{fps}.log')).write_text(output,encoding='utf-8')
    assert run.returncode == 0 and 'REPLAY_SAVED 0 frames=360' in output and 'SCRIPT ERROR' not in output, output
    data = json.loads(destination.read_text(encoding='utf-8'))
    assert data['physics_hz'] == 60 and data['requested_fps'] == fps
    trace = data['trace']
    assert len(trace)==360 and trace[-1]['tick']==330
    if baseline is None:
        baseline = trace
    else:
        assert trace == baseline, f'Fixed-tick divergence at {fps} FPS'
    for key in ('tick','player','hp','focus','action','age','cooldowns','actors','projectiles','zones'):
        assert trace[89][key] == trace[119][key], f'Pause advanced {key}'
    events = collections.Counter(e['kind'] for row in trace for e in row['events'])
    assert all(events[k]>0 for k in ('action','hit','release','projectile_spawn','dot')), events
    if 'shield' in trace[0]:
        assert events['shield_absorb'] > 0 and events['rain_impact'] > 0, events
    intervals = data['process_intervals'][10:]
    measured = 1/statistics.mean(intervals)
    results.append(dict(requested_fps=fps,measured_fps=measured,drawn_frames=data['drawn_frames'],elapsed_seconds=data['elapsed_seconds'],events=dict(events),trace_equal=True,pause_frozen=True))
    print(f'{fps} FPS requested / {measured:.2f} measured: 360 replay frames identical',flush=True)
assert results[1]['measured_fps'] > results[0]['measured_fps']*1.5
assert results[2]['measured_fps'] > results[1]['measured_fps']*1.5
(evidence_path(f'{build}-framerate-summary.json')).write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
print('PASS native rendered replay and pause invariance.')
