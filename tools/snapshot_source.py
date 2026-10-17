"""Archive source and record per-file hashes, excluding regenerated import cache."""
from qa_paths import evidence_path
import hashlib
import json
import sys
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
build = sys.argv[1]
hashes = {}
with zipfile.ZipFile(root/f'deliverables/{build}-source.zip','w',zipfile.ZIP_DEFLATED) as archive:
    paths = list((root/'game').rglob('*'))+list((root/'tools').rglob('*'))
    paths += [root/'qa/gates.json',evidence_path(f'{build}-gate-report.md'),root/'策划输出/菌灯之下_游戏开发策划方案.md']
    for path in sorted(paths):
        if not path.is_file() or '.godot' in path.parts or '__pycache__' in path.parts:
            continue
        name = path.relative_to(root).as_posix()
        archive.write(path,name)
        hashes[name] = hashlib.sha256(path.read_bytes()).hexdigest()
(evidence_path(f'{build}-source-hashes.json')).write_text(json.dumps(hashes,ensure_ascii=False,indent=2),encoding='utf-8')
print(f'Archived {len(hashes)} source files for {build}.')
