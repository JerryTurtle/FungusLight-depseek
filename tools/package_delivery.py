#!/usr/bin/env python3
"""Build the delivery source zip and checksums for ``资料包/``.

The source package is assembled from Git-tracked files so it can be regenerated
from any clean checkout of the same commit. Binary QA screenshots and ignored
local caches are excluded; see ``资料包/03-源码压缩包/源码包说明.md``.

Usage (from the repository root):

    python tools/package_delivery.py
"""
from __future__ import annotations

import hashlib
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PKG = ROOT / "资料包"
GAME_ZIP = PKG / "01-游戏安装包" / "FungusLight-G6-012-Release.zip"
GAME_ZIP_SHA256 = "FCEC62C9CCD11759AF30E8532C72AD26B31D1608BA186390DAC8969D20EB25BF"
SRC_DIR = PKG / "03-源码压缩包"
ZIP_PATH = SRC_DIR / "FungusLight-G6-012-Source.zip"
TOP = "FungusLight-G6-012-Source"
STAMP = (2026, 10, 19, 0, 0, 0)

EXCLUDE_PREFIXES = (
    "deliverables/",
    "资料包/",
    "game/autoload/",
    "qa/local/",
    "qa/runtime-profile/",
    "qa/clean-run/",
    "qa/storage_probe.gd",
)
EXCLUDE_PARTS = {"__pycache__", ".godot", ".git"}
EVIDENCE_TEXT_EXT = {".md", ".json", ".log", ".txt"}

EXTRA_FILES = [
    # (source path relative to repo root, path inside zip)
    ("资料包/03-源码压缩包/源码包说明.md", "README-SOURCE.md"),
    ("资料包/03-源码压缩包/AI交互过程记录/README.md", "AI交互记录/README.md"),
    ("资料包/02-作品说明文档/作品说明.md", "交付文档/作品说明.md"),
    ("资料包/02-作品说明文档/AI工具使用说明.md", "交付文档/AI工具使用说明.md"),
    ("docs/与AI交互内容-汇总.md", "AI交互记录/与AI交互内容-汇总.md"),
    ("docs/与AI交互内容-策划.md", "AI交互记录/与AI交互内容-策划.md"),
    ("docs/与AI交互内容-1.md", "AI交互记录/与AI交互内容-1.md"),
    ("docs/与AI交互内容-2.md", "AI交互记录/与AI交互内容-2.md"),
    ("docs/与AI交互内容-3.md", "AI交互记录/与AI交互内容-3.md"),
    ("docs/history/AI-interaction-log.md", "AI交互记录/AI交互列表-35组.md"),
    ("docs/history/development-through-G3-001.md", "AI交互记录/开发历史-G0到G3-001.md"),
]


def git(*args: str) -> str:
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True).strip()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def tracked_files() -> list[str]:
    raw = subprocess.check_output(["git", "-C", str(ROOT), "ls-files", "-z"])
    return [item.decode("utf-8") for item in raw.split(b"\0") if item]


def included(path: str) -> bool:
    if any(path.startswith(prefix) for prefix in EXCLUDE_PREFIXES):
        return False
    parts = path.split("/")
    if any(part in EXCLUDE_PARTS for part in parts):
        return False
    if path.startswith("qa/evidence/"):
        suffix = Path(path).suffix.lower()
        return suffix in EVIDENCE_TEXT_EXT
    return True


def zip_info(name: str) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name, date_time=STAMP)
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o644 << 16
    return info


def add_bytes(handle: zipfile.ZipFile, name: str, data: bytes) -> None:
    handle.writestr(zip_info(name), data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)


def add_path(handle: zipfile.ZipFile, fs_path: Path, arcname: str) -> None:
    add_bytes(handle, arcname, fs_path.read_bytes())


def build_manifest(entries: list[tuple[str, int]], commit: str, unpacked: int) -> bytes:
    lines = [
        "《菌灯之下》G6-012 源码包清单",
        f"源提交: {commit}",
        f"条目数: {len(entries)}",
        f"解压后总字节: {unpacked}",
        "生成器: tools/package_delivery.py",
        "",
        "说明: 本清单不含 SOURCE-MANIFEST.txt 自身；路径使用 / 分隔。",
        "排除: .git、deliverables、资料包、Fungus Cave 原始全集、game/.godot、",
        "      game/autoload、qa/local、qa/runtime-profile、__pycache__、",
        "      qa/evidence 下的 PNG 截图（发布包 QA/evidence 与 Git 仓库保留）。",
        "",
        "序号\t字节\t路径",
    ]
    for index, (name, size) in enumerate(entries, 1):
        lines.append(f"{index:06d}\t{size}\t{name}")
    return ("\n".join(lines) + "\n").encode("utf-8")


def main() -> int:
    if not GAME_ZIP.is_file():
        print(f"[error] missing game package: {GAME_ZIP}", file=sys.stderr)
        return 1
    game_hash = sha256(GAME_ZIP)
    if game_hash != GAME_ZIP_SHA256:
        print(f"[error] game zip hash mismatch: {game_hash}", file=sys.stderr)
        return 1

    commit = git("rev-parse", "--short", "HEAD")
    source = [path for path in tracked_files() if included(path)]
    extras = [(src, arc) for src, arc in EXTRA_FILES if (ROOT / src).is_file()]
    missing = [src for src, _ in EXTRA_FILES if not (ROOT / src).is_file()]
    if missing:
        print(f"[error] missing extra inputs: {missing}", file=sys.stderr)
        return 1

    SRC_DIR.mkdir(parents=True, exist_ok=True)
    ZIP_PATH.unlink(missing_ok=True)

    entries: list[tuple[str, int]] = []
    with zipfile.ZipFile(ZIP_PATH, "w", allowZip64=True) as handle:
        handle.writestr(zip_info(TOP + "/"), b"")
        for folder in ("AI交互记录/", "交付文档/"):
            handle.writestr(zip_info(f"{TOP}/{folder}"), b"")
        for rel in source:
            fs_path = ROOT / rel
            arcname = f"{TOP}/{rel}"
            data = fs_path.read_bytes()
            add_bytes(handle, arcname, data)
            entries.append((rel, len(data)))
        for src, arc in extras:
            data = (ROOT / src).read_bytes()
            add_bytes(handle, f"{TOP}/{arc}", data)
            entries.append((arc, len(data)))
        unpacked = sum(size for _, size in entries)
        manifest = build_manifest(entries, commit, unpacked)
        add_bytes(handle, f"{TOP}/SOURCE-MANIFEST.txt", manifest)
        entries.append(("SOURCE-MANIFEST.txt", len(manifest)))

    size = ZIP_PATH.stat().st_size
    digest = sha256(ZIP_PATH)
    source_zip_sums = SRC_DIR / "SHA256SUMS.txt"
    source_zip_sums.write_text(f"{digest}  {ZIP_PATH.name}\n", encoding="utf-8")

    # Root checksum list: the two deliverable archives. Markdown documents are
    # tracked by Git and are intentionally not hashed here (editing a document
    # would otherwise invalidate the list).
    checksum_lines = [
        f"{game_hash}  01-游戏安装包/{GAME_ZIP.name}",
        f"{digest}  03-源码压缩包/{ZIP_PATH.name}",
    ]
    (PKG / "SHA256SUMS.txt").write_text("\n".join(checksum_lines) + "\n", encoding="utf-8")

    print(f"source commit : {commit}")
    print(f"entries       : {len(entries)} files, {unpacked:,} bytes unpacked")
    print(f"source zip    : {ZIP_PATH} ({size:,} bytes)")
    print(f"source sha256 : {digest}")
    print(f"game sha256   : {game_hash} (verified)")
    print(f"checksums     : {PKG / 'SHA256SUMS.txt'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
