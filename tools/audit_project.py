"""Reproducible, read-only source/data checks and asset provenance manifest."""
from qa_paths import evidence_path
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
game = ROOT / 'game'
records = []
for path in sorted((game / 'assets/original').rglob('*.png')):
    with Image.open(path) as im:
        records.append(dict(path=path.relative_to(game).as_posix(), size=list(im.size), sha256=hashlib.sha256(path.read_bytes()).hexdigest(), source='User-provided Fungus Cave [16x16]', license='Not supplied; pending verification'))
cleric = Image.open(game / 'assets/original/Characters/Cleric.png').convert('RGBA')
assert cleric.size == (48, 128)
frames = []
palette = set()
for row, direction in enumerate(['down', 'left', 'right', 'up']):
    for frame in range(3):
        tile = cleric.crop((frame*16, row*32, frame*16+16, row*32+32))
        frames.append(dict(direction=direction, frame=frame, visible_bounds=tile.getbbox(), foot_anchor=[8,31]))
        palette.update(pixel[:3] for pixel in tile.getdata() if pixel[3])
actions = json.loads((game/'data/actions.json').read_text(encoding='utf-8'))
for key, value in actions['actions'].items():
    for field in ['windup','active','recovery','cost','cooldown']:
        assert isinstance(value[field], int) and value[field] >= 0, (key, field)
assert actions['physics_hz'] == 60
assert sum(actions['actions']['melee'][k] for k in ['windup','active','recovery']) == 22
report = dict(build_id='G0-001',assets=records,cleric_frames=frames,palette=sorted(palette), data_validation='passed', note='Source validation only; does not establish runtime, combat, audio, or human review.')
(evidence_path('asset_manifest.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(f'PASS: {len(records)} original textures; 12 Cleric regions; action schema; manifest saved.')
