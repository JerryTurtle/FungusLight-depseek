"""Run the exported binary with an isolated writable QA profile.
from qa_paths import evidence_path

The automation host restricts child game executables from writing to normal
Roaming AppData. Confining QA writes to the workspace avoids that limitation;
no ACLs or security settings are changed. Production uses normal AppData.
"""
import os
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
build = sys.argv[1] if len(sys.argv) > 1 else 'G1-001'
profile = root/'qa/runtime-profile'
profile.mkdir(exist_ok=True)
env = os.environ.copy()
env['APPDATA'] = str(profile)
env['FUNGUS_CAPTURE'] = str(evidence_path(f'{build}-window.png'))
extra = sys.argv[2:]
result = subprocess.run([str(root/f'deliverables/{build}/FungusLight.exe'),'--quit-after','120','--','--capture',*extra],cwd=root/f'deliverables/{build}',env=env,capture_output=True,timeout=30)
output = result.stdout.decode(errors='replace') + result.stderr.decode(errors='replace')
(evidence_path(f'{build}-runtime.log')).write_text(f'exit={result.returncode}\nextra_args={extra}\n'+output,encoding='utf-8')
print(output)
assert result.returncode == 0, result.returncode
assert 'READY' in output
assert 'SCRIPT ERROR' not in output
assert (evidence_path(f'{build}-window.png')).exists()
print('PASS: export startup and captured native render; not keyboard or audio acceptance.')
