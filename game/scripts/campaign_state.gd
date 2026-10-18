extends RefCounted
## G4 campaign progression. Story, encounters, puzzles, rewards, skills,
## upgrades, equipment and endings are all stable IDs; rendering never awards
## anything without going through this object.
const Store = preload("res://scripts/save_store.gd")

var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/prologue.json"))
var node_id := "N0-01"
var flags: Dictionary = {}
var choices: Dictionary = {}
var choice := "" ## M1 compatibility; mirrored with choices.M1.
var seconds := 0.0
var potions := 3
var active_event := ""

var flag_ids: Array = []
var encounter_ids: Array = []
var puzzle_ids: Array = []
var reward_ids: Array = ["M1", "M2", "M3", "M4", "Q1", "Q2"]
var choice_ids: Array = ["M1", "M2", "M3", "M4"]
var skill_ids: Array = ["light", "shield", "rain"]
var equipment_ids: Array = ["charm", "lens", "focus", "ward", "relic", "token"]
var quest_ids: Array = ["Q1", "Q2"]

func _init() -> void:
	_build_ids()

func _build_ids() -> void:
	flag_ids.clear()
	var seen := {}
	for key in ["S01","S02","S03","S04","S05","S06","S07","S08","S09","S10","S11","S12",
			"M1","M2","M3","M4","core","P01","P02","P03","P04","P05","P06","P07","P08","P09",
			"pipe","tutorial","END_RESTORE","END_SEAL"]:
		if not seen.has(key): seen[key] = true; flag_ids.append(key)
	for id in content.get("events", {}).keys():
		if not seen.has(id): seen[id] = true; flag_ids.append(id)
	for id in content.get("encounters", {}).keys():
		if not seen.has(id): seen[id] = true; flag_ids.append(id)
	for id in content.get("puzzles", {}).keys():
		if not seen.has(id): seen[id] = true; flag_ids.append(id)
		for part in content.puzzles[id].get("flags", []):
			if not seen.has(part): seen[part] = true; flag_ids.append(part)
	for id in content.get("sidequests", {}).keys():
		if not seen.has(id): seen[id] = true; flag_ids.append(id)
		for part in content.sidequests[id].get("parts", []):
			var key: String = str(id) + str(part)
			if not seen.has(key): seen[key] = true; flag_ids.append(key)
	encounter_ids = content.get("encounters", {}).keys()
	puzzle_ids = content.get("puzzles", {}).keys()

func node(id: String = "") -> Dictionary:
	for entry in content.nodes:
		if entry.id == (node_id if id.is_empty() else id): return entry
	return {}

func has(id: String) -> bool:
	return bool(flags.get(id,false))

func event_def(id: String) -> Dictionary:
	return content.get("events", {}).get(id, {})

func can_event(id: String) -> bool:
	if not active_event.is_empty() or has(id): return false
	var def := event_def(id)
	if def.is_empty() or str(def.get("node", "")) != node_id: return false
	for req in def.get("requires", []):
		if not has(str(req)): return false
	return true

func start_event(id: String) -> bool:
	if not can_event(id): return false
	active_event = id
	return true

func event_options(id: String) -> Array:
	return event_def(id).get("options", [])

func finish_event(option: String = "") -> bool:
	if active_event.is_empty(): return false
	var def := event_def(active_event)
	var opts: Array = def.get("options", [])
	if not opts.is_empty():
		var valid := false
		for item in opts:
			if str(item.get("id", "")) == option: valid = true
		if not valid: return false
		choices[active_event] = option
		if active_event == "M1": choice = option
	flags[active_event] = true
	active_event = ""
	return true

func set_switch(object: Dictionary) -> String:
	var flag := str(object.get("flag", ""))
	var puzzle := str(object.get("puzzle", ""))
	if flag.is_empty() or not content.get("puzzles", {}).has(puzzle): return "阀门数据无效。"
	if has(flag): return "这道阀门已经打开了。"
	flags[flag] = true
	var parts: Array = content.puzzles[puzzle].get("flags", [])
	var complete := true
	for part in parts:
		if not has(str(part)): complete = false
	if complete:
		flags[puzzle] = true
		return "阀门全部打开，灯线接通。"
	return "阀门打开：%d / %d。" % [parts.filter(func(p): return has(str(p))).size(), parts.size()]

func sidequest(quest: String, part: String) -> String:
	var def: Dictionary = content.get("sidequests", {}).get(quest, {})
	if def.is_empty() or not part in def.get("parts", []): return "这里的线索无法记录。"
	var key := quest + part
	flags[key] = true
	var complete := true
	for item in def.parts:
		if not has(quest + str(item)): complete = false
	if complete and not has(quest):
		flags[quest] = true
		return "%s 完成，取得 %s。" % [def.name, def.reward]
	return "记录 %s：%d / %d。" % [def.name, def.parts.filter(func(p): return has(quest + str(p))).size(), def.parts.size()]

func set_ending(kind: String) -> void:
	if kind not in ["restore", "seal"]: return
	flags["END_RESTORE" if kind == "restore" else "END_SEAL"] = true
	flags["S10"] = true
	flags["S11"] = true

func ending_id() -> String:
	if has("END_RESTORE"): return "restore"
	if has("END_SEAL"): return "seal"
	return ""

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

func growth_count() -> int:
	var count := 0
	for id in ["M1","M2","M3","M4"]:
		if has(id): count += 1
	return count

func max_hp() -> float:
	return max_hp_for(flags, choices)

func max_focus() -> float:
	return max_focus_for(flags, choices)

func skills() -> Dictionary:
	# Shield is unlocked in the first chapter before the gatekeeper, as in the
	# plan's first-chapter rest point (P02 is the last safe stop before E07/E08).
	return {"light":has("S02"), "shield":has("P02"), "rain":has("M3")}

func melee_damage() -> float:
	var damage := 18.0
	if choices.get("M1", "") == "melee": damage += 3.0
	return damage

func light_damage() -> float:
	var damage := 24.0
	if choices.get("M1", "") == "light": damage += 4.0
	return damage

func rain_damage() -> float:
	var damage := 45.0
	if choices.get("M3", "") == "rain": damage *= 1.25
	return damage

func light_cost() -> int:
	var cost := 20
	if choices.get("M3", "") == "cost": cost -= 5
	return maxi(5,cost)

func hit_focus_gain() -> int:
	return 6 if choices.get("M2", "") == "energy" else 4

func shield_capacity() -> int:
	return 35 if choices.get("M2", "") == "shield" else 25

func evidence() -> Dictionary:
	# The three mainline evidence items are carried by the event flags, so old
	# saves do not need new fields. A player who skipped the story object cannot
	# unlock the final choice.
	return {
		"root_cut": has("S04"),
		"pump_record": has("S07"),
		"covenant": has("S08"),
	}

func evidence_count() -> int:
	var count := 0
	for value in evidence().values():
		if bool(value): count += 1
	return count

func ending_requirements() -> Dictionary:
	return {
		"restore": has("S04") and has("S07") and has("S08") and has("P09"),
		"seal": has("P06") and has("P08"),
	}

func equipment() -> Dictionary:
	return {
		"charm":"guardian_knot" if has("M1") else "",
		"lens":"echo_lens" if has("M2") else "",
		"focus":"rain_lens" if has("M3") else "",
		"ward":"root_ward" if has("M4") else "",
		"relic":"clear_mirror" if has("Q1") else "",
		"token":"ember_talisman" if has("Q2") else "",
	}

func rewards() -> Dictionary:
	var out := {}
	for id in reward_ids: out[id] = has(id)
	return out

func puzzles() -> Dictionary:
	var out := {}
	for id in puzzle_ids: out[id] = has(id)
	return out

func quests() -> Dictionary:
	var out := {}
	for id in quest_ids: out[id] = has(id)
	return out

func upgrades() -> Dictionary:
	var out := {}
	for id in choice_ids: out[id] = str(choices.get(id, ""))
	return out

func snapshot(position: Vector2, health: float, focus: float) -> Dictionary:
	var story := {}
	for id in flag_ids: story[id] = has(id)
	var encounters := {}
	for id in encounter_ids: encounters[id] = has(id)
	return {"schema_version":1,"build_id":str(ProjectSettings.get_setting("application/config/version","G6-001")),"chapter_id":"campaign","node_id":node_id,
		"safe_position":[position.x,position.y],"health":health,"focus":focus,"potions":potions,"effective_seconds":seconds,
		"quests":quests(),"story":story,"puzzles":puzzles(),"encounters":encounters,
		"rewards":rewards(),"skills":skills(),"upgrades":upgrades(),"equipment":equipment()}

func validate(value: Dictionary) -> String:
	var error := Store.validate_snapshot(value)
	if not error.is_empty(): return error
	if value.chapter_id != "campaign" or node(str(value.node_id)).is_empty(): return "存档章节或节点未知。"
	if value.quests.size() != quest_ids.size() or not value.quests.keys().all(func(k): return k in quest_ids): return "任务字段未知。"
	if value.story.size() != flag_ids.size() or not value.story.keys().all(func(k): return k in flag_ids): return "进度字段未知。"
	for key in flag_ids:
		if not value.story.get(key) is bool: return "进度标记无效。"
	var f: Dictionary = value.story
	if value.encounters.size() != encounter_ids.size() or not value.encounters.keys().all(func(k): return k in encounter_ids): return "遭遇字段未知。"
	for key in encounter_ids:
		if value.encounters.get(key) != f.get(key,false): return "遭遇状态不一致。"
	if value.puzzles.size() != puzzle_ids.size() or not value.puzzles.keys().all(func(k): return k in puzzle_ids): return "机关字段未知。"
	for key in puzzle_ids:
		if value.puzzles.get(key) != f.get(key,false): return "机关状态不一致。"
	if value.rewards.size() != reward_ids.size() or not value.rewards.keys().all(func(k): return k in reward_ids): return "奖励字段未知。"
	for key in reward_ids:
		if value.rewards.get(key) != f.get(key,false): return "奖励状态不一致。"
	if value.upgrades.size() != choice_ids.size() or not value.upgrades.keys().all(func(k): return k in choice_ids): return "强化字段未知。"
	if value.equipment.size() != equipment_ids.size() or not value.equipment.keys().all(func(k): return k in equipment_ids): return "装备字段未知。"
	if value.skills != skills() or value.equipment != equipment(): return "技能或装备不一致。"
	if value.quests != quests(): return "任务状态不一致。"
	# Dependency graph: every true encounter/story flag must satisfy its data requirement.
	var requires_map := {}
	for id in content.get("events", {}).keys():
		requires_map[id] = content.events[id].get("requires", [])
	for id in content.get("encounters", {}).keys():
		var req := str(content.encounters[id].get("requires", ""))
		requires_map[id] = [req] if not req.is_empty() else []
	for id in encounter_ids:
		for req in requires_map.get(id, []):
			if f.get(id,false) and not f.get(str(req),false): return "遭遇顺序不一致。"
	for id in content.get("events", {}).keys():
		for req in requires_map.get(id, []):
			if f.get(id,false) and not f.get(str(req),false): return "剧情顺序不一致。"
	# Choices must exactly match completed M events.
	for id in choice_ids:
		var selected := str(value.upgrades.get(id, ""))
		if not f.get(id,false) and selected != "": return "未完成强化却有选择。"
		if f.get(id,false):
			var ids := []
			for option in event_def(id).get("options", []): ids.append(str(option.id))
			if not selected in ids: return "强化选择无效。"
	if value.skills != skills(): return "技能不一致。"
	if value.health > max_hp_for(f, value.upgrades) or value.focus > max_focus_for(f, value.upgrades): return "资源超过当前上限。"
	# Every visited node must be reachable through unlocked exits from the start.
	if not node_reachable(str(value.node_id), f): return "节点尚未解锁。"
	var position := Vector2(value.safe_position[0],value.safe_position[1])
	if not Rect2(14,35,292,117).has_point(position): return "安全位置超出地图。"
	for wall in node(value.node_id).walls:
		if Rect2(wall[0],wall[1],wall[2],wall[3]).grow(5).has_point(position): return "安全位置位于墙内。"
	if not validate_puzzles(): return "机关数据无效。"
	return ""

func max_hp_for(f: Dictionary, upgrades: Dictionary = {}) -> float:
	var count := 0
	for id in choice_ids:
		if f.get(id,false): count += 1
	var hp := 100.0 + 10.0 * count
	# 守灯结 is always awarded with M1, as the prologue mainline equipment.
	if count >= 1: hp += 10.0
	if f.get("M4", false) and str(upgrades.get("M4", "")) == "life": hp += 20.0
	return hp

func max_focus_for(f: Dictionary, upgrades: Dictionary = {}) -> float:
	var focus := 100.0
	if f.get("M2", false): focus += 10.0
	if f.get("M4", false): focus += 10.0
	if f.get("M4", false) and str(upgrades.get("M4", "")) == "focus": focus += 20.0
	return focus

func requirement_met(req: String, f: Dictionary) -> bool:
	if req.is_empty(): return true
	for part in req.split("|", false):
		var ok := true
		for bit in part.split("&", false):
			if not f.get(bit, false): ok = false
		if ok: return true
	return false

func node_reachable(target: String, f: Dictionary) -> bool:
	if target == "N0-01": return true
	var queue: Array = ["N0-01"]
	var visited := {"N0-01": true}
	while not queue.is_empty():
		var current: String = queue.pop_front()
		for object in node(current).objects:
			if str(object.kind) not in ["exit", "end"]: continue
			var next := str(object.get("target", ""))
			if next.is_empty() or visited.has(next) or node(next).is_empty(): continue
			if not requirement_met(str(object.get("requires", "")), f): continue
			if next == target: return true
			visited[next] = true; queue.append(next)
	return false

func validate_puzzles() -> bool:
	var seen := {}
	for entry in content.nodes:
		for object in entry.objects:
			if object.kind == "guide":
				if not object.has("solution") or int(object.solution) < 0 or int(object.solution) > 3: return false
				if not object.has("dir") or int(object.dir) < 0 or int(object.dir) > 3: return false
				var target = object.get("target")
				if not target is Array or target.size() != 2: return false
				seen[object.id] = true
			elif object.kind == "switch":
				var puzzle := str(object.get("puzzle", ""))
				var flag := str(object.get("flag", ""))
				if not content.puzzles.has(puzzle) or not flag in content.puzzles[puzzle].get("flags", []): return false
				seen[flag] = true
	for puzzle in content.puzzles:
		if puzzle in ["P01","P02"]: continue
		for flag in content.puzzles[puzzle].get("flags", []):
			if not seen.has(flag): return false
	var guide_count := 0
	for entry in content.nodes:
		for object in entry.objects:
			if object.kind == "guide": guide_count += 1
	if content.nodes.any(func(e): return e.id == "N1-02") and guide_count != 3: return false
	return true

func restore(value: Dictionary) -> bool:
	if not validate(value).is_empty(): return false
	node_id = value.node_id
	flags = value.story.duplicate(true)
	choices = value.upgrades.duplicate(true)
	choice = str(choices.get("M1", ""))
	seconds = float(value.effective_seconds)
	potions = int(value.potions)
	active_event = ""
	return true
