"""Test native viewport input dispatch and retries in a release export."""
from qa_paths import evidence_path
import json
import os
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
build = sys.argv[1] if len(sys.argv) > 1 else 'G1-007'
destination = evidence_path(f'{build}-integration.json')
env = os.environ.copy()
env['APPDATA'] = str(root / 'qa/runtime-profile')
env['FUNGUS_INTEGRATION_OUTPUT'] = str(destination)
result = subprocess.run([str(root / f'deliverables/{build}/FungusLight.exe'), '--', '--integration'], env=env, capture_output=True, timeout=30)
output = result.stdout.decode(errors='replace') + result.stderr.decode(errors='replace')
(evidence_path(f'{build}-integration.log')).write_text(output, encoding='utf-8')
print(output)
assert result.returncode == 0, result.returncode
assert 'SCRIPT ERROR' not in output and 'INTEGRATION_DONE' in output
assert 'instances leaked' not in output and 'resources still in use' not in output
report = json.loads(destination.read_text(encoding='utf-8'))
assert report['checks'] >= 75 and report['failures'] == 0
print('PASS native exported scene integration (not OS keyboard automation).')
