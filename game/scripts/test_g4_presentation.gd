extends SceneTree
## G6-004 presentation checks: the pixel HUD, the five-panel opening, and the
## revised story data. These are structural checks, not a human visual review.

const Campaign = preload("res://scripts/campaign.gd")
const Intro = preload("res://scripts/intro_cinematic.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func menu_texts(scene) -> Array[String]:
	var out: Array[String] = []
	for child in scene.menu.get_children():
		if child is Label or child is Button:
			out.append(str(child.text))
	return out

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = Campaign.new()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.saves.directory = ProjectSettings.globalize_path("res://").path_join("../qa/runtime-profile/g4-presentation-"+str(Time.get_ticks_usec())).simplify_path()
	scene.new_game()
	scene.wake_left = 0
	scene.hide_player = false
	await process_frame
	check(scene.hud_panel != null and scene.hud_panel.visible, "pixel HUD is present and visible in play")
	check(scene.hud_panel.skill_slots().size() == 5, "HUD exposes five skill slots")
	var names: Array = scene.hud_panel.skill_slots().map(func(s): return s.name)
	var keys: Array = scene.hud_panel.skill_slots().map(func(s): return s.key)
	check(names == ["灯击","净光","护灯","灯雨","闪避"], "skill slot names are readable Chinese")
	check(keys == ["左键","右键","1","2","空格"], "skill slots show their input keys")
	var slot_rects: Array = scene.hud_panel.skill_slots().map(func(s): return s.rect)
	var overlap := false
	for i in slot_rects.size():
		if slot_rects[i].position.y < 560 or slot_rects[i].position.x < 880: overlap = true
		for j in range(i + 1, slot_rects.size()):
			if slot_rects[i].intersects(slot_rects[j]): overlap = true
	check(not overlap, "skill tray is in the lower-right and slots do not overlap")

	# The bars must reflect actual state, not a decorative fixed fill.
	scene.combat.hp = 42
	scene.combat.focus = 27
	scene.combat.potions = 1
	scene.progress.flags.S02 = true
	scene.progress.flags.P02 = true
	scene.progress.flags.M3 = true
	scene.combat.cooldowns.light = 36
	scene.combat.cooldowns.shield = 240
	scene.combat.cooldowns.rain = 180
	scene.combat.cooldowns.dodge = 30
	scene.hud_panel.queue_redraw()
	var slots: Array = scene.hud_panel.skill_slots()
	check(is_equal_approx(float(slots[1].total), 72.0) and int(slots[1].cd) == 36, "light cooldown feeds the icon overlay")
	check(is_equal_approx(float(slots[2].cd), 240.0) and not bool(slots[2].locked), "shield cooldown and unlock state feed the icon")
	check(bool(slots[3].locked) == false and is_equal_approx(float(slots[3].cd), 180.0), "rain icon shows its cooldown")
	check(scene.combat.potions == 1 and scene.progress.potions == 3, "HUD preview does not silently rewrite save potions")
	check(load("res://assets/hud/icon_potion_empty.png") != null, "empty potion texture loads")

	# The opening has five authored panels, each with a texture and narration.
	check(Intro.SCENES.size() == 5, "opening has five panels")
	var all_textured := true
	var all_narrated := true
	for panel in Intro.SCENES:
		if panel.get("image") == null: all_textured = false
		if str(panel.get("text","")).is_empty() or str(panel.get("chapter","")).is_empty(): all_narrated = false
	check(all_textured, "opening panels have pixel-art textures")
	check(all_narrated, "opening panels have chapter and narration text")
	var intro_state := {"done":false}
	scene.play_intro(func(): intro_state.done = true)
	await process_frame
	check(scene.intro.visible and scene.intro.index == 0 and scene.intro.playing, "opening starts on the first panel")
	scene.intro.next()
	check(scene.intro.index == 1, "opening advances to the next panel")
	scene.intro.skip()
	check(not scene.intro.playing, "opening can be skipped")
	await create_timer(0.5).timeout
	check(not scene.intro.visible, "skipping the opening closes the cinematic")
	check(bool(intro_state.done), "opening finish invokes the campaign callback")

	# The revised story is in the data, not only in a design document.
	var content: Dictionary = scene.progress.content
	check(content.dialogues.has("S10"), "boss aftermath S10 is authored")
	check(content.dialogues.size() >= 31, "all S/L dialogue entries load")
	check(str(content.dialogues["S10"][0][0]) == "旁白", "S10 uses narrator line for the mother's aftermath")
	check(str(content.events.S10.get("title","")).find("母体") >= 0, "S10 event has a journal title")
	var s03 := ""
	for row in content.dialogues.S03: s03 += str(row[1])
	check(s03.find("禾") >= 0 and s03.find("水先退") >= 0, "S03 states the human-first drought cause")
	check(s03.find("我是菌人") >= 0 and s03.find("水脉") >= 0, "S03 explains why Rong stays at the lamp")
	var l12 := ""
	for row in content.dialogues.L12: l12 += str(row[1])
	check(l12.find("违约者") >= 0 and l12.find("留路") >= 0, "L12 carries the complete covenant and its explanation")
	var s08 := ""
	for row in content.dialogues.S08: s08 += str(row[1])
	check(s08.find("残片") >= 0 and s08.find("旧约墙") >= 0 and s08.find("违约者") < 0, "S08 is an incomplete fragment that points to the wall")
	var s07 := ""
	for row in content.dialogues.S07: s07 += str(row[1])
	check(s07.find("泵压") >= 0 and s07.find("砍根令") >= 0 and s07.find("别推给菌群") >= 0, "S07 ties overpumping to the root-cutting order")
	var s10 := ""
	for row in content.dialogues.S10: s10 += str(row[1])
	check(s10.find("先断水的是人") >= 0 and s10.find("以渴偿还") >= 0, "S10 closes the evidence and covenant debt")
	var dialogue_ok := true
	for id in content.dialogues:
		for row in content.dialogues[id]:
			if str(row[0]).is_empty() or str(row[1]).is_empty(): dialogue_ok = false
			for token in ["S0","S1","M1","M2","M3","M4","P0","P1","manual_"]:
				if str(row[1]).find(token) >= 0: dialogue_ok = false
	check(dialogue_ok, "all dialogue entries are complete and free of internal IDs")
	var goals_ok := true
	for node_def in content.nodes:
		if str(node_def.goal).is_empty() or str(node_def.goal).length() > 32: goals_ok = false
	check(goals_ok, "all room goals are readable one-line objectives")
	check(JSON.stringify(content).find("专注") < 0, "player-facing resource is consistently called 精力")
	var data_ids_ok := true
	for node_def in content.nodes:
		if str(node_def.name).find("M1") >= 0 or str(node_def.goal).find("M1") >= 0: data_ids_ok = false
		for obj in node_def.objects:
			var obj_name := str(obj.get("name",""))
			if obj_name.find("M1") >= 0 or obj_name.find("P0") >= 0 or obj_name.find("S0") >= 0: data_ids_ok = false
	check(data_ids_ok, "room and object labels do not expose internal IDs")
	var mounted_lore := {}
	for node_def in content.nodes:
		for obj in node_def.objects:
			if obj.has("dialogue"): mounted_lore[str(obj.dialogue)] = true
	var lore_reachable := true
	for id in content.dialogues:
		if str(id).begins_with("L") and not mounted_lore.has(str(id)): lore_reachable = false
	check(lore_reachable, "all 20 lore entries are reachable from a room object")
	var intro_spoils := false
	for panel in Intro.SCENES:
		var panel_text := str(panel.get("text",""))
		if panel_text.find("三份证据") >= 0 or panel_text.find("恢复共生") >= 0 or panel_text.find("封存撤离") >= 0: intro_spoils = true
	check(not intro_spoils, "opening raises the question without spoiling evidence or endings")
	var n4_04: Dictionary = content.nodes.filter(func(n): return str(n.id) == "N4-04")[0]
	check(str(n4_04.goal).find("空") >= 0 and str(n4_04.goal).find("两段") < 0, "core corridor objective matches the empty room")
	var n1_04: Dictionary = content.nodes.filter(func(n): return str(n.id) == "N1-04")[0]
	var n1_04_east: Dictionary = n1_04.objects.filter(func(o): return str(o.id) == "east")[0]
	check(str(n1_04_east.target) == "N1-08" and str(n1_04_east.name).find("菌灯井") >= 0, "rift objective and exit name point to the lamp well")
	scene.progress.flags.Q1a = true
	check(scene.quest_status("Q1") == "进行中 1/3", "quest status shows partial progress")
	scene.progress.flags.Q1b = true
	scene.progress.flags.Q1c = true
	scene.progress.flags.Q1 = true
	check(scene.quest_status("Q1") == "已完成", "quest status shows completion")
	check(scene.slot_name("manual_1") == "手动存档 1", "save slot label is player-facing")
	var before_node: String = str(scene.progress.node_id)
	scene.progress.node_id = "N4-03"
	check(scene.current_goal().find("第三道") >= 0, "final pressure goal names the remaining third valve")
	scene.progress.node_id = before_node

	# Save/rest lamps must not steal the E prompt from an exit.
	var rest_min := 9999.0
	var rest_conflict := false
	var stand_conflict := false
	for node_def in content.nodes:
		var exits: Array = node_def.objects.filter(func(o): return str(o.kind) in ["exit","end"])
		for rest in node_def.objects.filter(func(o): return str(o.kind) == "rest" and str(o.get("visual","")) == "lamp"):
			for exit_obj in exits:
				rest_min = minf(rest_min, Vector2(rest.pos[0],rest.pos[1]).distance_to(Vector2(exit_obj.pos[0],exit_obj.pos[1])))
			var stand := Vector2(rest.pos[0], rest.pos[1] - 14)
			for other in node_def.objects:
				if other.kind == "rest": continue
				if Vector2(rest.pos[0],rest.pos[1]).distance_to(Vector2(other.pos[0],other.pos[1])) < 42.0:
					rest_conflict = true
				if stand.distance_to(Vector2(other.pos[0],other.pos[1])) < 34.0:
					stand_conflict = true
	check(rest_min >= 60.0, "rest lamp is at least 60px from every exit (min %.1f)" % rest_min)
	check(not rest_conflict, "rest lamp keeps 42px from other interactables")
	check(not stand_conflict, "rest approach point keeps 34px from other interactables")

	scene.show_title()
	await process_frame
	var title_text := " ".join(menu_texts(scene))
	check(title_text.find("地下三百尺") >= 0 and title_text.find("是谁先断了水") >= 0 and title_text.find("开场故事") >= 0, "title states the premise and offers the opening")
	scene.show_journal()
	await process_frame
	var journal_text := " ".join(menu_texts(scene))
	check(journal_text.find("合流") >= 0 and journal_text.find("共生结局") >= 0 and journal_text.find("封存结局") >= 0 and journal_text.find("S06") < 0, "journal names branches and endings without internal IDs")

	scene.combat_audio.stop_all()
	scene.queue_free()
	await process_frame
	print("G4_PRESENTATION_TEST checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
