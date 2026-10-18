extends RefCounted
## Serializable prologue progression. Rendering and input cannot award rewards directly.
const Store = preload("res://scripts/save_store.gd")
const FLAGS := ["S01","core","P01","S02","tutorial","E01","M1","pipe","S03","E02","E03","E04","E05","E06","P02","E07","E08"]
const ENCOUNTERS := ["tutorial","E01","E02","E03","E04","E05","E06","E07","E08"]
const DEPENDENCIES := {"core":"S01","P01":"core","S02":"P01","tutorial":"S02","E01":"tutorial","M1":"E01","pipe":"M1","S03":"pipe","E02":"S03","E03":"E02","E04":"E03","E05":"E04","E06":"E05","P02":"E06","E07":"P02","E08":"E07"}
const GATES := {"N0-02":"S01","N0-03":"M1","N0-04":"S03","N1-01":"E03","N1-02":"E04","N1-03":"P02"}
var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/prologue.json"))
var node_id := "N0-01"
var flags: Dictionary = {}
var choice := ""
var seconds := 0.0
var potions := 3
var active_event := ""

func node(id: String = "") -> Dictionary:
	for entry in content.nodes:
		if entry.id == (node_id if id.is_empty() else id): return entry
	return {}

func has(id: String) -> bool:
	return bool(flags.get(id,false))

func can_event(id: String) -> bool:
	if not active_event.is_empty() or has(id): return false
	match id:
		"S01": return node_id == "N0-01"
		"S02": return node_id == "N0-02" and has("P01")
		"M1": return node_id == "N0-02" and has("E01") and has("S02")
		"S03": return node_id == "N0-03" and has("pipe")
	return false

func start_event(id: String) -> bool:
	if not can_event(id): return false
	active_event = id
	return true

func finish_event(option: String = "") -> bool:
	if active_event.is_empty(): return false
	if active_event == "M1":
		if option not in ["melee","light"]: return false
		choice = option
	flags[active_event] = true
	active_event = ""
	return true

func apply_interaction(kind: String, scanned: bool = false) -> String:
	if not active_event.is_empty(): return "先完成当前对话。"
	match kind:
		"chest":
			if node_id != "N0-02": return "此处没有灯芯。"
			if has("core"): return "箱子已经空了，把灯芯装入出口灯座。"
			flags.core = true
			return "取得备用灯芯。靠近出口灯座按 E 装入。"
		"socket":
			if node_id != "N0-02" or not has("core"): return "灯座缺少灯芯，先找储藏箱。"
			flags.P01 = true
			return "备用芯已装好，出口灯线复亮。"
		"pipe":
			if node_id != "N0-03" or not scanned: return "按 Q 观察旧水管，再按 E 调查刻痕。"
			flags.pipe = true
			return "证据：刻痕一格格下降，说明水位在袭击之前已经降低。去问绒。"
	return ""

func guides(id: String = "") -> Array:
	var found: Array = []
	for object in node(id).objects:
		if object.kind == "guide": found.append(object)
	return found

func guide_targets(id: String = "") -> Array:
	var found: Array = []
	for object in node(id).objects:
		if object.kind == "guide_target": found.append(object)
	return found

func max_hp() -> float:
	return 120.0 if has("M1") else 100.0

func skills() -> Dictionary:
	return {"light":has("S02"),"shield":false,"rain":false}

func snapshot(position: Vector2, health: float, focus: float) -> Dictionary:
	var encounters := {}
	for id in ENCOUNTERS: encounters[id] = has(id)
	return {"schema_version":1,"build_id":"G3-011","chapter_id":"prologue","node_id":node_id,
		"safe_position":[position.x,position.y],"health":health,"focus":focus,"potions":potions,"effective_seconds":seconds,
		"quests":{},"story":flags.duplicate(true),"puzzles":{"P01":has("P01"),"P02":has("P02")},"encounters":encounters,
		"rewards":{"M1":has("M1")},"skills":skills(),"upgrades":{"M1":choice},"equipment":{"charm":"guardian_knot" if has("M1") else ""}}

func validate(value: Dictionary) -> String:
	var error := Store.validate_snapshot(value)
	if not error.is_empty(): return error
	if value.chapter_id != "prologue" or node(str(value.node_id)).is_empty(): return "存档章节或节点未知。"
	var f: Dictionary = value.story
	if not value.quests.is_empty() or value.encounters.size() != ENCOUNTERS.size() or value.upgrades.size() != 1: return "存档包含当前版本未知的进度字段。"
	for key in f:
		if key not in FLAGS or not f[key] is bool: return "进度标记无效。"
	for key in DEPENDENCIES:
		if f.get(key,false) and not f.get(DEPENDENCIES[key],false): return "进度顺序不一致。"
	if GATES.has(value.node_id) and not f.get(GATES[value.node_id],false): return "节点尚未解锁。"
	var selected = value.upgrades.get("M1")
	if (f.get("M1",false) and selected not in ["melee","light"]) or (not f.get("M1",false) and selected != ""): return "强化选择无效。"
	var expected := {"M1":bool(f.get("M1",false))}
	if value.rewards != expected or value.skills != {"light":bool(f.get("S02",false)),"shield":false,"rain":false}: return "奖励或技能不一致。"
	if value.puzzles != {"P01":bool(f.get("P01",false)),"P02":bool(f.get("P02",false))}: return "机关状态不一致。"
	for key in ENCOUNTERS:
		if value.encounters.get(key) != f.get(key,false): return "遭遇状态不一致。"
	if value.equipment != {"charm":"guardian_knot" if f.get("M1",false) else ""}: return "装备状态不一致。"
	if value.health > (120 if f.get("M1",false) else 100) or value.focus > 100: return "资源超过当前上限。"
	var position := Vector2(value.safe_position[0],value.safe_position[1])
	if not Rect2(14,35,292,117).has_point(position): return "安全位置超出地图。"
	for wall in node(value.node_id).walls:
		if Rect2(wall[0],wall[1],wall[2],wall[3]).grow(5).has_point(position): return "安全位置位于墙内。"
	if not validate_puzzles(): return "机关数据无效。"
	return ""

func validate_puzzles() -> bool:
	for entry in content.nodes:
		var seen := {}
		for object in entry.objects:
			if object.kind == "guide":
				if not object.has("solution") or int(object.solution) < 0 or int(object.solution) > 3: return false
				if not object.has("dir") or int(object.dir) < 0 or int(object.dir) > 3: return false
				var target = object.get("target")
				if not target is Array or target.size() != 2: return false
				seen[object.id] = true
		if entry.id == "N1-02" and (seen.size() != 3 or entry.objects.filter(func(o): return o.kind == "guide_target").size() != 3): return false
	return true

func restore(value: Dictionary) -> bool:
	if not validate(value).is_empty(): return false
	node_id = value.node_id
	flags = value.story.duplicate(true)
	choice = value.upgrades.M1
	seconds = float(value.effective_seconds)
	potions = int(value.potions)
	active_event = ""
	return true
