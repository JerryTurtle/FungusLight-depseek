"""Install the Windows x64 and x86_32 templates from the official archive.

Download the official ``Godot_v4.3-stable_export_templates.tpz`` from the
Godot 4.3 release and place it at ``qa/local/`` first. The archive contains
both architectures; the release package ships a 32-bit build so old 32-bit
Windows machines can launch the game.
"""
from pathlib import Path
import os
import sys
import zipfile

root = Path(__file__).resolve().parents[1]
archive_path = root / 'qa/local/Godot_v4.3-stable_export_templates.tpz'
target = Path(os.environ['APPDATA']) / 'Godot/export_templates/4.3.stable'
if not archive_path.is_file():
    sys.exit(f"missing {archive_path}; download the official Godot 4.3 stable export templates archive first")
target.mkdir(parents=True, exist_ok=True)
names = [
    'windows_debug_x86_64.exe',
    'windows_release_x86_64.exe',
    'windows_debug_x86_32.exe',
    'windows_release_x86_32.exe',
    'version.txt',
]
with zipfile.ZipFile(archive_path) as archive:
    available = set(archive.namelist())
    for name in names:
        member = 'templates/' + name
        if member not in available:
            print('skip (not in archive):', name)
            continue
        data = archive.read(member)
        (target / name).write_bytes(data)
        print(name, len(data))
