"""Route reproducible evidence by stage; keep user profiles outside evidence."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def evidence_path(name: str) -> Path:
    relative = Path(name)
    if relative.is_absolute() or '..' in relative.parts:
        raise ValueError('Evidence name must stay inside its stage directory')
    match = re.match(r'(G[0-6])', name, re.IGNORECASE)
    stage = match.group(1).upper() if match else 'G0'
    destination = ROOT / 'qa' / 'evidence' / stage / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    return destination
