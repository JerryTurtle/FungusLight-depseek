from qa_paths import evidence_path
import os
import subprocess
import sys
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
build = sys.argv[1] if len(sys.argv) > 1 else 'G2-007'
output = evidence_path(f'{build}-review')
output.mkdir(exist_ok=True)
env = os.environ.copy()
env['APPDATA'] = str(root / 'qa/runtime-profile')
env['FUNGUS_REVIEW_QA'] = str(output)
result = subprocess.run([str(root/f'deliverables/{build}/FungusLight.exe'),'--','--review-test'],env=env,capture_output=True,timeout=120)
log = result.stdout.decode(errors='replace')+result.stderr.decode(errors='replace')
(output/'runtime.log').write_text(log,encoding='utf-8')
print(log)
assert result.returncode == 0 and 'REVIEW_TEST_DONE' in log
assert 'SCRIPT ERROR' not in log and 'FAIL REVIEW' not in log
report = json.loads((output/'checks.json').read_text(encoding='utf-8'))
assert report['failures'] == 0 and report['checks'] >= 25
