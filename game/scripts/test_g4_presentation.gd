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
	var l12 := ""
	for row in content.dialogues.L12: l12 += str(row[1])
	check(l12.find("违约者") >= 0, "L12 carries the complete covenant")
	var s08 := ""
	for row in content.dialogues.S08: s08 += str(row[1])
	check(s08.find("残片") >= 0 and s08.find("旧约墙") >= 0, "S08 points to the full covenant wall")

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
	check(title_text.find("只够一边") >= 0 and title_text.find("开场故事") >= 0, "title states the story premise and offers the opening")
	scene.show_journal()
	await process_frame
	var journal_text := " ".join(menu_texts(scene))
	check(journal_text.find("S06") >= 0 or journal_text.find("合流") >= 0, "journal names the confluence state")

	scene.combat_audio.stop_all()
	scene.queue_free()
	await process_frame
	print("G4_PRESENTATION_TEST checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
