"""Summarize measured stress data; never interpret unavailable engine memory as zero use."""
from qa_paths import evidence_path
import json
import statistics
from pathlib import Path

root = Path(__file__).resolve().parents[1]
data = json.loads((evidence_path('G2-007-stress.json')).read_text(encoding='utf-8'))
memory = json.loads((evidence_path('G2-007-stress-os-memory.json')).read_text(encoding='utf-8'))
samples = data['samples']
assert data['elapsed_seconds'] >= 900 and len(samples) >= 170
assert len(memory) >= 170 and all(x['private_bytes'] > 0 for x in memory)
assert all(x['enemies'] == 6 and 0 <= x['projectiles'] <= 20 and x['effects'] <= 64 for x in samples), 'Load was disturbed'
assert statistics.mean(x['projectiles'] for x in samples) >= 18, 'Insufficient projectile load'
result = {k:v for k,v in data.items() if k not in ('samples','frame_ms_histogram')}
result['profiles'] = {}
for quality in ('standard','low'):
    rows = [x for x in samples if x['quality'] == quality]
    assert len(rows) >= 80
    result['profiles'][quality] = {
        'samples':len(rows),
        'average_fps':statistics.mean(x['fps'] for x in rows),
        'minimum_5s_fps':min(x['fps'] for x in rows),
        'maximum_engine_frame_ms':max(x['max_frame_ms'] for x in rows),
        'frames_over_50ms':sum(x['over_50ms'] for x in rows),
    }
for key in ('nodes','objects','effects','enemies','projectiles'):
    result[key+'_range'] = [min(x[key] for x in samples),max(x[key] for x in samples)]
assert result['nodes_range'][0] == result['nodes_range'][1], 'Node count grew'
tail = [x for x in memory if x['elapsed'] >= 600]
for key in ('private_bytes','working_set'):
    result[key] = {
        'peak_mib':max(x[key] for x in memory)/1048576,
        'last5min_min_mib':min(x[key] for x in tail)/1048576,
        'last5min_max_mib':max(x[key] for x in tail)/1048576,
        'last5min_first_mib':tail[0][key]/1048576,
        'last_mib':tail[-1][key]/1048576,
    }
result['memory_samples'] = len(memory)
result['engine_static_memory_available'] = False
(evidence_path('G2-007-stress-summary.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(result,ensure_ascii=False,indent=2))
