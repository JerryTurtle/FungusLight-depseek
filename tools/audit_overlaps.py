"""Static authoring audit for the 37 campaign rooms.

Checks prop/actor visual bounds, solid footprints, spawn clearance and the
screen-space label bands. This is a data/authoring check; it does not replace
looking at the rendered rooms.
"""
from __future__ import annotations

import itertools
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "game/data/prologue.json"
PROPS = ROOT / "game/assets/props/props_data.json"
OUT_JSON = ROOT / "qa/evidence/G4/G4-009-overlap-audit-static.json"
OUT_MD = ROOT / "qa/evidence/G4/G4-009-overlap-audit-static.md"


def rect_intersection(a, b):
    w = max(0.0, min(a[0] + a[2], b[0] + b[2]) - max(a[0], b[0]))
    h = max(0.0, min(a[1] + a[3], b[1] + b[3]) - max(a[1], b[1]))
    return round(w, 2), round(h, 2), round(w * h, 2)


def load_data():
    data = json.loads(DATA.read_text(encoding="utf-8"))
    props = json.loads(PROPS.read_text(encoding="utf-8"))
    return data, props


def resolver(props):
    aliases = props["aliases"]
    kinds = props["kinds"]
    furniture = props["furniture"]

    def resolve(kind):
        for _ in range(8):
            if kind in kinds or kind in furniture:
                return kind
            if kind not in aliases:
                return kind
            kind = aliases[kind]
        return kind

    return resolve


def visual_rect(kind, pos, props, resolve):
    kind = resolve(kind)
    if kind in props["kinds"]:
        item = props["kinds"][kind]
        anchor, size = item["anchor"], item["size"]
        return [pos[0] + anchor[0], pos[1] + anchor[1], size[0], size[1]]
    if kind in props["furniture"]:
        item = props["furniture"][kind]
        if "prop" in item:
            return visual_rect(item["prop"], pos, props, resolve)
        near = item.get("near_rect", [-8, -8, 16, 16])
        return [pos[0] + near[0], pos[1] + near[1], near[2], near[3]]
    return None


def actor_rect(pos):
    return [pos[0] - 8, pos[1] - 31, 16, 32]


def solid_rect(kind, pos):
    x, y = pos
    table = {
        "chest": [x - 7, y - 8, 14, 9],
        "crates": [x - 20, y - 16, 40, 16],
        "cabinet": [x - 7, y - 8, 14, 10],
        "barrel": [x - 5, y - 5, 10, 8],
        "shelf": [x - 7, y - 8, 14, 10],
        "torch": [x - 3, y - 5, 6, 6],
        "bed": [x - 15, y - 44, 31, 44],
        "lamp": [x - 5, y - 5, 10, 10],
        "door": [x - 9, y - 28, 18, 28],
        "portal": [x - 13, y - 34, 26, 34],
    }
    return table.get(kind)


def intersects_wall(rect, walls, grow=0.0):
    for wall in walls:
        w = [wall[0] - grow, wall[1] - grow, wall[2] + grow * 2, wall[3] + grow * 2]
        if rect_intersection(rect, w)[2] > 0.0:
            return True
    return False


def label_box(name, pos, anchor, font_size=24):
    # Conservative CJK estimate: 24 px per glyph. It is only used to detect
    # bands that are already fixed by the renderer's clamp, not typography.
    width = max(24.0, len(name) * 18.0)
    at = [(pos[0] + anchor[0]) * 4.0, (pos[1] + anchor[1]) * 4.0]
    at[0] = min(max(at[0] - width / 2, 8.0), 1272.0 - width)
    at[1] = min(max(at[1], 136.0), 640.0)
    return [at[0], at[1] - font_size, width, font_size + 4.0]


def main():
    data, props = load_data()
    resolve = resolver(props)
    visual_overlaps = []
    collision_overlaps = []
    spawn_issues = []
    label_risks = []
    for node in data["nodes"]:
        node_id = node["id"]
        objects = []
        decors = []
        for obj in node.get("objects", []):
            kind = obj.get("visual", obj["kind"])
            if kind in ("wounded", "rong"):
                vr = actor_rect(obj["pos"])
            else:
                vr = visual_rect(kind, obj["pos"], props, resolve)
            objects.append({"id": obj["id"], "name": obj.get("name", obj["id"]), "kind": obj["kind"], "visual": kind, "pos": obj["pos"], "rect": vr})
        for dec in node.get("decor", []):
            vr = visual_rect(dec["kind"], dec["pos"], props, resolve)
            if vr:
                decors.append({"id": "decor:" + dec["kind"], "kind": dec["kind"], "pos": dec["pos"], "rect": vr})

        # Visual pairs: a 2x2 overlap is enough to break the pixel silhouette.
        for a, b in itertools.combinations(objects + decors, 2):
            if not a["rect"] or not b["rect"]:
                continue
            w, h, area = rect_intersection(a["rect"], b["rect"])
            if w >= 2 and h >= 2:
                visual_overlaps.append({
                    "node": node_id, "a": a["id"], "a_visual": a["visual"], "a_pos": a["pos"],
                    "b": b["id"], "b_visual": b["visual"], "b_pos": b["pos"],
                    "overlap": [w, h, area],
                })

        # Props that are not architecture should not be drawn on top of a wall.
        # Portals/doors/torches/panels are deliberately mounted into walls.
        wall_safe = {"exit", "end", "door", "portal", "torch", "wall_panel", "wall_panel_red", "wall_panel_cyan"}
        for obj in objects:
            if obj["kind"] in wall_safe or obj["visual"] in wall_safe or not obj["rect"]:
                continue
            for wall in node["walls"]:
                w, h, area = rect_intersection(obj["rect"], wall)
                if w >= 2 and h >= 2:
                    visual_overlaps.append({
                        "node": node_id, "a": obj["id"], "a_visual": obj["visual"], "a_pos": obj["pos"],
                        "b": "wall", "b_visual": "wall", "b_pos": wall,
                        "overlap": [w, h, area],
                    })
                    break
        for dec in decors:
            if dec["kind"] in wall_safe or not dec["rect"]:
                continue
            for wall in node["walls"]:
                w, h, area = rect_intersection(dec["rect"], wall)
                if w >= 2 and h >= 2:
                    visual_overlaps.append({
                        "node": node_id, "a": dec["id"], "a_visual": dec["kind"], "a_pos": dec["pos"],
                        "b": "wall", "b_visual": "wall", "b_pos": wall,
                        "overlap": [w, h, area],
                    })
                    break

        # Solid footprints must not stack; exits/portals embedded in the wall
        # are intentional architecture and are checked separately.
        solids = []
        for obj in node.get("objects", []):
            visual = obj.get("visual", obj["kind"])
            if obj["kind"] == "end":
                visual = "portal"
            elif obj["kind"] == "exit":
                visual = "portal"
            elif obj["kind"] == "rest":
                visual = "bed" if obj.get("visual") == "bed" else "lamp"
            sr = solid_rect(visual, obj["pos"])
            if sr:
                solids.append({"id": obj["id"], "kind": obj["kind"], "pos": obj["pos"], "rect": sr})
        for dec in node.get("decor", []):
            sr = solid_rect(dec["kind"], dec["pos"])
            if sr:
                solids.append({"id": "decor:" + dec["kind"], "pos": dec["pos"], "rect": sr})
        for a, b in itertools.combinations(solids, 2):
            w, h, area = rect_intersection(a["rect"], b["rect"])
            if w > 0 and h > 0:
                collision_overlaps.append({
                    "node": node_id, "a": a["id"], "b": b["id"],
                    "a_pos": a["pos"], "b_pos": b["pos"], "overlap": [w, h, area],
                })

        spawn = node["spawn"]
        spawn_rect = [spawn[0] - 5, spawn[1] - 5, 10, 10]
        if intersects_wall(spawn_rect, node["walls"], 0.1):
            spawn_issues.append({"node": node_id, "reason": "spawn in wall", "spawn": spawn})
        for entry in solids:
            if rect_intersection(spawn_rect, entry["rect"])[2] > 0:
                spawn_issues.append({"node": node_id, "reason": "spawn in blocker", "spawn": spawn, "blocker": entry["id"]})

        # Label bands: the renderer only shows the nearest label, but every
        # authored object is a candidate. Keep it clear of HUD, minimap and the
        # two-line status footer.
        bands = [(0, 0, 1110, 110), (1118, 16, 142, 92), (0, 648, 1280, 72)]
        for obj in objects:
            if not obj.get("id") or obj["kind"] == "guide_target":
                continue
            anchor = [0, -16]
            kind = resolve(obj["visual"])
            source = props["kinds"].get(kind) or props["furniture"].get(kind)
            if source:
                anchor = source.get("label_anchor", anchor)
            box = label_box(str(obj["name"]), obj["pos"], anchor)
            for band in bands:
                if rect_intersection(box, band)[2] > 0:
                    label_risks.append({"node": node_id, "object": obj["id"], "band": band, "box": box})

    report = {
        "build_id": data.get("build_id"),
        "nodes": len(data["nodes"]),
        "visual_overlaps": visual_overlaps,
        "collision_overlaps": collision_overlaps,
        "spawn_issues": spawn_issues,
        "label_risks": label_risks,
        "passed": not visual_overlaps and not collision_overlaps and not spawn_issues and not label_risks,
    }
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    lines = [
        "# G4-009 全地图重叠审计",
        "",
        f"- 构建：{report['build_id']}",
        f"- 节点：{report['nodes']}",
        f"- 视觉重叠：{len(visual_overlaps)}",
        f"- 碰撞块重叠：{len(collision_overlaps)}",
        f"- 出生点问题：{len(spawn_issues)}",
        f"- 标签/UI 区间风险：{len(label_risks)}",
        f"- 结论：{'通过' if report['passed'] else '存在待修复项'}",
        "",
    ]
    for section, rows in [("视觉重叠", visual_overlaps), ("碰撞块重叠", collision_overlaps),
                          ("出生点问题", spawn_issues), ("标签/UI 区间风险", label_risks)]:
        lines.append(f"## {section}")
        if not rows:
            lines.append("无。")
        for row in rows[:80]:
            lines.append(f"- `{json.dumps(row, ensure_ascii=False)}`")
        lines.append("")
    OUT_MD.write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps({k: report[k] for k in ("build_id", "nodes", "passed")}, ensure_ascii=False))
    print("visual", len(visual_overlaps), "collision", len(collision_overlaps),
          "spawn", len(spawn_issues), "labels", len(label_risks))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
