"""Validate the five-folder release layout, both architectures and hashes."""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = sys.argv[1] if len(sys.argv) > 1 else "G6-013"
LAYOUT = sys.argv[2] if len(sys.argv) > 2 else "G6-013-Release"
RELEASE = ROOT / "deliverables" / LAYOUT
OUT = ROOT / "qa" / "evidence" / "G6" / f"{BUILD}-release-layout.json"
REQUIRED = {
    "Game/FungusLight.exe": True,
    "Game/FungusLight.pck": True,
    "Game/64/FungusLight.exe": True,
    "Game/64/FungusLight.pck": True,
    "Game/开始游戏.cmd": True,
    "Game/兼容模式启动.cmd": True,
    "Game/系统检查.cmd": True,
    "Game/README.txt": True,
    "Source/game/project.godot": False,
    "Docs/操作说明.md": True,
    "Docs/验收说明.md": True,
    "Docs/已知问题.md": True,
    "Docs/兼容性说明.md": True,
    "QA/SHA256SUMS.txt": True,
    "QA/验收说明.md": True,
    "QA/G6-013-approval.md": True,
    "Licenses/LICENSE": True,
    "Licenses/Godot-MIT.txt": True,
    "Licenses/ASSET-RIGHTS.md": True,
    "Licenses/SOURCES.md": True,
    "Licenses/FusionPixel-OFL.txt": True,
}
HASHED = ("FungusLight.exe", "FungusLight.pck", "64/FungusLight.exe", "64/FungusLight.pck")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def main() -> int:
    missing = [name for name in REQUIRED if not (RELEASE / name).exists()]
    hashes = {}
    sums = RELEASE / "QA/SHA256SUMS.txt"
    if sums.exists():
        for line in sums.read_text(encoding="utf-8").splitlines():
            parts = line.split()
            if len(parts) == 2:
                hashes[parts[1]] = parts[0]
    hash_ok = True
    for name in HASHED:
        path = RELEASE / "Game" / name
        expected = hashes.get(name)
        if not path.exists() or not expected or sha256(path) != expected:
            hash_ok = False
    personal = []
    # Logs inside QA are intentional evidence; saves/settings/logs in the game
    # directory are not.
    for path in (RELEASE / "Game").rglob("*"):
        if not path.is_file():
            continue
        name = path.name
        if (name.endswith(".log") or name in ("auto.json", "manual_1.json", "presentation.cfg")
                or "启动日志" in name or "诊断报告" in name or "compat_report" in name
                or "用户数据" in str(path.relative_to(RELEASE))):
            personal.append(str(path.relative_to(RELEASE)))
    report = {
        "build": BUILD,
        "release": str(RELEASE.relative_to(ROOT)),
        "missing": missing,
        "hashes_ok": hash_ok,
        "hashes_checked": list(HASHED),
        "personal_files": personal,
        "passed": not missing and hash_ok and not personal,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
