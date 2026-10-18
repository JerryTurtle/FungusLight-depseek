"""Generate the G4 campaign extension on top of the G3 slice.

This script is deterministic: it keeps N0/N1-01..N1-05 from the G3 data, rewires
N1-05 to N1-06, and appends the chapter-2/3/4 rooms, encounters, puzzles and
story metadata. Run from the repository root.
"""
from __future__ import annotations
import json
from pathlib import Path

PATH = Path("game/data/prologue.json")
d = json.loads(PATH.read_text(encoding="utf-8"))

# Remove previously generated G4 nodes/encounters/dialogues so reruns are stable.
keep = {"N0-01", "N0-02", "N0-03", "N0-04", "N1-01", "N1-02", "N1-03", "N1-04", "N1-05"}
d["nodes"] = [n for n in d["nodes"] if n["id"] in keep]
for key in [k for k in d["encounters"] if k.startswith("E12") or (k.startswith("E") and k[1:].isdigit() and int(k[1:]) >= 12)]:
    d["encounters"].pop(key, None)
for key in [k for k in d["dialogues"] if k.startswith("L") and k[1:].isdigit() and int(k[1:]) >= 5]:
    d["dialogues"].pop(key, None)

# Rewire the G3 terminal room into the G4 root bridge.
n15 = next(n for n in d["nodes"] if n["id"] == "N1-05")
for o in n15["objects"]:
    if o["id"] == "east":
        o.clear(); o.update({"id": "east", "name": "通往 根桥", "pos": [292, 130], "kind": "exit", "target": "N1-06", "requires": "E11&M2"})
n15 = next(n for n in d["nodes"] if n["id"] == "N1-05")
n15["objects"] = [o for o in n15["objects"] if o.get("id") != "m2"]
n15["objects"].append({"id": "m2", "name": "灯根 · 选择强化", "pos": [180, 140], "kind": "growth", "event": "M2", "visual": "ring"})
for decor_item in n15.get("decor", []):
    if decor_item.get("kind") == "torch" and decor_item.get("pos") == [150, 46]:
        decor_item["pos"] = [90, 46]

# G4-009 wall-overlap cleanup in two kept rooms.
n01 = next(n for n in d["nodes"] if n["id"] == "N0-01")
for decor_item in n01.get("decor", []):
    if decor_item.get("kind") == "crates" and decor_item.get("pos") in ([232, 132], [232, 150]):
        decor_item["pos"] = [190, 160]
n11 = next(n for n in d["nodes"] if n["id"] == "N1-01")
for o in n11.get("objects", []):
    if o.get("id") == "lore":
        o["pos"] = [278, 155]
n12 = next(n for n in d["nodes"] if n["id"] == "N1-02")
n12["objects"] = [o for o in n12["objects"] if o.get("id") != "q1a"]
n12["objects"].append({"id": "q1a", "name": "旧灯·导光间", "pos": [80, 140], "kind": "sidequest", "quest": "Q1", "part": "a", "visual": "chest"})
# G4-009 overlap cleanup: the guide, lore sheet, chest and torch were sharing
# the same corner of the light room. Keep each readable and walkable.
for o in n12["objects"]:
    if o.get("id") == "guide_c": o["pos"] = [265, 95]
    if o.get("id") == "lore": o["pos"] = [50, 135]
for decor_item in n12.get("decor", []):
    if decor_item.get("kind") == "torch" and decor_item.get("pos") == [150, 46]:
        decor_item["pos"] = [250, 46]
n14 = next(n for n in d["nodes"] if n["id"] == "N1-04")
n14["objects"] = [o for o in n14["objects"] if o.get("id") != "q2a"]
n14["objects"].append({"id": "q2a", "name": "补给箱单·裂口", "pos": [190, 140], "kind": "sidequest", "quest": "Q2", "part": "a", "visual": "chest"})

# Camp: make the injured NPC explicit; remove mushroom decor that reads as an NPC.
n01 = next(n for n in d["nodes"] if n["id"] == "N0-01")
n01["goal"] = "先查看床铺旁的伤员，再调查熄灭的灯座。"
n01["objects"] = [o for o in n01.get("objects", []) if o.get("id") != "wounded"]
n01["objects"].append({"id": "wounded", "name": "伤员", "pos": [152, 138], "kind": "npc", "visual": "wounded", "dialogue": "S01"})
n01["decor"] = [d for d in n01.get("decor", []) if d.get("kind") != "mushroom_red" and not (d.get("kind") == "glow_mushroom" and d.get("pos") == [120, 140])]
n01["decor"].append({"kind": "glow_mushroom", "pos": [120, 140]})
n03 = next(n for n in d["nodes"] if n["id"] == "N0-03")
n03["decor"] = [d for d in n03.get("decor", []) if d.get("kind") != "mushroom_red" and not (d.get("kind") == "glow_mushroom" and d.get("pos") == [186, 140])]
n03["decor"].append({"kind": "glow_mushroom", "pos": [186, 140]})

def room(nid, name, goal, walls, objects, *, decor=None, ambient=None, spawn=(35, 110)):
    return {"id": nid, "name": name, "style": "mine", "spawn": list(spawn), "walls": walls,
            "goal": goal, "objects": objects, "decor": decor or [], "ambient": ambient or []}

def exit_(oid, name, target, *, requires="", pos=(292, 130), kind="exit"):
    o = {"id": oid, "name": name, "pos": list(pos), "kind": kind, "target": target}
    if requires: o["requires"] = requires
    return o

def rest(pos=(55, 135), name="休息灯座 / 休息存档"):
    return {"id": "rest", "name": name, "pos": list(pos), "kind": "rest", "visual": "lamp"}

def lore(oid, name, dialogue, pos):
    return {"id": oid, "name": name, "pos": list(pos), "kind": "lore", "dialogue": dialogue}

def switch(oid, name, puzzle, flag, pos):
    return {"id": oid, "name": name, "pos": list(pos), "kind": "switch", "puzzle": puzzle, "flag": flag, "visual": "lamp"}

def story(oid, name, event, pos, dialogue=""):
    o = {"id": oid, "name": name, "pos": list(pos), "kind": "story", "event": event, "visual": "papers"}
    if dialogue: o["dialogue"] = dialogue
    return o

def growth(oid, name, event, pos):
    return {"id": oid, "name": name, "pos": list(pos), "kind": "growth", "event": event, "visual": "ring"}

def side(oid, name, quest, part, pos, dialogue=""):
    o = {"id": oid, "name": name, "pos": list(pos), "kind": "sidequest", "quest": quest, "part": part, "visual": "chest"}
    if dialogue: o["dialogue"] = dialogue
    return o

def pillars(left=True, right=True, y1=40, y2=120, h1=40, h2=40):
    w = []
    if left: w += [[100, y1, 20, h1], [100, y2, 20, h2]]
    if right: w += [[215, y1, 20, h1], [215, y2, 20, h2]]
    return w

N = []

N.append(room("N1-06", "根桥", "清掉守桥的菌群，转动桥压阀让根桥接上。",
    pillars(True, True, 40, 120, 45, 35),
    [exit_("west", "返回 灯根祭坛", "N1-05", pos=(25, 95)), rest(),
     lore("lore", "桥头记录", "L05", (150, 60)),
     story("s04", "桥头记录", "S04", (250, 140), "L05"),
     switch("v01", "桥压阀·一", "P03", "V01", (150, 100)),
     switch("v02", "桥压阀·二", "P03", "V02", (190, 100)),
     exit_("east", "通往 根桥下层", "N1-07", requires="P03")],
    decor=[{"kind":"torch","pos":[150,46]},{"kind":"torch","pos":[250,132]}],
    ambient=[{"kind":"spores","pos":[170,80]}]))

N.append(room("N2-01", "分流室", "读过分流图，进入排水入口。",
    pillars(True, True, 45, 125, 40, 30),
    [exit_("west", "返回 根桥下层", "N1-07", pos=(25, 95)), rest(),
     lore("lore", "分流图", "L06", (150, 60)),
     story("s05", "分流图前", "S05", (150, 135), "L06"),
     exit_("east", "支路 A · 排水入口", "N2-02", requires="S05", pos=(292,130)),
     exit_("north", "支路 B · 被困门外", "N2-04", pos=(250,60)),
     exit_("merge", "合流通道（需两条支路）", "N2-06", requires="P04&P05", pos=(160,80))],
    decor=[{"kind":"torch","pos":[150,46]}], ambient=[{"kind":"dust","pos":[240,120]}]))

N.append(room("N2-02", "排水入口", "关闭两道排水阀，排干前段积水。",
    pillars(True, True, 40, 120, 45, 35),
    [exit_("west", "返回 分流室", "N2-01", pos=(25, 95)), rest(),
     switch("v03", "排水阀·一", "P04", "V03", (145, 100)),
     switch("v04", "排水阀·二", "P04", "V04", (190, 100)),
     exit_("east", "通往 排水出口", "N2-03", requires="P04")],
    decor=[{"kind":"torch","pos":[246,46]}], ambient=[{"kind":"drip","pos":[150,90]}]))

N.append(room("N2-03", "排水出口", "确认排水完成，检查旧灯。",
    pillars(True, True, 45, 120, 40, 35),
    [exit_("west", "返回 分流室", "N2-01", pos=(25, 95)), rest(),
     lore("lamp", "旧灯·排水口", "L07", (150, 60)),
     side("q1b", "旧灯修复·排水口", "Q1", "b", (150, 140))],
    decor=[{"kind":"torch","pos":[250,46]}], ambient=[{"kind":"light_pool","pos":[150,60]}]))

N.append(room("N2-04", "被困门外", "从安全侧清除污染根，打开门。",
    pillars(True, True, 40, 125, 40, 30),
    [exit_("west", "返回 分流室", "N2-01", pos=(25, 95)), rest(),
     switch("v05", "污染根阀·一", "P05", "V05", (145, 100)),
     switch("v06", "污染根阀·二", "P05", "V06", (190, 100)),
     exit_("east", "通往 安全旁室", "N2-05", requires="P05")],
    decor=[{"kind":"torch","pos":[150,46]}], ambient=[{"kind":"spores","pos":[180,80]}]))

N.append(room("N2-05", "安全旁室", "砾留在旁室；检查另一出口。",
    pillars(True, True, 45, 120, 40, 35),
    [exit_("west", "返回 被困门外", "N2-04", pos=(25, 95)), rest(),
     lore("lore", "砾的留条", "L08", (150, 60)),
     side("q2b", "补给箱单·旁室", "Q2", "b", (150, 140)),
     exit_("east", "返回 分流室", "N2-01", pos=(292,130))],
    decor=[{"kind":"torch","pos":[250,46]}], ambient=[{"kind":"dust","pos":[250,120]}]))

N.append(room("N2-06", "合流通道", "两条水路都合到这里；清开通道。",
    pillars(True, True, 40, 125, 45, 30),
    [exit_("west", "返回 分流室", "N2-01", pos=(25, 95)), rest(),
     story("s06", "合流标记", "S06", (150, 135), "L09"),
     exit_("east", "通往 泵站守卫", "N2-07", requires="S06")],
    decor=[{"kind":"torch","pos":[150,46]},{"kind":"torch","pos":[250,132]}], ambient=[{"kind":"drip","pos":[200,100]}]))

N.append(room("N2-07", "泵站守卫", "击破泵站守卫，打开控制室。",
    pillars(True, True, 45, 120, 40, 35),
    [exit_("west", "返回 合流通道", "N2-06", pos=(25, 95)), rest(),
     exit_("east", "通往 泵站回廊", "N2-09", requires="E19")],
    decor=[{"kind":"torch","pos":[150,46]}], ambient=[{"kind":"light_pool","pos":[250,90]}]))

N.append(room("N2-08", "控制室 / 试验段", "启动储水，校准灯雨；选择第三次强化。",
    pillars(True, True, 40, 120, 45, 35),
    [exit_("west", "返回 泵站回廊", "N2-09", pos=(25, 95)), rest(),
     lore("lore", "抽水记录", "L10", (150, 60)),
     story("s07", "抽水记录前", "S07", (170, 140), "L10"),
     switch("v07", "稳压阀·一", "P06", "V07", (145, 100)),
     switch("v08", "稳压阀·二", "P06", "V08", (190, 100)),
     side("q2c", "补给箱单·控制室", "Q2", "c", (250, 140)),
     growth("m3", "控制室 · 选择强化", "M3", (180, 140)),
     exit_("east", "通往 试验段外廊", "N2-10", requires="M3&P06")],
    decor=[{"kind":"torch","pos":[250,46]}], ambient=[{"kind":"spores","pos":[180,80]}]))

N.append(room("N3-01", "王庭外环", "观察根与管的连接，沿清晰通路前进。",
    pillars(True, True, 45, 120, 40, 35),
    [exit_("west", "返回 试验段外廊", "N2-10", pos=(25, 95)), rest(),
     story("s08", "王庭外环", "S08", (150, 135), "L11"),
     exit_("east", "通往 供给回廊", "N3-02", requires="S08")],
    decor=[{"kind":"torch","pos":[90,46]},{"kind":"glow_mushroom","pos":[245,70]}], ambient=[{"kind":"dust","pos":[240,120]}]))

N.append(room("N3-02", "供给回廊", "扫描前两处供给点，打开回廊。",
    pillars(True, True, 40, 125, 45, 30),
    [exit_("west", "返回 王庭外环", "N3-01", pos=(25, 95)), rest(),
     switch("v09", "供给阀·一", "P07", "V09", (140, 100)),
     switch("v10", "供给阀·二", "P07", "V10", (180, 100)),
     switch("v11", "供给阀·三", "P07", "V11", (205, 100)),
     side("q1c", "旧灯修复·供给回廊", "Q1", "c", (90, 140)),
     exit_("east", "通往 旧约墙", "N3-03", requires="P07")],
    decor=[{"kind":"torch","pos":[250,46]}], ambient=[{"kind":"light_pool","pos":[150,100]}]))

N.append(room("N3-03", "旧约墙", "取得旧约拓文，沿墙后通道前进。",
    pillars(True, True, 45, 120, 40, 35),
    [exit_("west", "返回 供给回廊", "N3-02", pos=(25, 95)), rest(),
     lore("lore", "旧约拓文", "L12", (150, 60)),
     exit_("east", "通往 王庭侧廊", "N3-07")],
    decor=[{"kind":"torch","pos":[150,46]}], ambient=[{"kind":"spores","pos":[200,90]}]))

N.append(room("N3-04", "王庭前厅", "清掉前厅的两段守卫，进入安全王庭。",
    pillars(True, True, 40, 125, 45, 30),
    [exit_("west", "返回 王庭侧廊", "N3-07", pos=(25, 95)), rest(),
     exit_("east", "通往 王庭安全区", "N3-05", requires="E25")],
    decor=[{"kind":"torch","pos":[150,46]},{"kind":"torch","pos":[250,132]}], ambient=[{"kind":"dust","pos":[240,120]}]))

N.append(room("N3-05", "王庭安全区", "完成旧约校准，选择最后的强化。",
    pillars(True, True, 45, 120, 40, 35),
    [exit_("west", "返回 王庭前厅", "N3-04", pos=(25, 95)), rest(),
     lore("lore", "菌王的留声", "L13", (150, 60)),
     switch("v12", "旧约阀·一", "P08", "V12", (145, 100)),
     switch("v13", "旧约阀·二", "P08", "V13", (190, 100)),
     growth("m4", "王庭 · 选择强化", "M4", (180, 140)),
     exit_("east", "通往 回流桥", "N3-06", requires="M4&P08")],
    decor=[{"kind":"torch","pos":[250,46]}], ambient=[{"kind":"light_pool","pos":[150,60]}]))

N.append(room("N3-06", "回流桥", "用最后的强化清开回流桥。",
    pillars(True, True, 40, 125, 45, 30),
    [exit_("west", "返回 王庭安全区", "N3-05", pos=(25, 95)), rest(),
     exit_("east", "通往 调压前厅", "N3-08", requires="E26")],
    decor=[{"kind":"torch","pos":[150,46]}], ambient=[{"kind":"drip","pos":[220,100]}]))

N.append(room("N4-01", "调压入口", "读取主流向，开始调压。",
    pillars(True, True, 45, 120, 40, 35),
    [exit_("west", "返回 调压前厅", "N3-08", pos=(25, 95)), rest(),
     switch("v14", "调压阀·一", "P09", "V14", (150, 100)),
     exit_("east", "通往 调压中段", "N4-02")],
    decor=[{"kind":"torch","pos":[250,46]}], ambient=[{"kind":"light_pool","pos":[150,100]}]))

N.append(room("N4-02", "调压中段", "切换支路，稳定中段压力。",
    pillars(True, True, 40, 125, 45, 30),
    [exit_("west", "返回 调压入口", "N4-01", pos=(25, 95)), rest(),
     switch("v15", "调压阀·二", "P09", "V15", (150, 100)),
     exit_("east", "通往 稳压台", "N4-03")],
    decor=[{"kind":"torch","pos":[150,46]}], ambient=[{"kind":"dust","pos":[240,120]}]))

N.append(room("N4-03", "稳压台", "稳定压力，打开核心外廊。",
    pillars(True, True, 45, 120, 40, 35),
    [exit_("west", "返回 调压中段", "N4-02", pos=(25, 95)), rest(),
     switch("v16", "调压阀·三", "P09", "V16", (150, 100)),
     exit_("east", "通往 核心外廊", "N4-04", requires="P09")],
    decor=[{"kind":"torch","pos":[250,46]}], ambient=[{"kind":"light_pool","pos":[150,100]}]))

N.append(room("N4-04", "核心外廊", "穿过最后两段战前压力。",
    pillars(True, True, 40, 125, 45, 30),
    [exit_("west", "返回 稳压台", "N4-03", pos=(25, 95)), rest(),
     exit_("east", "通往 最后灯座", "N4-05", requires="E29")],
    decor=[{"kind":"torch","pos":[150,46]},{"kind":"glow_mushroom","pos":[250,90]}], ambient=[{"kind":"spores","pos":[200,80]}]))

N.append(room("N4-05", "最后灯座", "检查配置、保存，确认进入核心室。",
    pillars(True, True, 45, 120, 40, 35),
    [exit_("west", "返回 核心外廊", "N4-04", pos=(25, 95)), rest(),
     story("s09", "最后灯座", "S09", (150, 60), "L14"),
     exit_("east", "进入 核心室", "N4-06", requires="S09")],
    decor=[{"kind":"torch","pos":[150,46]}], ambient=[{"kind":"light_pool","pos":[150,60]}]))

N.append(room("N4-06", "核心室", "压制母体，然后选择灯根的去向。",
    pillars(True, True, 40, 130, 40, 25),
    [exit_("west", "撤离核心室", "N4-05", pos=(25, 95)), rest(),
     {"id":"ending", "name": "灯根核心 / 做出选择", "pos": [150, 100], "kind": "ending", "visual": "portal"},
     exit_("east", "通往 尾声", "N4-07", requires="S11")],
    decor=[{"kind":"torch","pos":[150,46]},{"kind":"torch","pos":[250,132]}], ambient=[{"kind":"light_pool","pos":[230,140]}]))

N.append(room("N4-07", "尾声", "灯根的选择已经写下。",
    pillars(True, True, 45, 120, 40, 35),
    [{"id": "credits", "name": "回看这段路", "pos": [160, 90], "kind": "credits"}],
    decor=[{"kind":"torch","pos":[150,46]}], ambient=[{"kind":"light_pool","pos":[160,90]}]))

N.append(room("N1-07", "根桥下层", "穿过根桥下的旧支撑，清掉盘踞的菌群。",
    pillars(True, True, 45, 120, 40, 35),
    [exit_("west", "返回 根桥", "N1-06", pos=(25, 95)), rest(),
     lore("lore", "支撑刻记", "L15", (150, 60)),
     exit_("east", "北侧分流门 通往 分流室", "N2-01", requires="E31", pos=(160, 65))],
    decor=[{"kind":"torch","pos":[150,46]},{"kind":"torch","pos":[250,132]}], ambient=[{"kind":"drip","pos":[190,100]}]))

N.append(room("N2-09", "泵站回廊", "沿回廊检查泵站管线，清掉守卫。",
    pillars(True, True, 40, 125, 45, 30),
    [exit_("west", "返回 泵站守卫", "N2-07", pos=(25, 95)), rest(),
     lore("lore", "泵站管线", "L16", (150, 60)),
     exit_("east", "回廊下行 通往 控制室", "N2-08", requires="E32", pos=(160, 145))],
    decor=[{"kind":"torch","pos":[250,46]}], ambient=[{"kind":"light_pool","pos":[150,100]}]))

N.append(room("N3-07", "王庭侧廊", "从侧廊绕到王庭前厅，避开正门的根刺。",
    pillars(True, True, 45, 120, 40, 35),
    [exit_("west", "返回 旧约墙", "N3-03", pos=(25, 95)), rest(),
     lore("lore", "侧廊壁画", "L17", (150, 60)),
     exit_("east", "北侧门 通往 王庭前厅", "N3-04", requires="E33", pos=(160, 65))],
    decor=[{"kind":"torch","pos":[150,46]},{"kind":"glow_mushroom","pos":[250,90]}], ambient=[{"kind":"spores","pos":[180,80]}]))

N.append(room("N2-10", "试验段外廊", "沿试验段外廊进入王庭；清掉最后的泵站菌群。",
    pillars(True, True, 45, 120, 40, 35),
    [exit_("west", "返回 控制室", "N2-08", pos=(25, 95)), rest(),
     lore("lore", "试验段记录", "L18", (150, 60)),
     exit_("east", "北侧根门 通往 王庭外环", "N3-01", requires="E34", pos=(160, 65))],
    decor=[{"kind":"torch","pos":[250,46]}], ambient=[{"kind":"spores","pos":[180,80]}]))

N.append(room("N1-08", "菌灯井", "绕过菌灯井的旧井架，清掉最后的裂口菌群。",
    pillars(True, True, 45, 120, 40, 35),
    [exit_("west", "返回 菌根裂口", "N1-04", pos=(25, 95)), rest(),
     lore("lore", "井架刻记", "L19", (150, 60)),
     exit_("east", "北侧灯道 通往 灯根祭坛", "N1-05", requires="E35", pos=(160, 65))],
    decor=[{"kind":"torch","pos":[150,46]}], ambient=[{"kind":"light_pool","pos":[180,100]}]))

N.append(room("N3-08", "调压前厅", "穿过王庭最后的根门，检查调压管路。",
    pillars(True, True, 45, 120, 40, 35),
    [exit_("west", "返回 回流桥", "N3-06", pos=(25, 95)), rest(),
     lore("lore", "调压前厅记录", "L20", (150, 60)),
     exit_("east", "通往 调压入口", "N4-01", requires="E36")],
    decor=[{"kind":"torch","pos":[150,46]}], ambient=[{"kind":"drip","pos":[200,100]}]))

# G4-009 overlap cleanup for the generated rooms. The old template stacked the
# lore sheet under the centre torch and, in the central-exit rooms, directly on
# top of the exit portal. Move the torch off the centre line and separate the
# few authored story/record props from torches and growth rings.
for n in N:
    lore_spot = {"N1-07":[150,140], "N1-08":[150,140], "N2-01":[252,140], "N2-10":[252,140], "N3-07":[252,140]}
    for o in n["objects"]:
        if o.get("id") == "lore" and n["id"] in lore_spot:
            o["pos"] = lore_spot[n["id"]]
        if n["id"] == "N1-06" and o.get("id") == "s04":
            o["pos"] = [250, 140]
        if n["id"] == "N2-08" and o.get("id") == "s07":
            o["pos"] = [80, 60]
    for decor_item in n.get("decor", []):
        if decor_item.get("kind") == "torch" and decor_item.get("pos") == [150, 46]:
            decor_item["pos"] = [90, 46]
        if n["id"] == "N1-06" and decor_item.get("kind") == "torch" and decor_item.get("pos") == [250, 132]:
            decor_item["pos"] = [270, 46]

d["nodes"].extend(N)

# Story / growth / ending metadata.
d["chapters"] = [
    {"id": "prologue", "name": "序章", "nodes": ["N0-01","N0-02","N0-03","N0-04"]},
    {"id": "chapter1", "name": "第一章 · 断根", "nodes": ["N1-01","N1-02","N1-03","N1-04","N1-08","N1-05","N1-06","N1-07"]},
    {"id": "chapter2", "name": "第二章 · 排水", "nodes": ["N2-01","N2-02","N2-03","N2-04","N2-05","N2-06","N2-07","N2-08","N2-09","N2-10"]},
    {"id": "chapter3", "name": "第三章 · 王庭", "nodes": ["N3-01","N3-02","N3-03","N3-04","N3-05","N3-06","N3-07","N3-08"]},
    {"id": "finale", "name": "终章 · 灯根", "nodes": ["N4-01","N4-02","N4-03","N4-04","N4-05","N4-06","N4-07"]},
]
d["events"] = {
    "S01": {"node": "N0-01", "requires": []},
    "S02": {"node": "N0-02", "requires": ["P01"]},
    "M1": {"node": "N0-02", "requires": ["E01", "S02"], "title": "初燃 · 选择一项强化",
           "options": [{"id":"melee","label":"灯击伤害 +15%","desc":"18 → 21"},
                       {"id":"light","label":"净光伤害 +15%","desc":"24 → 28"}]},
    "S03": {"node": "N0-03", "requires": ["pipe"]},
    "S04": {"node": "N1-06", "requires": []},
    "S05": {"node": "N2-01", "requires": []},
    "S06": {"node": "N2-06", "requires": []},
    "S07": {"node": "N2-08", "requires": ["E20"]},
    "S08": {"node": "N3-01", "requires": []},
    "S09": {"node": "N4-05", "requires": ["E29"]},
    "S10": {"node": "N4-06", "requires": ["E30"]},
    "S11": {"node": "N4-06", "requires": ["S10"]},
    "S12": {"node": "N4-07", "requires": ["S11"]},
    "M2": {"node": "N1-05", "requires": ["E11"], "title": "回响 · 选择一项强化（生命上限120→140）",
           "options": [{"id":"echo","label":"回响范围 +20%","desc":"Q 扫描半径 80 → 96"},
                       {"id":"guard","label":"护灯上限 +20%","desc":"护盾值 40 → 48"}]},
    "M3": {"node": "N2-08", "requires": ["E20"], "title": "灯雨 · 选择一项强化（生命上限140→160）",
           "options": [{"id":"rain","label":"灯雨伤害 +15%","desc":"24 → 28"},
                       {"id":"focus","label":"专注回复 +20%","desc":"专注回复 8 → 10"}]},
    "M4": {"node": "N3-05", "requires": ["P08"], "title": "澄明 · 选择一项强化（生命上限160→180）",
           "options": [{"id":"ward","label":"护盾反伤 +2","desc":"破盾时对周围造成伤害"},
                       {"id":"step","label":"闪避冷却 -15%","desc":"闪避冷却 0.8s → 0.68s"}]},
}
d["puzzles"] = {
    "P01": {"node": "N0-02", "flags": ["core","P01"]},
    "P02": {"node": "N1-02", "flags": []},
    "P03": {"node": "N1-06", "flags": ["V01","V02"]},
    "P04": {"node": "N2-02", "flags": ["V03","V04"]},
    "P05": {"node": "N2-04", "flags": ["V05","V06"]},
    "P06": {"node": "N2-08", "flags": ["V07","V08"]},
    "P07": {"node": "N3-02", "flags": ["V09","V10","V11"]},
    "P08": {"node": "N3-05", "flags": ["V12","V13"]},
    "P09": {"node": "N4-03", "flags": ["V14","V15","V16"]},
}
d["sidequests"] = {
    "Q1": {"name": "旧灯修复", "parts": ["a","b","c"], "reward": "澄明镜"},
    "Q2": {"name": "补给调查", "parts": ["a","b","c"], "reward": "余温符"},
}

# Encounters: E12-E29 normal, E30 Boss (E01-E11 stay from G3).
enc = {
    "E12": ("N1-06", [[180,80]], [["T4",220,90]], "E11", ""),
    "E13": ("N2-01", [[180,120]], [["T2",220,90]], "S05", ""),
    "E14": ("N2-02", [[180,110]], [["T3",230,90]], "", "排水暂时安静，但菌群仍在移动。"),
    "E15": ("N2-03", [[180,80]], [["T3",230,100],["T5",230,115]], "E14", ""),
    "E16": ("N2-04", [[180,90]], [["T1",220,80],["T2",250,110]], "S05", ""),
    "E17": ("N2-05", [[180,100]], [["T3",230,90]], "E16", ""),
    "E18": ("N2-06", [[180,80]], [["T2",230,90],["T3",255,110]], "S06", ""),
    "E19": ("N2-07", [], [["EL2",235,90]], "E18", "泵站守卫倒下，控制室的门开了。"),
    "E20": ("N2-08", [[180,80]], [["T1",220,100]], "E19", ""),
    "E21": ("N3-01", [[180,90]], [["T4",230,80],["T2",255,120]], "S08", ""),
    "E22": ("N3-02", [[180,80]], [["T2",230,90],["T5",255,120]], "E21", ""),
    "E23": ("N3-03", [[180,80]], [["T4",230,90],["T3",255,120]], "P07", ""),
    "E24": ("N3-04", [[180,100]], [["T6",230,80],["T1",180,130]], "S08", ""),
    "E25": ("N3-04", [[180,80]], [["T4",230,110],["T2",255,90]], "E24", "前厅安静下来，安全王庭的门开了。"),
    "E26": ("N3-06", [[180,80]], [["T3",230,90],["T6",255,120]], "M4", ""),
    "E27": ("N4-01", [[180,120]], [["T4",230,90],["T1",255,120]], "E26", ""),
    "E28": ("N4-02", [[160,80]], [["T2",190,90]], "E27", ""),
    "E29": ("N4-03", [[180,80]], [["T4",230,100],["T6",255,120]], "E28", "稳压完成，核心外廊打开。"),
    "E31": ("N1-07", [[170,80]], [["T1",220,90],["T2",250,120]], "P03", ""),
    "E32": ("N2-09", [[170,100]], [["T2",230,90],["T3",255,120]], "E19", ""),
    "E33": ("N3-07", [[170,110]], [["T4",235,90],["T2",260,120]], "P07", ""),
    "E34": ("N2-10", [[170,100]], [["T3",230,90],["T5",255,120]], "M3", ""),
    "E35": ("N1-08", [[170,100]], [["T1",220,90],["T2",250,120]], "E10", ""),
    "E36": ("N3-08", [[170,100]], [["T2",230,90],["T3",255,120]], "E26", ""),
    "E30": ("N4-06", [], [["BOSS",175,105]], "S09", "母体被压制，灯根核心暴露。"),
}
for eid, (node, positions, members, requires, notice) in enc.items():
    spec = {"node": node, "positions": positions, "members": members, "requires": requires}
    if eid == "E30": spec["boss"] = True
    if eid == "E19": spec["hp_mult"] = 0.25
    if eid in ["E24","E25"]: spec["hp_mult"] = 0.55
    if eid in ["E26","E27","E28","E29"]: spec["hp_mult"] = 0.4
    if notice: spec["clear_notice"] = notice
    d["encounters"][eid] = spec

# Dialogues L05-L14 (short, two speakers; placeholders with real beats).
D = {
    "L05": [["岚","根桥的纤维在动。桥压阀被缠住了。"],["岚","把两处阀门都转开，桥面才会接上。"]],
    "L06": [["岚","分流图把上下两条水路画得很清楚。"],["岚","先去排水入口；另一条路等这边稳定再说。"]],
    "L07": [["岚","旧灯的灯芯还在，只是被水泡过。"],["岚","把三处旧灯都修好，也许能换一件护具。"]],
    "L08": [["砾","我没事，只是腿被压住了。"],["砾","你别管我，另一侧的出口更重要。"]],
    "L09": [["岚","两条水路在这里合流。"],["岚","前面的泵站有重甲守卫，准备好再进去。"]],
    "L10": [["岚","抽水记录停在一个不自然的刻度。"],["岚","有人提前把水放干了——和绒说的一样。"]],
    "L11": [["岚","王庭的根须是从这里接上管道的。"],["岚","不是寄生，更像是某种很久以前的约定。"]],
    "L12": [["岚","旧约拓文：灯与根，共享同一口水。"],["岚","如果这是真的，母体也许并不只是敌人。"]],
    "L13": [["菌王","你们终于走到这里了。"],["菌王","灯根的选择不该由一个人决定——但门已经为你打开。"]],
    "L14": [["岚","最后一段路。灯根就在门后。"],["岚","检查装备，保存；进去以后就没有回头路了。"]],
    "L15": [["岚","根桥下的旧支撑还在响。"],["岚","清掉下面盘踞的菌群，分流室的路才会露出来。"]],
    "L16": [["岚","泵站回廊的管线比上面更旧。"],["岚","控制室就在前面；先处理守卫。"]],
    "L17": [["岚","侧廊壁画上，灯根和菌王坐在同一张桌旁。"],["岚","……也许旧约不是传说。"]],
    "L18": [["岚","试验段外廊把泵站和王庭接在一起。"],["岚","清掉最后一层菌群，王庭就在前面。"]],
    "L19": [["岚","菌灯井的旧架还在，井底已经不流水了。"],["岚","清掉周围的菌群，灯根祭坛就在前面。"]],
    "L20": [["岚","调压前厅的根门已经打开。"],["岚","进去就是核心外廊；检查一下药剂和专注。"]],
}
d["dialogues"].update(D)
d["build_id"] = "G6-001"
d["chapter_id"] = "campaign"
PATH.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
print("nodes", len(d["nodes"]), [n["id"] for n in d["nodes"]])
print("encounters", len(d["encounters"]), list(d["encounters"]))
