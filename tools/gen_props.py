#!/usr/bin/env python3
"""Deterministic pixel-art generator for 《菌灯之下》G3 interactive props.

Outputs
-------
game/assets/props/props_data.json
    Palette + all hand-drawn prop frames (palette-index character rows) +
    tileset furniture crop definitions + ambient particle definitions.
qa/evidence/G3/props/*.png
    Human-review previews (props sheet, furniture sheet, world mock, palette).

Design rules enforced here (and re-checked in scripts/test_props.gd):
  * every colour comes from game/assets/original/Tilesets/Complete.png;
  * 1 px dark outline, no anti-aliasing, no gradients, all binary alpha;
  * <= 16 colours per prop kind (union over all state variants);
  * 3..6 idle frames per variant, integer hold counts.

Run: python tools/gen_props.py
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
TILESET = ROOT / "game/assets/original/Tilesets/Complete.png"
OUT_JSON = ROOT / "game/assets/props/props_data.json"
OUT_DIR = ROOT / "qa/evidence/G3/props"

# ---------------------------------------------------------------------------
# Palette — every entry was sampled from Complete.png (source counts verified
# by `python tools/gen_props.py --audit`).  Chars are the serialisation alphabet.
# ---------------------------------------------------------------------------
PALETTE = {
    # ink / outline
    "k": ("0e0b08", "ink"),
    "K": ("13120c", "ink"),
    "j": ("18130f", "ink"),
    "h": ("231d1a", "ink"),
    "v": ("1b060e", "ink"),
    # metal
    "M": ("242b2b", "metal"),
    "m": ("332e2e", "metal"),
    "n": ("362e2b", "metal"),
    "L": ("4a5152", "metal"),
    "l": ("4f4442", "metal"),
    "q": ("748989", "metal"),
    # cold / water
    "z": ("9ab8bf", "cold"),
    "Z": ("cdf5ff", "cold"),
    # earth browns
    "d": ("411f0f", "brown"),
    "D": ("3e1d0c", "brown"),
    "e": ("4b2818", "brown"),
    "B": ("864b12", "brown"),
    "b": ("965d24", "brown"),
    "c": ("ac7036", "brown"),
    "C": ("c2903c", "brown"),
    "p": ("d0a66a", "brown"),
    "P": ("b7a178", "stone"),
    "Q": ("d7af89", "stone"),
    "w": ("e5c996", "warm"),
    # warm light
    "y": ("cfa545", "warm"),
    "Y": ("ddc161", "warm"),
    "a": ("d7a453", "warm"),
    "A": ("d2ae56", "warm"),
    "F": ("f8ca66", "warm"),
    "W": ("f8f8f8", "warm"),
    # red / violet
    "R": ("94242d", "red"),
    "r": ("b52727", "red"),
    "T": ("c93327", "red"),
    "o": ("ac552f", "red"),
    "O": ("c06f3b", "red"),
    "V": ("614744", "violet"),
    "U": ("36336f", "violet"),
    "u": ("37447c", "violet"),
    # moss / green
    "g": ("2a2a1c", "green"),
    "G": ("424530", "green"),
    "H": ("234333", "green"),
    "I": ("2a5e36", "green"),
    "J": ("30793b", "green"),
    "x": ("091411", "green"),
}
INK = set("kKjhv") | {"d", "D"}


def rgb(ch: str) -> tuple[int, int, int]:
    h = PALETTE[ch][0]
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def rgba(ch: str, alpha: int = 255) -> tuple[int, int, int, int]:
    return rgb(ch) + (alpha,)


# ---------------------------------------------------------------------------
# Minimal pixel grid
# ---------------------------------------------------------------------------
class Grid:
    __slots__ = ("w", "h", "rows")

    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.rows = [["." for _ in range(w)] for _ in range(h)]

    def put(self, x: int, y: int, ch: str) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.rows[y][x] = ch

    def get(self, x: int, y: int) -> str:
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.rows[y][x]
        return "."

    def rect(self, x: int, y: int, w: int, h: int, ch: str, fill: bool = True) -> None:
        if fill:
            for yy in range(y, y + h):
                for xx in range(x, x + w):
                    self.put(xx, yy, ch)
        else:
            for xx in range(x, x + w):
                self.put(xx, y, ch)
                self.put(xx, y + h - 1, ch)
            for yy in range(y, y + h):
                self.put(x, yy, ch)
                self.put(x + w - 1, yy, ch)

    def line(self, x0: int, y0: int, x1: int, y1: int, ch: str) -> None:
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.put(x0, y0, ch)
            if x0 == x1 and y0 == y1:
                return
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, ch: str,
                inner: float = 0.55, outer: float = 1.0) -> None:
        for y in range(self.h):
            for x in range(self.w):
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if inner <= d <= outer:
                    self.put(x, y, ch)

    def dither(self, x: int, y: int, w: int, h: int, ch: str,
               step: int = 2, phase: int = 0, overwrite: bool = True) -> None:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if (xx + yy + phase) % step == 0:
                    if overwrite or self.get(xx, yy) == ".":
                        self.put(xx, yy, ch)

    def paste(self, other: "Grid", ox: int, oy: int) -> None:
        for y in range(other.h):
            for x in range(other.w):
                ch = other.get(x, y)
                if ch != ".":
                    self.put(ox + x, oy + y, ch)

    def copy(self) -> "Grid":
        g = Grid(self.w, self.h)
        g.rows = [row[:] for row in self.rows]
        return g

    def strings(self) -> list[str]:
        return ["".join(row) for row in self.rows]

    def colors(self) -> set[str]:
        return {ch for row in self.rows for ch in row if ch != "."}

    def outline(self, ch: str = "K") -> None:
        """Add an exterior 1 px outline around the current silhouette."""
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if self.get(x, y) != ".":
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if self.get(x + dx, y + dy) not in (".", ch):
                        add.append((x, y))
                        break
        for x, y in add:
            self.put(x, y, ch)


def grid_from_ascii(text: str) -> Grid:
    lines = [ln for ln in text.strip("\n").split("\n")]
    w = max(len(ln) for ln in lines)
    g = Grid(w, len(lines))
    for y, ln in enumerate(lines):
        for x, ch in enumerate(ln):
            if ch != ".":
                g.put(x, y, ch)
    return g


# ---------------------------------------------------------------------------
# Hand-drawn interactive props
# ---------------------------------------------------------------------------
def lamp_base() -> Grid:
    g = Grid(16, 30)
    # hanging ring / cap
    g.put(7, 0, "K")
    g.put(8, 0, "K")
    g.put(7, 1, "K")
    g.put(8, 1, "K")
    g.rect(5, 2, 6, 1, "K")
    g.rect(4, 3, 8, 1, "K")
    g.rect(5, 3, 6, 1, "m")
    g.put(6, 3, "l")
    g.put(9, 3, "l")
    g.rect(3, 4, 10, 1, "K")
    g.rect(4, 4, 8, 1, "l")
    # cage top bar
    g.rect(3, 5, 10, 1, "K")
    g.rect(4, 5, 8, 1, "m")
    # cage sides
    for y in range(6, 12):
        g.put(3, y, "K")
        g.put(12, y, "K")
        g.put(4, y, "m")
        g.put(11, y, "m")
    g.rect(3, 12, 10, 1, "K")
    g.rect(4, 12, 8, 1, "m")
    g.rect(3, 13, 10, 1, "K")
    g.rect(4, 13, 8, 1, "m")
    g.rect(5, 14, 6, 1, "K")
    g.rect(6, 14, 4, 1, "m")
    g.rect(6, 15, 4, 1, "K")
    g.rect(7, 15, 2, 1, "m")
    g.rect(7, 16, 2, 1, "K")
    # pole
    for y in range(17, 25):
        g.put(6, y, "K")
        g.put(7, y, "l")
        g.put(8, y, "K")
    for y in (19, 23):
        g.rect(5, y, 5, 1, "K")
        g.rect(6, y, 3, 1, "m")
    # neck + stone base
    g.rect(5, 25, 6, 1, "K")
    g.rect(6, 25, 4, 1, "m")
    g.rect(4, 26, 8, 1, "K")
    g.rect(5, 26, 6, 1, "m")
    g.rect(3, 27, 10, 1, "K")
    g.rect(4, 27, 8, 1, "m")
    g.rect(5, 27, 6, 1, "l")
    g.rect(2, 28, 12, 1, "K")
    g.rect(3, 28, 10, 1, "M")
    g.rect(4, 28, 8, 1, "m")
    g.rect(1, 29, 14, 1, "K")
    # moss on the plinth
    g.put(3, 27, "G")
    g.put(4, 28, "H")
    g.put(12, 27, "G")
    return g


LAMP_FLAME = {
    0: [(7, 6, "a"), (7, 7, "F"), (8, 7, "Y"), (7, 8, "W"), (8, 8, "F"),
        (7, 9, "F"), (8, 9, "W"), (7, 10, "a"), (8, 10, "F")],
    1: [(7, 6, "F"), (8, 6, "a"), (7, 7, "W"), (8, 7, "F"), (7, 8, "F"),
        (8, 8, "W"), (7, 9, "Y"), (8, 9, "F"), (7, 10, "F"), (8, 10, "a")],
    2: [(8, 6, "a"), (7, 7, "F"), (8, 7, "W"), (7, 8, "W"), (8, 8, "F"),
        (7, 9, "F"), (8, 9, "a"), (7, 10, "a")],
}


def lamp_lit(frame: int) -> Grid:
    g = lamp_base()
    phase = frame // 2
    for y in range(6, 12):
        for x in range(5, 11):
            base = "a" if (x + y + phase) % 2 == 0 else "m"
            if (x + y * 2 + phase) % 5 == 0:
                base = "y"
            g.put(x, y, base)
    for x, y, ch in LAMP_FLAME[frame % 3]:
        g.put(x, y, ch)
    # warm glints on the metal cage + cap
    if frame in (1, 4):
        g.put(6, 3, "Y")
    if frame in (0, 3):
        g.put(9, 5, "Y")
    g.put(4, 5, "Y" if frame % 2 == 0 else "y")
    g.put(11, 12, "Y" if frame % 2 == 1 else "y")
    return g


UNLIT_GLINTS = [(5, 7), (6, 9), (9, 10), (10, 8)]


def lamp_unlit(frame: int) -> Grid:
    g = lamp_base()
    for y in range(6, 12):
        for x in range(5, 11):
            g.put(x, y, "M" if (x + y + frame) % 2 == 0 else "m")
    gx, gy = UNLIT_GLINTS[frame]
    g.put(gx, gy, "L")
    g.put(gx + 1, gy, "l")
    # a stray cold mote drifting past the cage
    g.put(13, 8 + frame, "L")
    # moss drip under the base
    g.put(2 if frame % 2 else 13, 29, "G")
    return g


def chest_base() -> Grid:
    g = Grid(20, 16)
    # silhouette
    g.rect(5, 1, 10, 1, "K")
    g.rect(4, 2, 12, 1, "K")
    g.rect(3, 3, 14, 1, "K")
    for y in (4, 5, 6, 7):
        g.rect(2, y, 16, 1, "K")
    for y in range(8, 13):
        g.rect(2, y, 16, 1, "K")
    g.rect(3, 13, 14, 1, "K")
    g.put(4, 14, "K")
    g.put(5, 14, "K")
    g.put(14, 14, "K")
    g.put(15, 14, "K")
    g.rect(4, 15, 2, 1, "K")
    g.rect(14, 15, 2, 1, "K")
    # lid
    g.rect(5, 2, 10, 1, "D")
    g.rect(4, 3, 12, 1, "b")
    g.rect(3, 4, 14, 1, "b")
    g.rect(3, 5, 14, 1, "B")
    g.rect(3, 6, 14, 1, "D")
    # seam / body
    g.rect(3, 7, 14, 1, "D")
    for y in range(8, 12):
        g.rect(3, y, 14, 1, "B")
    g.rect(3, 12, 14, 1, "D")
    g.rect(4, 13, 12, 1, "B")
    # feet
    g.put(5, 14, "D")
    g.put(14, 14, "D")
    g.put(5, 15, "D")
    g.put(14, 15, "D")
    # iron straps
    for y in range(2, 14):
        for x in (5, 6, 13, 14):
            g.put(x, y, "m" if x in (5, 13) else "M")
    for y in (3, 8, 12):
        g.put(5, y, "l")
        g.put(14, y, "l")
    # brass latch plate with a single keyhole
    g.rect(8, 8, 4, 1, "K")
    g.rect(9, 8, 2, 1, "y")
    g.put(8, 9, "K")
    g.put(9, 9, "Y")
    g.put(10, 9, "y")
    g.put(11, 9, "K")
    g.put(8, 10, "K")
    g.put(9, 10, "K")
    g.put(10, 10, "y")
    g.put(11, 10, "K")
    g.rect(8, 11, 4, 1, "K")
    # lid highlights
    g.put(7, 3, "c")
    g.put(8, 3, "c")
    g.put(9, 4, "c")
    g.put(4, 13, "b")
    return g


CHEST_SEAM = {
    0: [(6, 7, "y"), (12, 7, "y")],
    1: [(6, 7, "a"), (7, 7, "Y"), (12, 7, "y")],
    2: [(6, 7, "y"), (7, 7, "a"), (11, 7, "Y"), (12, 7, "a")],
}


def chest_closed(frame: int) -> Grid:
    g = chest_base()
    for x, y, ch in CHEST_SEAM[frame % 3]:
        g.put(x, y, ch)
    if frame in (2, 5):
        g.put(9, 9, "W")
        g.put(1, 7, "y")
        g.put(18, 7, "a")
    if frame in (1, 4):
        g.put(7, 6, "a")
        g.put(12, 6, "a")
    g.put(13 - (frame % 3), 2, "D")
    return g


def chest_open(frame: int) -> Grid:
    g = Grid(20, 16)
    # opened lid leaning back
    g.rect(5, 0, 10, 1, "K")
    g.rect(4, 1, 12, 1, "K")
    g.rect(5, 1, 10, 1, "b")
    g.rect(3, 2, 14, 1, "K")
    g.rect(4, 2, 12, 1, "D")
    g.rect(2, 3, 16, 1, "K")
    g.rect(3, 3, 14, 1, "k")
    # interior: dark box with a small warm core
    for y in (4, 5, 6, 7):
        g.rect(2, y, 16, 1, "K")
        g.rect(3, y, 14, 1, "k")
    g.rect(3, 4, 14, 1, "D")
    # core glow (1px dither, no smear)
    g.put(9, 5, "W" if frame % 2 == 0 else "F")
    g.put(10, 5, "F")
    g.put(9, 6, "F")
    g.put(10, 6, "Y")
    g.put(8, 6, "a" if frame % 2 == 0 else "y")
    g.put(11, 7, "a")
    g.put(9, 7, "y")
    g.put(12, 5, "y" if frame % 2 == 0 else "a")
    # front rim + body
    g.rect(3, 8, 14, 1, "K")
    for y in range(9, 12):
        g.rect(2, y, 16, 1, "K")
        g.rect(3, y, 14, 1, "B")
    g.rect(3, 9, 14, 1, "b")
    g.rect(3, 12, 14, 1, "K")
    g.rect(4, 12, 12, 1, "B")
    g.put(4, 13, "K")
    g.put(5, 13, "K")
    g.put(14, 13, "K")
    g.put(15, 13, "K")
    g.rect(4, 14, 2, 1, "K")
    g.rect(14, 14, 2, 1, "K")
    # straps + hasp
    for y in range(9, 12):
        for x in (5, 6, 13, 14):
            g.put(x, y, "m" if x in (5, 13) else "M")
    g.put(5, 9, "l")
    g.put(14, 10, "l")
    g.rect(8, 9, 4, 1, "K")
    g.rect(9, 9, 2, 1, "m")
    g.put(9, 10, "K")
    # drifting warm mote
    g.put(15 - frame, 4 + frame % 2, "Y")
    return g


def chest_dim(frame: int) -> Grid:
    g = chest_base()
    # no seam light, cold dither on the lid corners and a dull latch
    for x, y in ((4, 3), (15, 3), (4, 6), (15, 6)):
        g.put(x, y, "M")
    g.put(9, 9, "m")
    g.put(15, 2, "l" if frame % 2 == 0 else "m")
    g.put(4, 5, "l")
    return g


def door_lantern(lit: bool, frame: int = 0, dx: int = 0) -> Grid:
    """8x8 wall lantern body (glass x2..5, rows 2..4); pasted at (6,1)."""
    g = Grid(8, 8)
    # cap + top rim
    g.rect(1, 0, 6, 1, "K")
    g.rect(2, 0, 4, 1, "m")
    g.rect(0, 1, 8, 1, "K")
    g.rect(1, 1, 6, 1, "m")
    g.put(1, 1, "l")
    g.put(6, 1, "l")
    # glass box
    for y in (2, 3, 4):
        g.put(0, y, "K")
        g.put(1, y, "m")
        g.put(6, y, "m")
        g.put(7, y, "K")
        for x in range(2, 6):
            if lit:
                ch = "a" if (x + y + frame) % 2 == 0 else "y"
                if (x * 2 + y + frame) % 5 == 0:
                    ch = "Y"
            else:
                ch = "M" if (x + y + frame) % 2 == 0 else "m"
            g.put(x, y, ch)
    # bottom rim + base
    g.rect(0, 5, 8, 1, "K")
    g.rect(1, 5, 6, 1, "m")
    g.rect(1, 6, 6, 1, "K")
    g.rect(2, 6, 4, 1, "m")
    g.put(3, 6, "l")
    if lit:
        flames = [
            [(3, 2, "F"), (4, 2, "Y"), (3, 3, "W"), (4, 3, "F"), (3, 4, "F"), (4, 4, "Y")],
            [(3, 2, "Y"), (4, 2, "F"), (3, 3, "F"), (4, 3, "W"), (3, 4, "Y"), (4, 4, "F")],
            [(2, 2, "a"), (3, 2, "F"), (4, 3, "W"), (3, 3, "Y"), (3, 4, "F"), (4, 4, "F")],
        ]
        for x, y, ch in flames[frame % 3]:
            g.put(x, y, ch)
    else:
        g.put(2 + frame % 4, 2 + frame % 3, "z")
        g.put(5, 4 - frame % 2, "z")
    return g


def door_frame() -> Grid:
    """Unlit closed door skeleton (lantern drawn separately)."""
    g = Grid(20, 32)
    # chain
    g.put(9, 0, "K")
    g.put(10, 0, "K")
    # lintel
    g.rect(2, 8, 16, 1, "K")
    g.rect(3, 8, 14, 1, "P")
    g.rect(1, 9, 18, 1, "K")
    g.rect(2, 9, 16, 1, "Q")
    g.rect(3, 9, 14, 1, "P")
    g.put(4, 9, "M")
    g.put(10, 9, "M")
    # jambs
    for y in range(10, 27):
        g.put(2, y, "K")
        g.put(3, y, "P")
        g.put(16, y, "P")
        g.put(17, y, "K")
    g.put(3, 10, "Q")
    g.put(16, 10, "Q")
    # top frame + door panel
    g.rect(2, 10, 16, 1, "K")
    g.rect(3, 10, 14, 1, "P")
    for y in range(11, 27):
        g.put(4, y, "K")
        g.put(15, y, "K")
        for x in range(5, 15):
            ch = "B"
            if x in (7, 11):
                ch = "D"
            elif (x * 3 + y) % 11 == 0:
                ch = "b"
            g.put(x, y, ch)
    g.rect(4, 11, 12, 1, "K")
    g.rect(5, 11, 10, 1, "b")
    # iron straps
    for sy in (14, 22):
        g.rect(4, sy, 12, 1, "K")
        g.rect(5, sy, 10, 1, "m")
        g.rect(4, sy + 1, 12, 1, "K")
        g.rect(5, sy + 1, 10, 1, "M")
        for x in (6, 10, 13):
            g.put(x, sy, "l")
    # handle
    g.put(12, 18, "m")
    g.put(13, 18, "m")
    g.put(14, 18, "K")
    g.put(13, 19, "l")
    g.put(12, 19, "K")
    # hinges
    for hy in (14, 22):
        g.put(3, hy, "m")
        g.put(16, hy, "m")
        g.put(3, hy + 1, "l")
    # threshold
    g.rect(1, 27, 18, 1, "K")
    g.rect(1, 28, 18, 1, "P")
    g.rect(2, 28, 10, 1, "Q")
    g.rect(1, 29, 18, 1, "M")
    g.rect(2, 30, 16, 1, "K")
    g.rect(3, 31, 14, 1, "K")
    return g


def _door_paint_bottom(g: Grid, warm: bool, phase: int) -> None:
    if not warm:
        return
    for x in range(4, 16):
        if (x + phase) % 2 == 0:
            g.put(x, 29, "y")
        if (x + phase) % 3 == 0:
            g.put(x, 28, "a")
        if (x + phase) % 4 == 0:
            g.put(x, 30, "Y")
    g.put(9, 31, "y")


def door_sealed(frame: int) -> Grid:
    g = door_frame()
    # lantern unlit, cold glass
    g.paste(door_lantern(False, frame), 6, 1)
    # two nailed boards across the door
    for by in (15, 20):
        g.rect(4, by, 12, 1, "K")
        g.rect(4, by + 1, 12, 1, "b")
        g.rect(4, by + 2, 12, 1, "D")
        g.rect(4, by + 3, 12, 1, "K")
        for bx in (5, 10, 14):
            g.put(bx, by + 1, "l")
    # cold dither on upper panel
    for x in range(5, 15, 2):
        g.put(x, 12, "M")
        g.put(x + 1, 13, "m")
    g.put(9 + frame % 2, 4, "z")
    g.put(6, 12 + frame, "l")
    return g


def door_lit(frame: int) -> Grid:
    g = door_frame()
    sway = [0, -1, 0, 1, 0][frame % 5]
    g.paste(door_lantern(True, frame, sway), 6 + sway, 1)
    # warm rim cast by the lantern
    for x in range(5, 15):
        if (x + frame) % 2 == 0:
            g.put(x, 11, "y")
        if (x + frame) % 3 == 0:
            g.put(x, 10, "a")
    for y in range(12, 16):
        g.put(5, y, "a" if (y + frame) % 2 else "y")
        g.put(14, y, "y" if (y + frame) % 2 else "a")
    for x in range(3, 17):
        if (x + frame) % 3 == 0:
            g.put(x, 8, "y")
    _door_paint_bottom(g, True, frame)
    # warm mote drifting down from the lantern
    g.put(8 + frame % 3, 16 + frame % 4, "Y")
    return g


def door_open(frame: int) -> Grid:
    g = door_frame()
    # doorway interior: clear the panel, keep frame
    for y in range(11, 27):
        for x in range(4, 16):
            g.put(x, y, "k")
        g.put(4, y, "K")
        g.put(15, y, "K")
    # door leaves folded at the jambs
    for y in range(11, 27):
        g.put(3, y, "P")
        g.put(16, y, "P")
        if y % 4 == 0:
            g.put(3, y, "m")
            g.put(16, y, "M")
    # back wall stones, sparse
    for y in (15, 20, 24):
        for x in range(6, 15, 4):
            if (x + y + frame) % 2 == 0:
                g.put(x, y, "M")
    # light shaft falling from the lantern (sparse dither)
    for dy in range(0, 13):
        half = 1 + dy // 5
        for dx in range(-half, half + 1):
            if (dx + dy + frame) % 3 != 0:
                continue
            g.put(9 + dx, 10 + dy, "a" if dy < 6 else "y")
    for dy in range(0, 9, 2):
        g.put(9, 10 + dy, "Y")
    g.put(10, 11, "a")
    # broken chain hanging from the lintel
    for y in range(10, 15):
        g.put(5, y, "l" if y % 2 == 0 else "m")
    # lantern lit + sway
    sway = [0, 1, 0, -1][frame % 4]
    g.paste(door_lantern(True, frame, sway), 6 + sway, 1)
    # interior motes
    g.put(7 + frame % 4, 18 + frame % 5, "Y")
    g.put(13 - frame % 3, 22 + frame % 3, "a")
    _door_paint_bottom(g, True, frame + 1)
    return g


def pipe_base() -> Grid:
    g = Grid(34, 18)
    # cylinder with a readable highlight band
    g.rect(3, 2, 28, 1, "K")
    g.rect(2, 3, 30, 1, "K")
    g.rect(3, 3, 28, 1, "q")
    g.rect(1, 4, 32, 1, "K")
    g.rect(2, 4, 30, 1, "l")
    g.rect(5, 4, 24, 1, "q")
    g.rect(1, 5, 32, 1, "K")
    g.rect(2, 5, 30, 1, "m")
    g.rect(1, 6, 32, 1, "K")
    g.rect(2, 6, 30, 1, "m")
    g.rect(2, 7, 30, 1, "K")
    g.rect(3, 7, 28, 1, "M")
    g.rect(3, 8, 28, 1, "K")
    g.rect(4, 8, 26, 1, "M")
    g.rect(4, 9, 26, 1, "K")
    # flange rings around the pipe
    for bx in (4, 15, 26):
        g.rect(bx, 1, 3, 1, "K")
        g.rect(bx, 9, 3, 1, "K")
        for y in range(2, 9):
            g.put(bx, y, "K")
            g.put(bx + 1, y, "m")
            g.put(bx + 2, y, "K")
        g.put(bx + 1, 5, "l")
    # valve wheel on top (clear of the marks)
    g.put(11, 0, "m")
    g.rect(10, 1, 3, 1, "K")
    g.rect(10, 1, 3, 1, "K")
    g.put(10, 1, "m")
    g.put(11, 1, "l")
    g.put(12, 1, "m")
    g.put(11, 2, "m")
    # moss on top / hanging
    for x, y in ((8, 2), (9, 2), (9, 3), (31, 9), (31, 10)):
        g.put(x, y, "H" if (x + y) % 2 else "G")
    g.put(3, 1, "I")
    # water-level scratches: dark groove, pale top nib, pale tick
    marks = [(19, 4, 6), (21, 4, 7), (23, 5, 8), (25, 6, 8)]
    for mx, y0, y1 in marks:
        for y in range(y0, y1 + 1):
            g.put(mx, y, "K")
        g.put(mx, y0, "Q")
        g.put(mx + 1, y1, "K")
        g.put(mx + 2, y1, "Q")
    # wet puddle: a thin, quiet line
    for x in range(11, 24):
        g.put(x, 15, "L" if x % 3 else "q")
    g.put(10, 15, "K")
    g.put(24, 15, "K")
    g.put(13, 16, "q")
    g.put(18, 16, "q")
    g.put(15, 15, "z")
    return g


DRIP_STAGES = [
    [(17, 10, "Z")],
    [(17, 11, "Z"), (17, 12, "z")],
    [(17, 12, "Z")],
    [(15, 15, "z"), (16, 15, "Z"), (17, 16, "Z"), (18, 15, "z"), (19, 15, "q")],
    [(16, 15, "q"), (18, 15, "z"), (17, 16, "Z")],
    [],
]


def pipe_idle(frame: int) -> Grid:
    g = pipe_base()
    for x, y, ch in DRIP_STAGES[frame % 6]:
        g.put(x, y, ch)
    if frame % 2 == 0:
        g.put(14, 15, "Z")
    if frame % 3 == 1:
        g.put(19, 6, "z")
    return g


def pipe_scanned(frame: int) -> Grid:
    g = pipe_base()
    for x, y, ch in DRIP_STAGES[(frame + 2) % 6]:
        g.put(x, y, ch)
    # highlighted water marks (nib + tick only)
    for mx, y0, y1 in ((19, 4, 6), (21, 4, 7), (23, 5, 8), (25, 6, 8)):
        g.put(mx, y0, "Y" if (mx + frame) % 2 == 0 else "y")
        g.put(mx + 2, y1, "y")
        g.put(mx, y1, "a")
    for x, y in ((18, 4), (20, 7), (22, 8), (26, 6)):
        g.put(x, y, "Z" if (x + frame) % 2 == 0 else "z")
    g.put(14, 15, "Z")
    return g


def ring_base() -> Grid:
    g = Grid(18, 18)
    # stone ring on the floor (thin elliptic band)
    for y in range(18):
        for x in range(18):
            d = ((x - 8.5) / 7.0) ** 2 + ((y - 10.0) / 4.5) ** 2
            if 0.6 <= d <= 1.0:
                if d > 0.93:
                    ch = "K"
                elif y < 9:
                    ch = "Q" if x < 9 else "w"
                elif y > 12:
                    ch = "M"
                else:
                    ch = "P"
                g.put(x, y, ch)
    # outer rune ticks (float just outside the ring)
    for x, y in ((8, 3), (16, 10), (8, 16), (1, 10)):
        g.put(x, y, "Y")
    for x, y in ((8, 4), (14, 10), (8, 15), (2, 10)):
        g.put(x, y, "y")
    # inner pit
    for y in range(8, 13):
        for x in range(5, 13):
            d = ((x - 8.5) / 4.0) ** 2 + ((y - 10.0) / 2.4) ** 2
            if d < 1.0:
                g.put(x, y, "k" if d < 0.5 else "d")
    return g


RING_FLAME = {
    0: [(8, 2, "a"), (8, 3, "Y"), (9, 3, "F"), (8, 4, "F"), (9, 4, "W"),
        (7, 5, "Y"), (8, 5, "W"), (9, 5, "F"), (8, 6, "F"), (9, 6, "Y"),
        (7, 7, "a"), (8, 7, "F"), (9, 7, "a")],
    1: [(8, 2, "F"), (9, 2, "a"), (8, 3, "W"), (9, 3, "F"), (8, 4, "W"),
        (9, 4, "Y"), (8, 5, "F"), (9, 5, "W"), (8, 6, "Y"), (9, 6, "F"),
        (8, 7, "F"), (9, 7, "a")],
    2: [(9, 3, "a"), (8, 3, "Y"), (9, 4, "F"), (8, 4, "W"), (9, 5, "W"),
        (8, 5, "F"), (8, 6, "Y"), (9, 6, "F"), (8, 7, "a"), (9, 7, "Y")],
}


def ring_idle(frame: int) -> Grid:
    g = ring_base()
    for x, y, ch in RING_FLAME[frame % 3]:
        g.put(x, y, ch)
    # soft pit glow
    for x, y in ((5, 9), (12, 9), (6, 11), (11, 11), (8, 9)):
        if (x + frame) % 2 == 0:
            g.put(x, y, "d" if frame % 3 == 0 else "a")
    g.put(7, 7, "y")
    g.put(10, 7, "y")
    return g


def ring_complete(frame: int) -> Grid:
    g = ring_base()
    for x, y, ch in RING_FLAME[frame % 3]:
        g.put(x, y, ch)
    g.put(7, 5, "Y")
    g.put(10, 6, "Y")
    g.put(8, 2, "Y")
    # bright runes + pit glow
    for x, y in ((8, 4), (14, 10), (8, 15), (2, 10)):
        g.put(x, y, "Y")
    for x, y in ((5, 9), (12, 9), (6, 11), (11, 11), (8, 12)):
        g.put(x, y, "a" if (x + frame) % 2 else "y")
    # embers floating up from the ring
    g.put(6, 4 - frame % 2, "Y")
    g.put(11, 3 + frame % 3, "F")
    g.put(5, 8 + frame % 2, "Y")
    g.put(12, 6 + frame % 2, "y")
    return g


def guide_base() -> Grid:
    g = Grid(16, 26)
    # top finial
    g.put(7, 0, "K")
    g.put(8, 0, "K")
    g.rect(6, 1, 4, 1, "K")
    g.rect(7, 1, 2, 1, "m")
    # cap
    g.rect(5, 2, 6, 1, "K")
    g.rect(6, 2, 4, 1, "m")
    g.rect(4, 3, 8, 1, "K")
    g.rect(5, 3, 6, 1, "m")
    g.put(6, 3, "l")
    g.put(9, 3, "l")
    # housing with side arms + crystal aperture
    for y in range(4, 8):
        g.put(3, y, "K")
        g.put(4, y, "l" if y in (5, 6) else "m")
        g.put(5, y, "Q" if y in (5, 6) else "l")
        g.put(10, y, "Q" if y in (5, 6) else "l")
        g.put(11, y, "l" if y in (5, 6) else "m")
        g.put(12, y, "K")
    crystal = {
        (7, 4): "Z", (8, 4): "Z",
        (6, 5): "z", (7, 5): "Z", (8, 5): "Z", (9, 5): "z",
        (6, 6): "Z", (7, 6): "Z", (8, 6): "Z", (9, 6): "Z",
        (7, 7): "z", (8, 7): "z",
    }
    for (x, y), ch in crystal.items():
        g.put(x, y, ch)
    g.rect(4, 8, 8, 1, "K")
    g.rect(5, 8, 6, 1, "m")
    g.rect(5, 9, 6, 1, "K")
    g.rect(6, 9, 4, 1, "m")
    # neck / stem
    g.rect(6, 10, 4, 1, "K")
    for y in range(11, 22):
        g.put(6, y, "K")
        g.put(7, y, "l")
        g.put(8, y, "m")
        g.put(9, y, "K")
    for y in (14, 18):
        g.rect(5, y, 6, 1, "K")
        g.rect(6, y, 4, 1, "m")
    # stone plinth
    g.rect(3, 22, 10, 1, "K")
    g.rect(5, 22, 6, 1, "m")
    g.rect(2, 23, 12, 1, "K")
    g.rect(3, 23, 10, 1, "P")
    g.rect(5, 23, 6, 1, "Q")
    g.rect(1, 24, 14, 1, "K")
    g.rect(2, 24, 12, 1, "M")
    g.rect(3, 24, 5, 1, "P")
    g.rect(1, 25, 14, 1, "K")
    g.put(2, 24, "H")
    g.put(12, 24, "G")
    return g


GUIDE_MARKS = {
    0: [(7, 2), (8, 2)],      # up
    1: [(12, 5), (12, 6)],    # right
    2: [(7, 9), (8, 9)],      # down
    3: [(3, 5), (3, 6)],      # left
}


def guide_variant(direction: int, correct: bool, frame: int) -> Grid:
    g = guide_base()
    coral = "Y" if correct else "q"
    # aperture notches on the emitting side
    for x, y in GUIDE_MARKS[direction]:
        g.put(x, y, coral)
    # crystal pulse
    phase = frame % 3
    if phase == 1:
        g.put(7, 6, "z")
        g.put(8, 5, "q")
        g.put(7, 5, "W")
    elif phase == 2:
        g.put(7, 6, "W")
        g.put(8, 6, "Z")
        g.put(9, 5, "Z")
    if correct:
        for x, y in ((4, 4), (11, 4), (4, 7), (11, 7)):
            g.put(x, y, "y" if (x + y + frame) % 2 else "Y")
        g.put(7, 23, "Y")
        g.put(8, 23, "Y")
        g.put(5, 2, "y")
        g.put(10, 2, "y")
    else:
        for x, y in ((4, 4), (11, 4), (4, 7), (11, 7)):
            g.put(x, y, "q" if (x + y + frame) % 2 else "z")
        g.put(7, 23, "q")
        g.put(5, 2, "q")
        g.put(10, 2, "q")
    # prong glint
    g.put(5, 3, "Y" if correct and frame % 2 == 0 else "l")
    g.put(10, 7, "l")
    return g


def guide_target_base() -> Grid:
    g = Grid(18, 18)
    # broken stone ring
    for y in range(18):
        for x in range(18):
            d = ((x - 8.5) / 7.0) ** 2 + ((y - 10.5) / 4.6) ** 2
            if 0.6 <= d <= 1.0:
                ch = "K" if d > 0.92 else ("Q" if y < 10 else "P")
                g.put(x, y, ch)
    # four outer aim ticks + inner notches
    for x, y in ((8, 1), (16, 10), (8, 17), (1, 10)):
        g.put(x, y, "w")
    for x, y in ((8, 7), (14, 10), (8, 14), (2, 10)):
        g.put(x, y, "w")
    # centre rune
    g.put(8, 10, "w")
    g.put(9, 10, "w")
    g.put(8, 11, "w")
    g.put(9, 11, "w")
    return g


def guide_target_off(frame: int) -> Grid:
    g = guide_target_base()
    for x, y in ((8, 7), (14, 10), (8, 14), (2, 10)):
        g.put(x, y, "z")
    g.put(8, 10, "q")
    g.put(9, 11, "q")
    g.put(8, 11, "z")
    g.put(6 + frame, 9, "z")
    g.put(12, 11 + frame % 2, "q")
    return g


def guide_target_on(frame: int) -> Grid:
    g = guide_target_base()
    for x, y in ((8, 7), (14, 10), (8, 14), (2, 10)):
        g.put(x, y, "Y")
    # warm centre + dither halo
    g.put(8, 10, "W")
    g.put(9, 10, "W")
    g.put(8, 11, "F")
    g.put(9, 11, "Y")
    for x, y in ((6, 9), (11, 9), (7, 12), (10, 12), (8, 13), (7, 8), (10, 8)):
        g.put(x, y, "y" if (x + y + frame) % 2 else "a")
    # rising sparks
    g.put(8, 8 - frame % 2, "Y")
    g.put(3, 8 + frame % 3, "a")
    g.put(15, 12 - frame % 2, "y")
    return g


def mine_door_base() -> Grid:
    g = Grid(22, 34)
    # rock lintel (chunky blocks, no noise dither)
    for y in range(0, 6):
        span = [6, 4, 2, 0, 0, 0][y]
        g.rect(span, y, 22 - span * 2, 1, "K")
    for y in range(3, 6):
        for x in range(1, 21):
            g.put(x, y, "m" if (x + y) % 7 == 0 else "M")
    for x, y in ((4, 3), (5, 3), (12, 4), (13, 4), (17, 3), (2, 5), (19, 5), (8, 5)):
        g.put(x, y, "K")
    g.put(3, 4, "m")
    g.put(18, 4, "m")
    # rock jambs framing the doorway
    for y in range(6, 34):
        g.put(0, y, "K")
        g.put(1, y, "m" if y % 4 == 0 else "M")
        g.put(2, y, "K")
        g.put(19, y, "K")
        g.put(20, y, "M" if y % 4 == 2 else "m")
        g.put(21, y, "K")
    # lamp housing recess in the lintel
    g.rect(8, 2, 6, 1, "K")
    for y in range(3, 7):
        g.put(8, y, "K")
        g.put(9, y, "m")
        g.put(12, y, "m")
        g.put(13, y, "K")
    g.rect(8, 7, 6, 1, "K")
    g.rect(9, 7, 4, 1, "m")
    # iron lintel beam
    g.rect(0, 8, 22, 1, "K")
    g.rect(1, 9, 20, 1, "m")
    for x in (3, 8, 13, 18):
        g.put(x, 9, "l")
    g.rect(0, 10, 22, 1, "K")
    # door leaves
    for y in range(11, 31):
        g.put(3, y, "K")
        g.put(18, y, "K")
        for x in range(4, 18):
            ch = "B"
            if x == 10:
                ch = "K"
            elif x == 11:
                ch = "D"
            elif x in (5, 8, 13, 16) and (y % 9) != 0:
                ch = "D"
            elif (x * 3 + y) % 13 == 0:
                ch = "B"
            g.put(x, y, ch)
    g.rect(4, 11, 14, 1, "K")
    g.rect(4, 12, 14, 1, "B")
    # iron straps
    for sy in (15, 23, 30):
        g.rect(3, sy, 16, 1, "K")
        g.rect(4, sy, 14, 1, "m")
        g.rect(3, sy + 1, 16, 1, "K")
        for x in (5, 9, 14, 17):
            g.put(x, sy, "l")
    # faded warning glyph
    for x, y in ((5, 19), (6, 20), (4, 20), (7, 21), (5, 21), (6, 21), (3, 21)):
        g.put(x, y, "R")
    for x, y in ((4, 25), (6, 25), (8, 25)):
        g.put(x, y, "R")
    # threshold stones
    g.rect(1, 31, 20, 1, "K")
    g.rect(2, 32, 18, 1, "P")
    g.rect(2, 33, 18, 1, "K")
    g.put(3, 32, "Q")
    g.put(17, 32, "P")
    return g


def mine_lamp(g: Grid, lit: bool, frame: int) -> None:
    if lit:
        flame = [
            [(10, 3, "F"), (11, 3, "Y"), (10, 4, "W"), (11, 4, "F"), (10, 5, "F"), (11, 5, "Y"), (10, 6, "a")],
            [(10, 3, "Y"), (11, 3, "F"), (10, 4, "F"), (11, 4, "W"), (10, 5, "Y"), (11, 5, "F"), (11, 6, "a")],
            [(10, 4, "F"), (11, 4, "Y"), (10, 5, "W"), (11, 5, "F"), (10, 6, "Y"), (10, 3, "a")],
        ]
        for x, y, ch in flame[frame % 3]:
            g.put(x, y, ch)
        g.put(9, 4, "y")
        g.put(12, 5, "Y")
        # warm spill on the iron beam below
        for x in range(8, 14):
            if (x + frame) % 2 == 0:
                g.put(x, 8, "y")
        g.put(11, 8, "Y")
    else:
        g.put(10, 4, "M")
        g.put(11, 5, "m")
        g.put(10 + frame % 2, 3 + frame % 3, "z" if frame % 2 else "Z")
        g.put(12, 6, "M")


def mine_door_sealed(frame: int) -> Grid:
    g = mine_door_base()
    mine_lamp(g, False, frame)
    # crossing chains
    for i in range(0, 20):
        x = 4 + i
        y = 12 + i
        if y < 30:
            g.put(x, y, "l" if i % 2 == 0 else "m")
            if i % 3 == 0:
                g.put(x + 1, y, "m")
        y2 = 30 - i
        if y2 > 11:
            g.put(x, y2, "m" if i % 2 else "l")
    # lock plate
    g.rect(9, 19, 4, 1, "K")
    g.rect(9, 20, 4, 1, "m")
    g.put(10, 20, "l")
    g.put(10, 21, "K")
    g.put(11, 21, "K")
    g.rect(9, 22, 4, 1, "K")
    # cold glints
    for x, y in ((4, 12), (17, 12), (10, 17)):
        g.put(x, y, "z" if (x + frame) % 2 else "Z")
    g.put(7, (frame * 3) % 16 + 12, "z")
    return g


def mine_door_scan(frame: int) -> Grid:
    g = mine_door_sealed(frame)
    for x, y in ((5, 16), (16, 16), (10, 27)):
        g.put(x, y, "Z" if (x + frame) % 2 else "z")
    for x in range(4, 18):
        if (x + frame) % 3 == 0:
            g.put(x, 18, "z")
    g.put(10, 8, "z")
    return g


def mine_door_lit(frame: int) -> Grid:
    g = mine_door_base()
    mine_lamp(g, True, frame)
    # broken chains hanging at the sides
    for i in range(0, 7):
        g.put(2, 12 + i, "l" if i % 2 else "m")
        g.put(19, 21 + i, "m" if i % 2 else "l")
    # seam light between the leaves: one quiet line
    for y in range(11, 31):
        if (y + frame) % 2 == 0:
            g.put(10, y, "y")
        elif (y + frame) % 4 == 0:
            g.put(10, y, "a")
    for x in range(4, 18, 3):
        g.put(x, 12, "y")
    for x in range(4, 19):
        if (x + frame) % 2 == 0:
            g.put(x, 32, "y")
        if (x + frame) % 3 == 0:
            g.put(x, 32, "a")
    g.put(9 + frame % 3, 32, "Y")
    g.put(10, 12, "Y")
    return g


def mine_door_open(frame: int) -> Grid:
    g = mine_door_base()
    mine_lamp(g, True, frame)
    # two leaves swung back: clean planks, dark gap in the middle
    for y in range(11, 31):
        for x in range(4, 10):
            ch = "B"
            if x == 6:
                ch = "D"
            if x in (4, 9):
                ch = "K"
            g.put(x, y, ch)
        for x in range(12, 18):
            ch = "B"
            if x == 15:
                ch = "D"
            if x in (12, 17):
                ch = "K"
            g.put(x, y, ch)
        g.put(10, y, "K")
        g.put(11, y, "K")
    # leaf straps
    for sy in (15, 23, 30):
        for x in list(range(4, 8)) + list(range(14, 18)):
            g.put(x, sy, "m" if x % 2 else "M")
    # warm light inside the gap (sparse, not a pillar)
    for y in range(11, 22):
        if (y + frame) % 2 == 0:
            g.put(10, y, "a")
        if (y + frame) % 3 == 0:
            g.put(11, y, "y")
    g.put(10, 11, "Y")
    g.put(11, 13, "a")
    # light catches the leaf edges
    for y in range(12, 31):
        if (y + frame) % 3 == 0:
            g.put(9, y, "y")
            g.put(12, y, "y")
    # floating dust in the shaft
    g.put(6 + frame % 4, 23 + frame % 4, "Y")
    g.put(16 - frame % 3, 27 + frame % 2, "y")
    # threshold spill
    for x in range(4, 19):
        if (x + frame) % 2 == 0:
            g.put(x, 32, "y")
        if (x + frame) % 3 == 0:
            g.put(x, 32, "a")
    g.put(10, 32, "Y")
    g.put(11, 33, "y")
    return g


def portal_opening(x: int, y: int) -> bool:
    dx = (x - 13.5) / 8.0
    dy = (y - 20.0) / 14.0
    return dx * dx + dy * dy <= 1.0


def portal_base() -> Grid:
    # Stone gate: chunky arch matching the cave brick walls, not a wooden door.
    g = Grid(28, 38)
    for y in range(1, 37):
        left = 4 if y < 4 else (3 if y < 6 else (2 if y < 8 else 1))
        right = 23 if y < 4 else (24 if y < 6 else (25 if y < 8 else 26))
        for x in range(left, right + 1):
            g.put(x, y, "B")
    for y in range(1, 37):
        for x in range(1, 27):
            if g.get(x, y) != "B":
                continue
            if y % 4 == 0:
                g.put(x, y, "D")
            elif x % 4 == 0 and (y // 4) % 2 == 0:
                g.put(x, y, "b")
            elif (x // 4 + y // 3) % 5 == 0:
                g.put(x, y, "P")
    # keystone and lintel highlights
    g.rect(5, 1, 18, 1, "P")
    g.rect(11, 1, 6, 4, "P")
    g.rect(12, 2, 4, 2, "Q")
    g.put(13, 3, "Y")
    g.put(14, 3, "y")
    # carved opening
    for y in range(2, 36):
        for x in range(2, 26):
            if portal_opening(x, y):
                g.put(x, y, ".")
    # outline the opening against the stone
    for y in range(2, 36):
        for x in range(2, 26):
            if not portal_opening(x, y):
                continue
            for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if not portal_opening(x + ox, y + oy):
                    g.put(x + ox, y + oy, "K")
    # runes on both jambs
    for y in (13, 20, 27):
        g.put(3, y, "y")
        g.put(24, y, "y")
        g.put(4, y, "Y")
        g.put(23, y, "Y")
    # threshold + moss
    g.rect(1, 35, 26, 2, "K")
    g.rect(2, 35, 24, 1, "P")
    g.put(3, 35, "Q")
    g.put(24, 35, "Q")
    for x, y in ((2, 33), (3, 34), (25, 33), (24, 34), (4, 34), (23, 34)):
        g.put(x, y, "G" if (x + y) % 2 else "g")
    return g


def portal_sealed(frame: int) -> Grid:
    g = portal_base()
    for y in range(2, 35):
        for x in range(2, 26):
            if not portal_opening(x, y):
                continue
            g.put(x, y, "h" if y < 28 else "H")
    # faint cold glints behind the sealed surface
    for i in range(3):
        x = 8 + (i * 5 + frame * 2) % 10
        y = 9 + (i * 7 + frame * 3) % 18
        if portal_opening(x, y):
            g.put(x, y, "z" if i % 2 else "Z")
    g.put(13, 21, "z")
    return g


def portal_open(frame: int) -> Grid:
    g = portal_base()
    for y in range(2, 35):
        for x in range(2, 26):
            if not portal_opening(x, y):
                continue
            dx = (x - 13.5) / 8.0
            dy = (y - 20.0) / 14.0
            d = dx * dx + dy * dy
            if d < 0.06:
                ch = "F"
            elif d < 0.18:
                ch = "Y"
            elif d < 0.36:
                ch = "y"
            elif d < 0.55:
                ch = "G"
            elif d < 0.78:
                ch = "H"
            else:
                ch = "h"
            if (x + y * 2 + frame) % 11 == 0:
                ch = "F" if ch in ("Y", "y") else ch
            g.put(x, y, ch)
    # slow drifting highlights in the light curtain
    for i in range(3):
        x = 8 + (i * 5 + frame * 2) % 10
        y = 10 + (i * 6 + frame * 3) % 18
        if portal_opening(x, y):
            g.put(x, y, "W")
    g.put(3, 13, "Y")
    g.put(3, 20, "W")
    g.put(3, 27, "Y")
    g.put(24, 13, "Y")
    g.put(24, 20, "W")
    g.put(24, 27, "Y")
    # light spill on the threshold
    for x in range(4, 24):
        if (x + frame) % 2 == 0:
            g.put(x, 34, "y")
        if (x + frame) % 3 == 0:
            g.put(x, 34, "Y")
    g.put(13, 34, "F")
    g.put(14, 34, "F")
    return g


def rail_base() -> Grid:
    g = Grid(34, 10)
    sleepers = (2, 10, 18, 26)
    # sleepers under the rails
    for sx in sleepers:
        for x in (sx, sx + 1):
            g.put(x, 0, "K")
            g.put(x, 1, "b")
            g.put(x, 2, "D")
            g.put(x, 3, "D")
            g.put(x, 4, "b")
            g.put(x, 5, "D")
            g.put(x, 6, "D")
            g.put(x, 7, "b")
            g.put(x, 8, "K")
        g.put(sx, 1, "b")
        g.put(sx + 1, 1, "D")
    # far rail
    g.rect(1, 2, 32, 1, "K")
    g.rect(1, 3, 32, 1, "q")
    g.rect(1, 2, 2, 1, "K")
    g.rect(31, 2, 2, 1, "K")
    for sx in sleepers:
        g.put(sx, 3, "l")
    # near rail
    g.rect(1, 5, 32, 1, "K")
    g.rect(1, 6, 32, 1, "q")
    g.rect(1, 5, 2, 1, "K")
    g.rect(31, 5, 2, 1, "K")
    for sx in sleepers:
        g.put(sx + 1, 6, "l")
    # gravel + moss
    for x, y in ((5, 4), (14, 4), (23, 4), (29, 4), (6, 7), (15, 7), (24, 7)):
        g.put(x, y, "P")
    g.put(1, 4, "G")
    g.put(33, 7, "H")
    g.put(9, 8, "G")
    # shadow
    g.dither(2, 8, 32, 2, "k", step=2)
    return g


def rail_idle(frame: int) -> Grid:
    g = rail_base()
    gx = [4, 12, 20, 28][frame % 4]
    g.put(gx, 3, "z")
    g.put(gx + 1, 3, "q")
    g.put(32 - gx % 22, 6, "z")
    g.put(6 + frame * 5 % 26, 1, "l")
    if frame % 2 == 0:
        g.put(17, 4, "q")
    return g


def rubble_base() -> Grid:
    g = Grid(16, 10)
    stones = [
        [(2, 4), (3, 3), (4, 3), (5, 4), (6, 4), (7, 5), (3, 5), (4, 5), (5, 5), (6, 5), (4, 6), (5, 6), (6, 6)],
        [(6, 2), (7, 2), (8, 3), (9, 3), (10, 4), (7, 4), (8, 4), (9, 4), (10, 5), (8, 5), (9, 5), (8, 6)],
        [(10, 5), (11, 5), (12, 6), (13, 6), (11, 6), (12, 7), (13, 7), (14, 7), (11, 7), (12, 8)],
        [(2, 2), (3, 2), (3, 3)],
    ]
    shades = ["M", "P", "Q", "P"]
    for idx, stone in enumerate(stones):
        base = shades[idx % len(shades)]
        for x, y in stone:
            g.put(x, y, base)
    # crevices between stones
    for x, y in ((5, 4), (6, 5), (9, 4), (10, 5), (3, 6), (11, 6)):
        if g.get(x, y) != ".":
            g.put(x, y, "K")
    # shading + moss
    for x, y in ((4, 6), (6, 6), (8, 6), (9, 6), (12, 8), (13, 8)):
        g.put(x, y, "m")
    for x, y in ((2, 4), (6, 2), (8, 3), (10, 5)):
        g.put(x, y, "Q")
    for x, y in ((3, 3), (7, 2), (12, 6)):
        g.put(x, y, "H" if (x + y) % 2 else "G")
    g.outline("K")
    return g


def rubble_idle(frame: int) -> Grid:
    g = rubble_base()
    if frame % 3 == 0:
        g.put(12, 3, "Z")
        g.put(11, 4, "z")
    elif frame % 3 == 1:
        g.put(12, 3, "z")
        g.put(13, 2, "Z")
    else:
        g.put(12, 3, "q")
    g.put(2 + frame * 3 % 12, 1 + frame % 2, "P")
    return g


def barrel_base() -> Grid:
    g = Grid(14, 18)
    # top rim
    g.rect(3, 0, 8, 1, "K")
    g.rect(2, 1, 10, 1, "K")
    g.rect(3, 1, 8, 1, "b")
    # body
    for y in range(2, 15):
        g.put(1, y, "K")
        g.put(12, y, "K")
        for x in range(2, 12):
            ch = "B" if (x + y) % 3 else "b"
            g.put(x, y, ch)
    for x in range(2, 12):
        g.put(x, 2, "b")
        g.put(x, 14, "D")
    # metal bands
    for by in (5, 11):
        g.rect(1, by, 12, 1, "K")
        g.rect(2, by, 10, 1, "m")
        g.rect(1, by + 1, 12, 1, "K")
        g.rect(2, by + 1, 10, 1, "M")
        g.put(4, by, "l")
        g.put(9, by + 1, "l")
    # stave lines
    for x in (4, 7, 10):
        for y in range(2, 15):
            if y not in (5, 6, 11, 12):
                g.put(x, y, "D" if (x + y) % 2 else "c")
    # base
    g.rect(2, 15, 10, 1, "K")
    g.rect(3, 15, 8, 1, "D")
    g.rect(3, 16, 8, 1, "K")
    g.put(4, 17, "K")
    g.put(9, 17, "K")
    return g


def barrel_idle(frame: int) -> Grid:
    g = barrel_base()
    g.put(4, 5, "q" if frame % 2 else "l")
    g.put(9, 11, "q" if frame % 3 else "l")
    g.put(11, 2 + frame % 4, "c")
    g.put(3 + frame * 2 % 9, 4, "C")
    return g


# kind -> (size, anchor, label_anchor, ground, variants {name: (frames fn, hold, flash_frames)})
def build_props() -> dict:
    variants = {
        "lamp": {
            "size": (16, 30), "anchor": (-8, -26), "label": (0, -31), "ground": 26,
            "variants": {
                "lit": ([lamp_lit(f) for f in range(6)], 7, []),
                "unlit": ([lamp_unlit(f) for f in range(4)], 10, []),
            },
        },
        "chest": {
            "size": (20, 16), "anchor": (-10, -14), "label": (0, -19), "ground": 13,
            "variants": {
                "closed": ([chest_closed(f) for f in range(6)], 8, []),
                "open": ([chest_open(f) for f in range(3)], 12, []),
                "dim": ([chest_dim(f) for f in range(3)], 16, []),
            },
        },
        "door": {
            "size": (20, 32), "anchor": (-10, -29), "label": (0, -34), "ground": 29,
            "variants": {
                "sealed": ([door_sealed(f) for f in range(4)], 12, []),
                "lit": ([door_lit(f) for f in range(5)], 7, []),
                "open": ([door_open(f) for f in range(4)], 9, []),
            },
        },
        "pipe": {
            "size": (34, 18), "anchor": (-17, -11), "label": (0, -16), "ground": 11,
            "variants": {
                "idle": ([pipe_idle(f) for f in range(6)], 8, []),
                "scanned": ([pipe_scanned(f) for f in range(5)], 9, []),
            },
        },
        "ring": {
            "size": (18, 18), "anchor": (-9, -13), "label": (0, -18), "ground": 13,
            "variants": {
                "idle": ([ring_idle(f) for f in range(6)], 9, []),
                "complete": ([ring_complete(f) for f in range(5)], 6, [2, 3]),
            },
        },
        "guide": {
            "size": (16, 26), "anchor": (-8, -23), "label": (0, -28), "ground": 23,
            "variants": {},
        },
        "guide_target": {
            "size": (18, 18), "anchor": (-9, -12), "label": (0, -17), "ground": 12,
            "variants": {
                "on": ([guide_target_on(f) for f in range(4)], 6, [1]),
                "off": ([guide_target_off(f) for f in range(4)], 10, []),
            },
        },
        "mine_door": {
            "size": (22, 34), "anchor": (-11, -31), "label": (0, -36), "ground": 31,
            "variants": {
                "sealed": ([mine_door_sealed(f) for f in range(5)], 11, []),
                "sealed_scan": ([mine_door_scan(f) for f in range(5)], 8, []),
                "lit": ([mine_door_lit(f) for f in range(5)], 7, []),
                "open": ([mine_door_open(f) for f in range(5)], 8, []),
            },
        },
        "portal": {
            "size": (28, 38), "anchor": (-14, -36), "label": (0, -42), "ground": 36,
            "variants": {
                "sealed": ([portal_sealed(f) for f in range(3)], 16, []),
                "open": ([portal_open(f) for f in range(5)], 14, []),
            },
        },
        "rail": {
            "size": (34, 10), "anchor": (-17, -4), "label": (0, -9), "ground": 4,
            "variants": {"idle": ([rail_idle(f) for f in range(4)], 12, [])},
        },
        "rubble": {
            "size": (16, 10), "anchor": (-8, -7), "label": (0, -12), "ground": 7,
            "variants": {"idle": ([rubble_idle(f) for f in range(4)], 10, [])},
        },
        "barrel": {
            "size": (14, 18), "anchor": (-7, -16), "label": (0, -21), "ground": 15,
            "variants": {"idle": ([barrel_idle(f) for f in range(4)], 10, [])},
        },
    }
    for direction in range(4):
        for correct, tag in ((True, "c"), (False, "w")):
            name = f"d{direction}{tag}"
            variants["guide"]["variants"][name] = (
                [guide_variant(direction, correct, f) for f in range(5)],
                6,
                [2] if correct else [],
            )
    return variants


PROP_PALETTES = {
    "lamp": set("K,mMlLayYFWPQGH"),
    "chest": set("KkMmlDBbcYyaFW"),
    "door": set("KkmMlDBbcPQyYFWz"),
    "pipe": set("KkmMlLqZzHIGP"),
    "ring": set("KkmMlPQwyYaFWGH"),
    "guide": set("KkmMlqzZyYFWP GH".replace(" ", "")),
    "guide_target": set("KkmPQwzZyYFWG"),
    "mine_door": set("KkMmlPQDBRzZyYFW"),
    "portal": set("KBDbPQGgHhzZyYFW"),
    "rail": set("KkMmlDBbPGH"),
    "rubble": set("KkmMlPQGHZz"),
    "barrel": set("KkMmlDBbcq"),
}

PROP_STATE_NOTES = {
    "lamp": "lit:false=熄灭（冷玻璃/灰烬） lit:true=点燃（火焰+暖玻璃）；near 由运行时画四角高亮",
    "chest": "open:false=闭合（缝光呼吸） open:true=开箱（箱内暖光） available:false=暗态（不发光，仍可读）",
    "door": "open:true=打开（暖光从门内溢出） open:false & available:true=带灯门（灯摆动） available:false=封板冷门",
    "pipe": "scanned:true=水位刻痕被高亮（Q 观察后）；drip 动画持续",
    "ring": "complete:true=初燃完成（更大火焰+浮尘） complete:false=待点燃（弱余烬）",
    "guide": "dir:0下/1左/2右/3上（world_art.row 约定）；correct:true=暖金束，false=冷灰束；available:false 不画光束",
    "guide_target": "correct:true=暖金目标亮起；false=冷色待机",
    "mine_door": "open:true=打开；available:false=锁链封闭；scanned:true=扫描标记（仅 sealed 时）",
    "portal": "open:true=灯路接通（暖光帘）；false=封印（冷暗内芯 + 符文）；门框为石拱，不使用木门",
    "rail": "静态矿道装饰，仅 1px 锈光/尘埃",
    "rubble": "静态矿道装饰，菌光呼吸",
    "barrel": "静态矿道装饰（自绘，图集给定位置无独立木桶）",
}

# ---------------------------------------------------------------------------
# Furniture: direct crops from Complete.png + animated overlay effects
# ---------------------------------------------------------------------------
def build_furniture() -> dict:
    # (rect, offset) offsets are relative to the ground anchor pos
    return {
        "bed": {
            "label_anchor": [0, -47], "near_rect": [-16, -45, 32, 46],
            "layers": [{"rect": [9, 339, 31, 45], "offset": [-15, -44]}],
            "fx": {
                "motes": [{"origin": [0, -32], "count": 3, "colors": ["y", "Y", "a"],
                           "spread": [10, 8], "rise": 12, "hold": 9}],
                "sparkle": [{"points": [[-13, -24], [8, -24]], "colors": ["Y", "W"], "hold": 16}],
            },
            "state_notes": "床铺/存档点：暖色浮尘 + 红柱反光；不会与图集床体冲突",
        },
        "chest_closed": {
            "label_anchor": [0, -18], "near_rect": [-11, -15, 22, 16],
            "layers": [{"rect": [7, 241, 20, 15], "offset": [-10, -14]}],
            "fx": {
                "seam": [{"origin": [-6, -7], "width": 13, "colors": ["F", "Y", "y"], "hold": 7}],
                "sparkle": [{"points": [[0, -12], [5, -13]], "colors": ["Y", "F"], "hold": 15}],
            },
            "state_notes": "闭合储藏箱：缝隙呼吸暖光；near 高亮",
        },
        "chest_open": {
            "label_anchor": [0, -18], "near_rect": [-11, -15, 22, 16],
            "layers": [{"rect": [39, 241, 20, 15], "offset": [-10, -14]}],
            "fx": {
                "glow": [{"center": [0, -9], "radii": [6, 3], "colors": ["Y", "y"],
                          "alpha": 0.32, "hold": 8}],
                "motes": [{"origin": [0, -11], "count": 2, "colors": ["Y", "F"],
                           "spread": [7, 4], "rise": 8, "hold": 8}],
            },
            "state_notes": "打开储藏箱：箱内暖光 + 上浮微尘",
        },
        "crates": {
            "label_anchor": [0, -26], "near_rect": [-25, -25, 50, 26],
            "layers": [{"rect": [32, 471, 48, 25], "offset": [-24, -24]}],
            "fx": {
                "dust": [{"origin": [0, -6], "count": 4, "colors": ["P", "Q", "l"],
                          "spread": [30, 6], "hold": 13}],
                "sparkle": [{"points": [[-12, -14], [10, -9]], "colors": ["Y", "y"], "hold": 21}],
            },
            "state_notes": "木箱堆（含开口箱）：静态图块 + 尘埃",
        },
        "crate_single": {
            "label_anchor": [0, -20], "near_rect": [-9, -17, 18, 19],
            "layers": [{"rect": [32, 479, 16, 17], "offset": [-8, -16]}],
            "fx": {
                "dust": [{"origin": [0, -4], "count": 2, "colors": ["P", "l"], "spread": [8, 4], "hold": 15}],
                "sparkle": [{"points": [[0, -10]], "colors": ["y"], "hold": 23}],
            },
            "state_notes": "单木箱（近道装饰）",
        },
        "crate_stack": {
            "label_anchor": [0, -37], "near_rect": [-17, -36, 34, 37],
            "layers": [{"rect": [96, 461, 32, 35], "offset": [-16, -34]}],
            "fx": {
                "dust": [{"origin": [0, -8], "count": 3, "colors": ["P", "Q"], "spread": [22, 8], "hold": 14}],
            },
            "state_notes": "叠放木箱堆（靠墙）",
        },
        "papers": {
            "label_anchor": [0, -26], "near_rect": [-15, -25, 30, 26],
            "layers": [
                {"rect": [1, 444, 14, 16], "offset": [-8, -17]},
                {"rect": [2, 433, 13, 10], "offset": [-14, -23]},
                {"rect": [37, 453, 7, 7], "offset": [4, -14]},
            ],
            "fx": {
                "dust": [{"origin": [0, -10], "count": 3, "colors": ["w", "Q", "P"], "spread": [18, 8], "hold": 12}],
                "sparkle": [{"points": [[-2, -10]], "colors": ["w"], "hold": 24}],
            },
            "state_notes": "散落纸张/文件（三层图块合成）",
        },
        "shelf": {
            "label_anchor": [0, -36], "near_rect": [-9, -35, 18, 38],
            "layers": [{"rect": [112, 414, 16, 34], "offset": [-8, -32]}],
            "fx": {
                "sparkle": [{"points": [[0, -29]], "colors": ["Z", "z"], "hold": 17}],
                "dust": [{"origin": [0, -12], "count": 2, "colors": ["P", "l"], "spread": [9, 10], "hold": 16}],
            },
            "state_notes": "书架/高柜（顶部青色书页反光）",
        },
        "barrel": {
            "label_anchor": [0, -21], "near_rect": [-8, -17, 16, 18],
            "prop": "barrel",
            "state_notes": "木桶：图集 c5 r26-28 实际为墙火把/发光菌，无独立透明木桶；此处用手绘同调色板木桶（见 docs 说明）",
        },
        "mushroom_red": {
            "label_anchor": [0, -21], "near_rect": [-13, -20, 26, 21],
            "layers": [{"rect": [0, 397, 23, 19], "offset": [-11, -18]}],
            "fx": {
                "spores": [{"origin": [0, -12], "count": 3, "colors": ["w", "P", "z"],
                            "spread": [14, 8], "rise": 10, "hold": 10}],
            },
            "state_notes": "红蘑菇丛：静态图块 + 孢子",
        },
        "glow_mushroom": {
            "label_anchor": [0, -14], "near_rect": [-8, -13, 16, 14],
            "layers": [{"rect": [82, 448, 12, 13], "offset": [-6, -12]}],
            "fx": {
                "pulse": [{"center": [0, -8], "radius": [5, 3], "colors": ["Z", "z", "I"],
                           "alpha": 0.30, "hold": 9}],
                "spores": [{"origin": [0, -10], "count": 2, "colors": ["Z", "z"],
                            "spread": [8, 6], "rise": 9, "hold": 8}],
            },
            "state_notes": "地面发光菌：青绿脉冲光 + 孢子",
        },
        "torch": {
            "label_anchor": [0, -24], "near_rect": [-9, -23, 18, 24],
            "layers": [{"rect": [65, 425, 17, 22], "offset": [-8, -21]}],
            "fx": {
                "flame": [{"origin": [-1, -22], "hold": 5, "colors": ["F", "W", "Y", "y"]}],
                "motes": [{"origin": [0, -20], "count": 3, "colors": ["F", "Y", "y"],
                           "spread": [6, 6], "rise": 9, "hold": 7}],
                "glow": [{"center": [0, -16], "radii": [9, 4], "colors": ["y", "a"],
                          "alpha": 0.16, "hold": 9}],
            },
            "state_notes": "立式火把：图块未带火焰，运行时叠加火焰/火星/暖光；state.lit=false 时只留冷炭",
        },
        "wall_panel": {
            "label_anchor": [0, -19], "near_rect": [-9, -18, 18, 18],
            "layers": [{"rect": [47, 687, 16, 16], "offset": [-8, -16]}],
            "fx": {
                "pulse": [{"center": [0, -8], "radius": [4, 4], "colors": ["J", "I", "z"],
                           "alpha": 0.30, "hold": 8}],
            },
            "state_notes": "墙挂装置面板（绿）：导光受光/目标标记用；带 16x16 砖墙底，建议贴墙放置",
        },
        "wall_panel_red": {
            "label_anchor": [0, -19], "near_rect": [-9, -18, 18, 18],
            "layers": [{"rect": [47, 703, 16, 16], "offset": [-8, -16]}],
            "fx": {
                "pulse": [{"center": [0, -8], "radius": [4, 4], "colors": ["T", "r", "o"],
                           "alpha": 0.30, "hold": 8}],
            },
            "state_notes": "墙挂装置面板（红）：警示/未对准",
        },
        "wall_panel_cyan": {
            "label_anchor": [0, -19], "near_rect": [-9, -18, 18, 18],
            "layers": [{"rect": [47, 719, 16, 16], "offset": [-8, -16]}],
            "fx": {
                "pulse": [{"center": [0, -8], "radius": [4, 4], "colors": ["Z", "z", "q"],
                           "alpha": 0.30, "hold": 8}],
            },
            "state_notes": "墙挂装置面板（青）：冷却/备用",
        },
    }


# ---------------------------------------------------------------------------
# Ambient particles
# ---------------------------------------------------------------------------
def build_ambient() -> dict:
    return {
        "budget": 24,
        "kinds": {
            "spores": {"base_count": 7, "pixel": 1, "colors": ["z", "Z", "w"],
                       "alpha": 0.42, "span": [34, 26], "hold": 2,
                       "state_notes": "洞穴/菌丛上浮孢子：1px，慢速上浮 + 1px 横摆"},
            "dust": {"base_count": 5, "pixel": 1, "colors": ["P", "Q", "l"],
                     "alpha": 0.32, "span": [40, 8], "hold": 3,
                     "state_notes": "地面/家具旁尘埃：横向漂移，贴地 1px"},
            "drip": {"base_count": 2, "pixel": 1, "colors": ["Z", "z", "q"],
                     "alpha": 0.65, "span": [4, 20], "hold": 2,
                     "state_notes": "水管滴水：下落 + 2px 溅落，循环 56 tick"},
            "ember": {"base_count": 3, "pixel": 1, "colors": ["F", "Y", "y"],
                      "alpha": 0.85, "span": [8, 22], "hold": 2,
                      "state_notes": "灯座/火把余烬：上浮暖色火星"},
            "light_pool": {"base_count": 1, "pixel": 1, "colors": ["a", "y"],
                           "alpha": 0.12, "radii": [18, 5], "hold": 18,
                           "state_notes": "灯光呼吸地面光斑：2~3 层抖动硬像素，无渐变"},
            "sway": {"base_count": 1, "pixel": 1, "colors": ["y", "a"],
                     "alpha": 0.07, "length": 26, "hold": 8,
                     "state_notes": "吊灯摆动光锥：1px 抖动，左右 ±2px"},
        },
    }


# ---------------------------------------------------------------------------
# Serialisation
# ---------------------------------------------------------------------------
def variant_number(v) -> int:
    if isinstance(v, tuple):
        return v[0]
    return int(v)


def payload() -> dict:
    props = build_props()
    kinds = {}
    stats = {}
    for kind, spec in props.items():
        variants = {}
        union = set()
        for vname, (frames, hold, flash) in spec["variants"].items():
            for f in frames:
                f.outline("K")
            rows = [f.strings() for f in frames]
            for f in frames:
                assert len(f.rows) == spec["size"][1], f"{kind}/{vname} frame height"
                for row in f.strings():
                    assert len(row) == spec["size"][0], f"{kind}/{vname} frame width"
            vcolors = set()
            for f in frames:
                vcolors |= f.colors()
            assert vcolors <= set(PALETTE), f"{kind}/{vname} undefined chars {sorted(vcolors - set(PALETTE))}"
            assert len(vcolors) <= 16, f"{kind}/{vname} {len(vcolors)} colours {sorted(vcolors)}"
            assert 3 <= len(frames) <= 6, f"{kind}/{vname} {len(frames)} frames"
            assert 4 <= hold <= 20, f"{kind}/{vname} hold {hold}"
            union |= vcolors
            variants[vname] = {
                "hold": hold,
                "rest_frame": 0,
                "flash_frames": flash,
                "frames": rows,
            }
        assert len(union) <= 16, f"{kind} union {len(union)} colours"
        w, h = spec["size"]
        ax, ay = spec["anchor"]
        lx, ly = spec["label"]
        kinds[kind] = {
            "size": [w, h],
            "anchor": [ax, ay],
            "label_anchor": [lx, ly],
            "ground": spec["ground"],
            "default_variant": "unlit" if kind == "lamp" else ("closed" if kind == "chest" else ("sealed" if kind in ("door", "mine_door", "portal") else ("off" if kind == "guide_target" else ("idle" if "idle" in variants else ("on" if "on" in variants else "d11"))))),
            "state_notes": PROP_STATE_NOTES[kind],
            "variants": variants,
        }
        stats[kind] = {"frames": sum(len(x[0]) for x in spec["variants"].values()),
                       "colors": len(union), "size": [w, h]}

    furniture = build_furniture()
    palette_used = set()
    for spec in props.values():
        for frames, _hold, _flash in spec["variants"].values():
            for frame in frames:
                palette_used |= frame.colors()
    for ambient_def in build_ambient()["kinds"].values():
        palette_used |= set(ambient_def["colors"])
    for f in furniture.values():
        for fx in f.get("fx", {}).values():
            for item in fx:
                palette_used |= set(item.get("colors", []))
    missing = palette_used - set(PALETTE)
    assert not missing, f"palette chars missing: {sorted(missing)}"

    data = {
        "schema_version": 1,
        "generator": "tools/gen_props.py",
        "source": {
            "tileset": "res://assets/original/Tilesets/Complete.png",
            "size": [128, 736],
            "tile": 16,
            "note": "所有调色板颜色均从该图集逐像素采样；家具图块直接按像素矩形裁切",
        },
        "world": {"logical_size": [320, 180], "scale": 4},
        "palette": {
            "groups": {
                "ink": "kKjhv", "metal": "MmnLlq", "cold": "zZ",
                "brown": "dDeBbCc", "stone": "PQ", "warm": "wyaAYFW",
                "red": "RrToO", "violet": "VUu", "green": "gGHIJx",
            },
            "colors": {ch: "#" + PALETTE[ch][0] for ch in sorted(palette_used)},
        },
        "aliases": {
            "rest": "bed", "socket": "lamp", "reward": "ring", "exit": "portal",
            "end": "portal", "storage": "door", "storage_door": "door",
            "crate": "crates", "crates_small": "crate_single", "barrel_old": "barrel",
            "lore": "papers", "note": "papers", "switch": "lamp", "growth": "ring", "story": "papers", "sidequest": "chest", "ending": "portal", "credits": "portal",
            "mushroom": "mushroom_red", "wall_panel_green": "wall_panel",
            "panel": "wall_panel",
        },
        "kinds": kinds,
        "furniture": furniture,
        "ambient": build_ambient(),
        "stats": stats,
    }
    blob = json.dumps(data, ensure_ascii=True, sort_keys=True, separators=(",", ":"))
    data["build"] = hashlib.sha256(blob.encode()).hexdigest()[:16]
    return data


# ---------------------------------------------------------------------------
# Previews
# ---------------------------------------------------------------------------
def ensure_out() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)


def render_props_sheet(data: dict) -> None:
    scale = 6
    pad = 10
    entries = []  # (green, label, image)
    for kind, spec in data["kinds"].items():
        w, h = spec["size"]
        for vname, vdef in spec["variants"].items():
            frames = vdef["frames"]
            n = len(frames)
            img = Image.new("RGBA", (n * (w + 4) + 4, h + 4), (0, 0, 0, 0))
            for i, rows in enumerate(frames):
                for y, row in enumerate(rows):
                    for x, ch in enumerate(row):
                        if ch == ".":
                            continue
                        img.putpixel((4 + i * (w + 4) + x, 2 + y), rgba(ch))
            entries.append((f"{kind}/{vname}", img))
    cell_w = max(e[1].width for e in entries) * scale + pad * 2
    cell_h = max(e[1].height for e in entries) * scale + pad * 2 + 14
    cols = 2
    rows = (len(entries) + cols - 1) // cols
    sheet = Image.new("RGBA", (cell_w * cols, cell_h * rows), (22, 26, 23, 255))
    d = ImageDraw.Draw(sheet)
    for i, (label, img) in enumerate(entries):
        cx, cy = (i % cols) * cell_w, (i // cols) * cell_h
        d.text((cx + 6, cy + 4), label, fill=(236, 223, 171, 255))
        # ground line
        d.line([(cx + 8, cy + cell_h - 12), (cx + cell_w - 8, cy + cell_h - 12)], fill=(70, 84, 64, 255))
        sheet.alpha_composite(img.resize((img.width * scale, img.height * scale), Image.NEAREST),
                              (cx + pad, cy + cell_h - 12 - img.height * scale))
    sheet.save(OUT_DIR / "props_sheet.png")

    # one sheet per kind for convenient inspection
    for kind, spec in data["kinds"].items():
        w, h = spec["size"]
        vnames = list(spec["variants"].keys())
        n = max(len(spec["variants"][v]["frames"]) for v in vnames)
        scale = 8
        img = Image.new("RGBA", (n * (w + 2) * scale + 160, len(vnames) * (h + 2) * scale + 20),
                        (22, 26, 23, 255))
        d = ImageDraw.Draw(img)
        for vi, vname in enumerate(vnames):
            d.text((4, 10 + vi * (h + 2) * scale + h * scale // 2), vname, fill=(230, 220, 180, 255))
            for fi, rows in enumerate(spec["variants"][vname]["frames"]):
                g = Grid(w, h)
                g.rows = [list(r) for r in rows]
                frame = Image.new("RGBA", (w, h), (0, 0, 0, 0))
                for y, row in enumerate(rows):
                    for x, ch in enumerate(row):
                        if ch != ".":
                            frame.putpixel((x, y), rgba(ch))
                img.alpha_composite(
                    frame.resize((w * scale, h * scale), Image.NEAREST),
                    (150 + fi * (w + 2) * scale, 10 + vi * (h + 2) * scale))
        img.save(OUT_DIR / f"kind_{kind}.png")


def furniture_crop(rect) -> Image.Image:
    x, y, w, h = rect
    src = Image.open(TILESET).convert("RGBA")
    return src.crop((x, y, x + w, y + h))


def blend_pixel(img: Image.Image, x: int, y: int, color, alpha: float) -> None:
    if not (0 <= x < img.width and 0 <= y < img.height):
        return
    r, g, b, a = img.getpixel((x, y))
    na = alpha
    nr = int(r * (1 - na) + color[0] * na)
    ng = int(g * (1 - na) + color[1] * na)
    nb = int(b * (1 - na) + color[2] * na)
    img.putpixel((x, y), (nr, ng, nb, 255))


def draw_ellipse_glow(img: Image.Image, cx: int, cy: int, rx: int, ry: int,
                      colors, alpha: float, phase: int = 0) -> None:
    for dy in range(-ry, ry + 1):
        for dx in range(-rx, rx + 1):
            d = (dx / rx) ** 2 + (dy / ry) ** 2
            if d > 1.0:
                continue
            ring = 0 if d < 0.35 else (1 if d < 0.7 else 2)
            step = 2 + ring
            if (dx + dy + phase + ring * 2) % step != 0:
                continue
            a = alpha * (1.0 - 0.25 * ring)
            ch = colors[min(ring, len(colors) - 1)]
            blend_pixel(img, cx + dx, cy + dy, rgb(ch), a)


def draw_motes(img: Image.Image, origin, count, colors, spread, rise, tick, hold=8) -> None:
    for i in range(count):
        t = tick // max(1, hold)
        x = origin[0] + (i * 13 + (t + i) % 3 - 1) % max(1, spread[0]) - spread[0] // 2
        y = origin[1] - (t * 1 + i * 5) % max(1, rise)
        a = 0.55 + 0.35 * ((i + t) % 3) / 2
        ch = colors[i % len(colors)]
        blend_pixel(img, x, y, rgb(ch), a)


def draw_flame(img: Image.Image, origin, tick, hold, colors) -> None:
    f = (tick // hold) % 3
    shapes = [
        [(1, 0, 0), (1, 1, 1), (2, 1, 2), (0, 2, 0), (1, 2, 1), (2, 2, 0), (0, 3, 2), (1, 3, 1), (1, 4, 0)],
        [(0, 1, 2), (1, 1, 0), (1, 2, 1), (2, 2, 2), (0, 3, 0), (1, 3, 0), (2, 3, 2), (1, 4, 0)],
        [(1, 0, 2), (2, 1, 0), (1, 1, 1), (0, 2, 0), (1, 2, 1), (2, 2, 0), (0, 3, 2), (1, 3, 1), (1, 4, 2)],
    ]
    for dx, dy, ci in shapes[f]:
        blend_pixel(img, origin[0] + dx, origin[1] + dy, rgb(colors[ci % len(colors)]), 0.95)


def draw_seam(img: Image.Image, origin, width, colors, tick, hold) -> None:
    f = (tick // hold) % 3
    for i in range(width):
        if (i + f) % 3 == 0:
            continue
        ch = colors[(i + f) % len(colors)]
        blend_pixel(img, origin[0] + i, origin[1], rgb(ch), 0.75)


def draw_sparkle(img: Image.Image, points, colors, tick, hold) -> None:
    f = (tick // hold) % 6
    if f >= 2:
        return
    for i, p in enumerate(points):
        ch = colors[i % len(colors)]
        blend_pixel(img, p[0], p[1], rgb(ch), 0.95 if f == 0 else 0.6)


def draw_spores(img: Image.Image, origin, count, colors, spread, rise, tick, hold) -> None:
    for i in range(count):
        t = tick // max(1, hold)
        x = origin[0] + (i * 7 + (t + i) % 3 - 1) % max(1, spread[0]) - spread[0] // 2
        y = origin[1] - (t * 2 + i * 4) % max(1, rise)
        blend_pixel(img, x, y, rgb(colors[i % len(colors)]), 0.8)


def draw_dust(img: Image.Image, origin, count, colors, spread, tick, hold) -> None:
    for i in range(count):
        t = tick // max(1, hold)
        x = origin[0] + (i * 17 + t) % max(1, spread[0]) - spread[0] // 2
        y = origin[1] + (i * 3) % max(1, spread[1]) if len(spread) > 1 else origin[1]
        blend_pixel(img, x, y, rgb(colors[i % len(colors)]), 0.5)


def render_furniture_sheet(data: dict) -> None:
    scale = 6
    entries = []
    for kind, spec in data["furniture"].items():
        near = spec["near_rect"]
        img = Image.new("RGBA", (near[2], near[3]), (0, 0, 0, 0))
        if "prop" in spec:
            # hand-drawn prop sprite preview
            p = data["kinds"][spec["prop"]]
            frame = p["variants"]["idle"]["frames"][0]
            for y, row in enumerate(frame):
                for x, ch in enumerate(row):
                    if ch != ".":
                        px = x + p["anchor"][0] - near[0]
                        py = y + p["anchor"][1] - near[1]
                        if 0 <= px < img.width and 0 <= py < img.height:
                            img.putpixel((px, py), rgba(ch))
            entries.append((kind, img))
            continue
        for layer in spec["layers"]:
            crop = furniture_crop(layer["rect"])
            ox = layer["offset"][0] - near[0]
            oy = layer["offset"][1] - near[1]
            img.alpha_composite(crop, (ox, oy))
        # overlay fx at a mid frame so the life is visible in the still
        fx = spec.get("fx", {})
        cx = -near[0]
        cy = -near[1]
        for item in fx.get("glow", []):
            draw_ellipse_glow(img, cx + item["center"][0], cy + item["center"][1],
                              item["radii"][0], item["radii"][1], item["colors"], item["alpha"], 2)
        for item in fx.get("pulse", []):
            draw_ellipse_glow(img, cx + item["center"][0], cy + item["center"][1],
                              item["radius"][0], item["radius"][1], item["colors"], item["alpha"], 1)
        for item in fx.get("seam", []):
            draw_seam(img, (cx + item["origin"][0], cy + item["origin"][1]),
                      item["width"], item["colors"], 14, item["hold"])
        for item in fx.get("flame", []):
            draw_flame(img, (cx + item["origin"][0], cy + item["origin"][1]),
                       14, item["hold"], item["colors"])
        for item in fx.get("motes", []):
            draw_motes(img, (cx + item["origin"][0], cy + item["origin"][1]), item["count"],
                       item["colors"], item["spread"], item["rise"], 20, item["hold"])
        for item in fx.get("spores", []):
            draw_spores(img, (cx + item["origin"][0], cy + item["origin"][1]), item["count"],
                        item["colors"], item["spread"], item["rise"], 20, item["hold"])
        for item in fx.get("dust", []):
            draw_dust(img, (cx + item["origin"][0], cy + item["origin"][1]), item["count"],
                      item["colors"], item["spread"], 16, item["hold"])
        for item in fx.get("sparkle", []):
            draw_sparkle(img, [(cx + p[0], cy + p[1]) for p in item["points"]],
                         item["colors"], 0, item["hold"])
        entries.append((kind, img))
    cell_w = max(e[1].width for e in entries) * scale + 20
    cell_h = max(e[1].height for e in entries) * scale + 30
    cols = 4
    rows = (len(entries) + cols - 1) // cols
    sheet = Image.new("RGBA", (cell_w * cols, cell_h * rows), (22, 26, 23, 255))
    d = ImageDraw.Draw(sheet)
    for i, (label, img) in enumerate(entries):
        cx = (i % cols) * cell_w
        cy = (i // cols) * cell_h
        d.text((cx + 4, cy + 3), label, fill=(230, 220, 180, 255))
        d.rectangle([cx + 6, cy + 18, cx + 6 + img.width * scale + 1, cy + 18 + img.height * scale + 1],
                    outline=(60, 70, 58, 255))
        sheet.alpha_composite(img.resize((img.width * scale, img.height * scale), Image.NEAREST),
                              (cx + 7, cy + 19))
    sheet.save(OUT_DIR / "furniture_sheet.png")


def render_world_mock(data: dict) -> None:
    """Compose a 320x180 room with real tileset tiles, props, furniture and character."""
    src = Image.open(TILESET).convert("RGBA")
    room = Image.new("RGBA", (320, 180), (36, 42, 37, 255))

    def tile(cell_x, cell_y, x, y):
        room.alpha_composite(src.crop((cell_x * 16, cell_y * 16, cell_x * 16 + 16, cell_y * 16 + 16)), (x, y))

    for y in range(27, 159, 16):
        for x in range(0, 320, 16):
            tile(6, 4, x, y)
    for wall in ((135, 48, 18, 45), (135, 123, 18, 26)):
        wx, wy, ww, wh = wall
        for y in range(wy, wy + wh, 16):
            for x in range(wx, wx + ww, 16):
                tile(2, 1, x, y)

    def put_prop(kind, pos, state, tick):
        if kind in data["kinds"]:
            spec = data["kinds"][kind]
            vname = "lit" if state.get("lit") and "lit" in spec["variants"] else (
                "open" if state.get("open") and "open" in spec["variants"] else (
                    "complete" if state.get("complete") and "complete" in spec["variants"] else (
                        "on" if state.get("correct") and "on" in spec["variants"] else (
                            "d%d%s" % (state.get("dir", 3), "c" if state.get("correct") else "w")
                            if kind == "guide" else (
                                "sealed" if "sealed" in spec["variants"] and not state.get("available", True) else
                                spec["default_variant"])))))
            frames = spec["variants"][vname]["frames"]
            rows = frames[(tick // spec["variants"][vname]["hold"]) % len(frames)]
            ax, ay = spec["anchor"]
            for y, row in enumerate(rows):
                for x, ch in enumerate(row):
                    if ch == ".":
                        continue
                    px, py = int(pos[0]) + ax + x, int(pos[1]) + ay + y
                    if 0 <= px < 320 and 0 <= py < 180:
                        room.putpixel((px, py), rgba(ch))
            return
        spec = data["furniture"].get(kind)
        if not spec:
            return
        if "prop" in spec:
            put_prop(spec["prop"], pos, state, tick)
            return
        near = spec["near_rect"]
        temp = Image.new("RGBA", (near[2], near[3]), (0, 0, 0, 0))
        for layer in spec["layers"]:
            ox = layer["offset"][0] - near[0]
            oy = layer["offset"][1] - near[1]
            temp.alpha_composite(src.crop((layer["rect"][0], layer["rect"][1],
                                           layer["rect"][0] + layer["rect"][2],
                                           layer["rect"][1] + layer["rect"][3])), (ox, oy))
        gas = spec.get("fx", {})
        cx, cy = -near[0], -near[1]
        for item in gas.get("glow", []):
            draw_ellipse_glow(temp, cx + item["center"][0], cy + item["center"][1],
                              item["radii"][0], item["radii"][1], item["colors"], item["alpha"], 2)
        for item in gas.get("pulse", []):
            draw_ellipse_glow(temp, cx + item["center"][0], cy + item["center"][1],
                              item["radius"][0], item["radius"][1], item["colors"], item["alpha"], 1)
        for item in gas.get("seam", []):
            draw_seam(temp, (cx + item["origin"][0], cy + item["origin"][1]), item["width"],
                      item["colors"], tick, item["hold"])
        for item in gas.get("flame", []):
            draw_flame(temp, (cx + item["origin"][0], cy + item["origin"][1]), tick, item["hold"], item["colors"])
        for item in gas.get("motes", []):
            draw_motes(temp, (cx + item["origin"][0], cy + item["origin"][1]), item["count"],
                       item["colors"], item["spread"], item["rise"], tick, item["hold"])
        for item in gas.get("spores", []):
            draw_spores(temp, (cx + item["origin"][0], cy + item["origin"][1]), item["count"],
                        item["colors"], item["spread"], item["rise"], tick, item["hold"])
        for item in gas.get("dust", []):
            draw_dust(temp, (cx + item["origin"][0], cy + item["origin"][1]), item["count"],
                      item["colors"], item["spread"], tick, item["hold"])
        for item in gas.get("sparkle", []):
            draw_sparkle(temp, [(cx + p[0], cy + p[1]) for p in item["points"]], item["colors"], tick, item["hold"])
        px = int(pos[0]) + near[0]
        py = int(pos[1]) + near[1]
        room.alpha_composite(temp, (px, py))

    # ambient helpers (mirror of prop_art.gd math, preview only)
    def ambient(kind, pos, tick):
        spec = data["ambient"]["kinds"][kind]
        cx, cy = int(pos[0]), int(pos[1])
        if kind == "light_pool":
            for dy in range(-5, 6):
                for dx in range(-18, 19):
                    d = (dx / 18) ** 2 + (dy / 5) ** 2
                    if d > 1:
                        continue
                    ring = 0 if d < 0.35 else (1 if d < 0.7 else 2)
                    if (dx + dy + tick // 24 + ring * 2) % (2 + ring) != 0:
                        continue
                    blend_pixel(room, cx + dx, cy + dy, rgb(spec["colors"][min(ring, 1)]), spec["alpha"] * (1 - ring * 0.25))
            return
        if kind == "sway":
            sway = [0, 1, 2, 1, 0, -1, -2, -1][(tick // 24) % 8]
            for dy in range(0, spec["length"]):
                half = 2 + dy // 4
                for dx in range(-half, half + 1):
                    if (dx + dy + tick) % 3 == 0:
                        continue
                    sx = int(round(dx + sway * dy / 12))
                    blend_pixel(room, cx + sx, cy + dy, rgb(spec["colors"][0]), spec["alpha"])
            return
        colors = spec["colors"]
        n = spec["base_count"]
        for i in range(n):
            t = tick
            if kind == "spores":
                x = cx - 17 + (i * 13 + (t // 16 + i) % 3) % 34
                y = cy - 2 - ((t // 2 + i * 9) % 26)
            elif kind == "dust":
                x = cx - 20 + (i * 17 + t // 3) % 40
                y = cy - 1 - (i * 5) % 7
            elif kind == "drip":
                tt = (tick + i * 28) % 56
                if tt < 24:
                    x = cx + (i * 6 - 3)
                    y = cy - 12 + tt // 2
                elif tt < 32:
                    x = cx + [(-2, 0), (0, 0), (2, 0)][tt % 3][0]
                    y = cy - 1
                else:
                    continue
            else:  # ember
                x = cx - 3 + (i * 7 + (t // 12 + i) % 3) % 7
                y = cy - 18 - ((t // 2 + i * 7) % 20)
            blend_pixel(room, x, y, rgb(colors[i % len(colors)]), spec["alpha"] * 0.8)

    def guide_beam(pos, direction, correct, t):
        origin = (int(pos[0]), int(pos[1]) - 17)
        vec = {0: (0, -1), 1: (1, 0), 2: (0, 1), 3: (-1, 0)}[direction]
        phase = (t // 4) % 6
        colors = ["Y", "F", "W"] if correct else ["q", "z"]
        for dist in range(4, 24):
            if (dist + phase) % 6 >= 4:
                continue
            for w in (-1, 0, 1):
                if w != 0 and (dist + w) % 2 == 0:
                    continue
                x = origin[0] + vec[0] * dist + (w if vec[1] == 0 else 0)
                y = origin[1] + vec[1] * dist + (w if vec[0] == 0 else 0)
                ch = colors[0] if w == 0 else colors[min(1, len(colors) - 1)]
                blend_pixel(room, x, y, rgb(ch), 0.85 if w == 0 else 0.55)

    tick = 13
    # wall fixture patch so the mounted panel reads as a wall device
    for y in range(27, 43, 16):
        tile(2, 1, 68, y)
    # props & furniture
    put_prop("lamp", (88, 80), {"lit": True}, tick)
    put_prop("bed", (48, 128), {}, tick)
    ambient("light_pool", (88, 93), tick)
    ambient("ember", (88, 80), tick)
    put_prop("chest_closed", (76, 62), {}, tick)
    put_prop("chest_open", (200, 74), {}, tick)
    put_prop("ring", (245, 120), {"complete": True}, tick)
    put_prop("pipe", (172, 108), {"scanned": True}, tick)
    ambient("drip", (189, 119), tick)
    put_prop("door", (292, 96), {"available": True}, tick)
    ambient("sway", (292, 58), tick)
    put_prop("mine_door", (285, 150), {"available": False}, tick)
    put_prop("guide", (200, 150), {"dir": 0, "correct": True}, tick)
    guide_beam((200, 150), 0, True, tick)
    put_prop("guide_target", (205, 120), {"correct": True}, tick)
    put_prop("rail", (120, 158), {}, tick)
    put_prop("rubble", (60, 92), {}, tick)
    put_prop("barrel", (172, 60), {}, tick)
    put_prop("crates", (250, 40), {}, tick)
    put_prop("crate_single", (105, 60), {}, tick)
    put_prop("papers", (110, 82), {}, tick)
    put_prop("shelf", (124, 88), {}, tick)
    put_prop("mushroom_red", (270, 145), {}, tick)
    put_prop("glow_mushroom", (100, 152), {}, tick)
    put_prop("torch", (225, 135), {"lit": True}, tick)
    put_prop("wall_panel", (76, 43), {"lit": True}, tick)
    ambient("spores", (250, 150), tick)
    ambient("dust", (60, 128), tick)
    # character for scale reference
    cleric = Image.open(ROOT / "game/assets/original/Characters/Cleric.png").convert("RGBA")
    room.alpha_composite(cleric.crop((16, 0, 32, 32)), (150 - 8, 120 - 31))
    room = room.resize((320 * 4, 180 * 4), Image.NEAREST)
    room.save(OUT_DIR / "props_world_mock.png")


def render_palette(data: dict) -> None:
    groups = data["palette"]["groups"]
    colors = data["palette"]["colors"]
    sw = 34
    entries = []
    for gname, chars in groups.items():
        for ch in chars:
            if ch in colors:
                entries.append((gname, ch, colors[ch]))
    per_row = 12
    rows = (len(entries) + per_row - 1) // per_row
    sheet = Image.new("RGBA", (per_row * sw, rows * (sw + 18) + 8), (22, 26, 23, 255))
    d = ImageDraw.Draw(sheet)
    for i, (gname, ch, hx) in enumerate(entries):
        x, y = (i % per_row) * sw, (i // per_row) * (sw + 18) + 4
        d.rectangle([x + 2, y + 2, x + sw - 4, y + sw - 4], fill=(int(hx[1:3], 16), int(hx[3:5], 16), int(hx[5:7], 16), 255))
        d.text((x + 3, y + sw - 8), ch, fill=(255, 255, 255, 255))
        d.text((x + 3, y + sw - 1), hx[1:], fill=(200, 200, 190, 255))
    sheet.save(OUT_DIR / "palette_sheet.png")


def audit_palette() -> None:
    src = Image.open(TILESET).convert("RGBA")
    from collections import Counter
    counter = Counter(p for p in src.getdata() if p[3])
    missing = []
    for ch, (hx, _group) in PALETTE.items():
        col = (int(hx[0:2], 16), int(hx[2:4], 16), int(hx[4:6], 16), 255)
        if counter.get(col, 0) == 0:
            missing.append((ch, hx))
    if missing:
        raise SystemExit("palette colours missing from Complete.png: %r" % missing)
    print(f"palette audit: {len(PALETTE)} colours all present in {TILESET.name}")


def main() -> None:
    ensure_out()
    audit_palette()
    data = payload()
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    render_props_sheet(data)
    render_furniture_sheet(data)
    render_world_mock(data)
    render_palette(data)
    total_frames = sum(s["frames"] for s in data["stats"].values())
    print(f"wrote {OUT_JSON.relative_to(ROOT)} build={data['build']} kinds={len(data['kinds'])} "
          f"furniture={len(data['furniture'])} prop_frames={total_frames}")
    print(f"previews -> {OUT_DIR.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
