"""Launch both release builds from clean directories with isolated APPDATA.

This is a startup/identity test, not a substitute for the user's first-run
acceptance. It proves that the 32-bit and 64-bit builds both boot the release
campaign, report their own architecture, write the compatibility report and
ignore the debug command-line switches.
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
BUILD = sys.argv[1] if len(sys.argv) > 1 else "G6-013"
OUT = ROOT / "qa" / "evidence" / "G6" / f"{BUILD}-clean-release.json"
SOURCES = {
    "x86_64": ROOT / "deliverables" / BUILD,
    "x86_32": ROOT / "deliverables" / (BUILD + "-32"),
}


def run_one(arch: str, source: Path, stamp: int) -> dict:
    if not (source / "FungusLight.exe").exists() or not (source / "FungusLight.pck").exists():
        return {"arch": arch, "source": str(source), "missing_build": True, "passed": False}
    clean = ROOT / "qa" / "local" / f"release-clean-{stamp}" / arch / "链 空 格 的 目录"
    if clean.exists():
        shutil.rmtree(clean)
    clean.mkdir(parents=True)
    for name in ("FungusLight.exe", "FungusLight.pck"):
        shutil.copy2(source / name, clean / name)
    profile = clean / "isolated-profile"
    (profile / "Roaming").mkdir(parents=True)
    (profile / "Local").mkdir(parents=True)
    (profile / "Temp").mkdir(parents=True)
    env = os.environ.copy()
    env["APPDATA"] = str(profile / "Roaming")
    env["LOCALAPPDATA"] = str(profile / "Local")
    env["TEMP"] = str(profile / "Temp")
    env["TMP"] = str(profile / "Temp")
    run = subprocess.run(
        [str(clean / "FungusLight.exe"), "--headless", "--quit-after", "180", "--",
         "--enemy-arena", "--review-test", "--campaign-capture"],
        cwd=clean, env=env, capture_output=True, timeout=45)
    output = run.stdout.decode(errors="replace") + run.stderr.decode(errors="replace")
    log = OUT.parent / f"{BUILD}-clean-release-{arch}.log"
    log.write_text(output, encoding="utf-8")
    report = {
        "arch": arch,
        "clean_directory": str(clean),
        "exit": run.returncode,
        "release_boot": "RELEASE_BOOT campaign" in output,
        "compat_arch": f"COMPAT_ARCH {arch}" in output,
        "compat_report_written": "COMPAT_REPORT" in output,
        "debug_boot_absent": "G2_REVIEW_READY" not in output and "G2_READY" not in output,
        "script_error_free": "SCRIPT ERROR" not in output,
        "isolated_profile_used": not (clean / "用户数据").exists(),
        "isolated_profile_created": (profile / "Roaming" / "FungusLight").exists(),
    }
    report["passed"] = all(value for key, value in report.items()
                           if key in ("release_boot", "compat_arch", "compat_report_written",
                                      "debug_boot_absent", "script_error_free", "isolated_profile_used"))
    return report


def main() -> int:
    stamp = int(time.time())
    reports = {arch: run_one(arch, source, stamp) for arch, source in SOURCES.items()}
    report = {
        "build": BUILD,
        "builds": reports,
        "passed": all(item.get("passed") for item in reports.values()),
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
