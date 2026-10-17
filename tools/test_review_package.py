"""Verify the Chinese-named standalone package from a fresh directory."""
from qa_paths import evidence_path
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

root = Path(__file__).resolve().parents[1]
source = root/'deliverables/G2_Review'
destination = root/f'qa/local/G2-007-clean-{int(time.time())}'
destination.mkdir(parents=True)
for name in ('动作审核.exe','动作审核.pck'):
    shutil.copy2(source/name,destination/name)
exe = destination/'动作审核.exe'
report = {'directory':str(destination),'hashes':{name:hashlib.sha256((source/name).read_bytes()).hexdigest() for name in ('动作审核.exe','动作审核.pck')}}
env = os.environ.copy()
env['APPDATA'] = str(destination/'qa-profile')
env['FUNGUS_REVIEW_QA'] = str(destination)
run = subprocess.run([str(exe),'--','--review-test'],env=env,capture_output=True,timeout=120)
log = run.stdout+run.stderr
(destination/'integration.log').write_bytes(log)
checks = json.loads((destination/'checks.json').read_text(encoding='utf-8'))
assert run.returncode == 0 and checks['checks'] >= 50 and checks['failures'] == 0
report['review_checks'] = checks['checks']

# Normal environment and direct executable launch: no APPDATA redirect.
run = subprocess.run([str(exe),'--quit-after','30'],capture_output=True,timeout=30)
(destination/'normal-launch.log').write_bytes(run.stdout+run.stderr)
assert run.returncode == 0 and b'G2_REVIEW_READY' in run.stdout
portable = destination/'用户数据/reviews/G2-007/review.json'
if portable.exists():
    initial = json.loads(portable.read_text(encoding='utf-8'))
    assert not initial['human_confirmed'] and all(x['status']=='未审核' for x in initial['items'].values())
    # Only our fresh disposable directory is modified, never a real user review.
    initial['current'] = 5
    initial['items']['H01']['note'] = 'QA restart persistence sentinel'
    portable.write_text(json.dumps(initial,ensure_ascii=False,indent=2),encoding='utf-8')
    restart = subprocess.run([str(exe),'--quit-after','30'],capture_output=True,timeout=30)
    (destination/'restart.log').write_bytes(restart.stdout+restart.stderr)
    restored = json.loads(portable.read_text(encoding='utf-8'))
    assert restart.returncode == 0 and restored['current'] == 5 and restored['context']['item'] == 'H06'
    assert restored['items']['H01']['note'] == initial['items']['H01']['note'] and not restored['human_confirmed']
    report['default_environment_persistence'] = 'portable fallback saved and restored; original per-user directories inaccessible on this host'
else:
    report['default_environment_persistence'] = 'normal launch passed; portable fallback not used, per-user persistence not modified by this test'
report['passed'] = True
(evidence_path('G2-007-package-check.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
