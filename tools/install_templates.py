"""Install only matching Windows x64 binaries from the official archive."""
from pathlib import Path
import os
import zipfile
root = Path(__file__).resolve().parents[1]
target = Path(os.environ['APPDATA'])/'Godot/export_templates/4.3.stable'
target.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(root/'qa/local/Godot_v4.3-stable_export_templates.tpz') as archive:
    for name in ['windows_debug_x86_64.exe','windows_release_x86_64.exe','version.txt']:
        data = archive.read('templates/'+name)
        (target/name).write_bytes(data)
        print(name, len(data))
