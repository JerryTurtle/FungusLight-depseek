"""Run the G6 release-flow checks inside the exported QA build."""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = sys.argv[1] if len(sys.argv) > 1 else "G6-001"
QA = ROOT / "deliverables" / (BUILD + "-QA")
OUT = ROOT / "qa" / "evidence" / "G6" / f"{BUILD}-release-flow.json"


def main() -> int:
    exe = QA / "FungusLight.exe"
    if not exe.exists():
        raise SystemExit(f"missing QA build: {exe}")
    profile = ROOT / "qa" / "runtime-profile" / ("release-flow-" + BUILD)
    profile.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["APPDATA"] = str(profile)
    run = subprocess.run(
        [str(exe), "--headless", "--path", str(QA), "--script", "res://scripts/test_g6_release.gd"],
        cwd=QA, env=env, capture_output=True, timeout=120)
    output = run.stdout.decode(errors="replace") + run.stderr.decode(errors="replace")
    log = OUT.with_suffix(".log")
    log.write_text(output, encoding="utf-8")
    match = re.search(r"G6_RELEASE_TEST checks=(\d+) failures=(\d+)", output)
    checks = int(match.group(1)) if match else None
    failures = int(match.group(2)) if match else None
    report = {
        "build": BUILD,
        "qa_dir": str(QA.relative_to(ROOT)),
        "returncode": run.returncode,
        "checks": checks,
        "failures": failures,
        "script_error_free": "SCRIPT ERROR" not in output,
        "passed": failures == 0 and checks is not None and checks >= 31 and "SCRIPT ERROR" not in output,
    }
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
