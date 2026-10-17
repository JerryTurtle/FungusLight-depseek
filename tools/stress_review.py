from qa_paths import evidence_path
import os
import subprocess
import sys
import ctypes
import json
import time
from ctypes import wintypes
from pathlib import Path

root = Path(__file__).resolve().parents[1]
build = sys.argv[1] if len(sys.argv) > 1 else 'G2-007'
env = os.environ.copy()
env['APPDATA'] = str(root/'qa/runtime-profile')
env['FUNGUS_STRESS_OUTPUT'] = str(evidence_path(f'{build}-stress.json'))
class Counters(ctypes.Structure):
    _fields_ = [('cb',wintypes.DWORD),('PageFaultCount',wintypes.DWORD)]+[(name,ctypes.c_size_t) for name in ['PeakWorkingSetSize','WorkingSetSize','QuotaPeakPagedPoolUsage','QuotaPagedPoolUsage','QuotaPeakNonPagedPoolUsage','QuotaNonPagedPoolUsage','PagefileUsage','PeakPagefileUsage','PrivateUsage']]
memory = []
started = time.monotonic()
process = subprocess.Popen([str(root/f'deliverables/{build}/FungusLight.exe'),'--','--stress'],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
while True:
    counter = Counters()
    counter.cb = ctypes.sizeof(counter)
    if ctypes.windll.psapi.GetProcessMemoryInfo(wintypes.HANDLE(int(process._handle)),ctypes.byref(counter),counter.cb):
        memory.append({'elapsed':time.monotonic()-started,'working_set':counter.WorkingSetSize,'private_bytes':counter.PrivateUsage})
    try:
        stdout,stderr = process.communicate(timeout=5)
        break
    except subprocess.TimeoutExpired:
        if time.monotonic()-started > 960:
            process.kill()
            raise TimeoutError('15-minute stress did not complete')
(evidence_path(f'{build}-stress-os-memory.json')).write_text(json.dumps(memory,indent=2),encoding='utf-8')
log = stdout.decode(errors='replace')+stderr.decode(errors='replace')
(evidence_path(f'{build}-stress.log')).write_text(log,encoding='utf-8')
print(log)
assert process.returncode == 0 and 'STRESS_DONE' in log and 'SCRIPT ERROR' not in log
