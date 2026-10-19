"""Launch the release build from a clean directory with isolated APPDATA.

This is a startup/identity test, not a substitute for the user's first-run
acceptance. It also proves that debug command-line switches are ignored by the
release boot gate.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = sys.argv[1] if len(sys.argv) > 1 else "G6-012"
SOURCE = ROOT / "deliverables" / (BUILD + "-Release") / "Game"
if not (SOURCE / "FungusLight.exe").exists():
    SOURCE = ROOT / "deliverables" / "Release" / "Game"
if not (SOURCE / "FungusLight.exe").exists():
    SOURCE = ROOT / "deliverables" / BUILD
OUT = ROOT / "qa" / "evidence" / "G6" / f"{BUILD}-clean-release.json"


def main() -> int:
    clean = ROOT / "qa" / "local" / f"release-clean-{int(time.time())}" / "有 空格 的 目录"
    if clean.exists():
        shutil.rmtree(clean)
    clean.mkdir(parents=True)
    for name in ("FungusLight.exe", "FungusLight.pck"):
        shutil.copy2(SOURCE / name, clean / name)
    profile = clean / "isolated-appdata"
    profile.mkdir()
    env = os.environ.copy()
    env["APPDATA"] = str(profile)
    env["FUNGUS_CAMPAIGN_CAPTURE"] = str(clean / "must-not-exist")
    run = subprocess.run(
        [str(clean / "FungusLight.exe"), "--headless", "--quit-after", "150", "--",
         "--enemy-arena", "--review-test", "--campaign-capture"],
        cwd=clean, env=env, capture_output=True, timeout=30)
    output = run.stdout.decode(errors="replace") + run.stderr.decode(errors="replace")
    log = OUT.parent / f"{BUILD}-clean-release.log"
    log.write_text(output, encoding="utf-8")
    report = {
        "build": BUILD,
        "clean_directory": str(clean),
        "exit": run.returncode,
        "release_boot": "RELEASE_BOOT campaign" in output,
        "debug_boot_absent": "G2_REVIEW_READY" not in output and "G2_READY" not in output,
        "script_error_free": "SCRIPT ERROR" not in output,
        "no_capture_side_effect": not (clean / "must-not-exist").exists(),
        "no_personal_files_in_game_dir": not any((clean / name).exists() for name in ("用户数据", "debug.log")),
        "isolated_profile_created": profile.exists(),
    }
    report["passed"] = all(value for key, value in report.items()
                           if key in ("release_boot", "debug_boot_absent", "script_error_free",
                                      "no_capture_side_effect", "no_personal_files_in_game_dir")) and run.returncode == 0
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
