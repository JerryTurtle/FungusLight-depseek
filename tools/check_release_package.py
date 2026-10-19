"""Audit the release PCK before packaging.

The release preset excludes test/capture/review/MCP resources. This check reads
the exported PCK bytes (Godot stores the file table and resource paths in clear
text) and fails the build if a forbidden resource or development path remains.
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = sys.argv[1] if len(sys.argv) > 1 else "G6-010"
RELEASE = ROOT / "deliverables" / BUILD
QA = ROOT / "deliverables" / (BUILD + "-QA")
OUT = ROOT / "qa" / "evidence" / "G6" / f"{BUILD}-release-package.json"

FORBIDDEN = [
    "scripts/test_", "scripts/route_test", "scripts/capture_", "scripts/stress_",
    "scripts/review", "scripts/enemy_arena", "scripts/integration_test",
    "scripts/replay_driver", "scripts/asset_preview", "scripts/main.gd",
    "scripts/tmp_",
    "scenes/capture_", "scenes/asset_preview", "scenes/main.tscn",
    "data/review_manifest", "autoload/", "McpInteractionServer",
    "用户数据/", "C:/Users/", "res://../qa",
]
REQUIRED = [
    "project.binary", "data/prologue.json", "data/actions.json", "data/enemies.json",
    "scripts/boot.gdc", "scripts/campaign.gdc", "scripts/campaign_state.gdc",
    "scripts/graybox.gdc", "scripts/combat_model.gdc", "scripts/world_art.gdc",
    "scripts/campaign_hud.gdc", "scripts/intro_cinematic.gdc",
    "assets/fonts/FusionPixel12px-zh_hans.ttf", "assets/audio/swing.wav",
    "assets/audio/boss_theme.wav", "assets/hud/icon_melee.png", "assets/intro/scene_01_cavern.png",
    "assets/title/title_bg.png",
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def main() -> int:
    exe = RELEASE / "FungusLight.exe"
    pck = RELEASE / "FungusLight.pck"
    if not exe.exists() or not pck.exists():
        raise SystemExit(f"missing release build: {exe} / {pck}")
    raw = pck.read_bytes()
    missing = [item for item in REQUIRED if item.encode() not in raw]
    forbidden = [item for item in FORBIDDEN if item.encode() in raw]
    project_ok = BUILD.encode() in raw and "菌灯之下".encode() in raw and "开发验证".encode() not in raw
    report = {
        "build": BUILD,
        "release_dir": str(RELEASE.relative_to(ROOT)),
        "exe_sha256": sha256(exe),
        "pck_sha256": sha256(pck),
        "pck_bytes": len(raw),
        "required_present": not missing,
        "missing": missing,
        "forbidden_present": forbidden,
        "project_identity_ok": project_ok,
        "qa_build_exists": (QA / "FungusLight.exe").exists(),
        "passed": not missing and not forbidden and project_ok,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
