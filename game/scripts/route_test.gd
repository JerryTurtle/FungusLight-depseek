extends SceneTree
## G3-012 normal-input slice route. Every action is fed through Godot input events
## (keyboard/mouse), then the campaign is advanced at its real fixed 60Hz step.
## No teleports and no direct flag/reward writes. Dialogue dwell is modelled
## (~0.9s per line + reveal input) and reported separately from movement/combat.
const Campaign = preload("res://scripts/campaign.gd")
var BUILD_ID := str(ProjectSettings.get_setting("application/config/version","G6-001"))
var scene
var checks := 0
var failures := 0
var tick := 0
var step_index := 0
var step_ticks := 0
var segments: Array = []
var held := {}
var mouse_down := false
var dialogue_wait := 0
var skip_dialogue := OS.get_environment("FUNGUS_SKIP_DIALOGUE") == "1"
var branch_b := OS.get_environment("FUNGUS_BRANCH") == "B"
var seal_ending := OS.get_environment("FUNGUS_ENDING") == "seal"
var choice_m1 := OS.get_environment("FUNGUS_M1")
var choice_m2 := OS.get_environment("FUNGUS_M2")
var choice_m3 := OS.get_environment("FUNGUS_M3")
var choice_m4 := OS.get_environment("FUNGUS_M4")
var route_tag := OS.get_environment("FUNGUS_ROUTE_TAG")
var sidequest_route := OS.get_environment("FUNGUS_SIDEQUEST") == "1"
var min_hp := 100.0
var deaths := 0
var wall_start := 0
var finished := false
var failed := ""
var route: Array = []
var nav_path: Array = []
var nav_goal := Vector2.INF
var nav_age := 0
var last_player := Vector2.ZERO
var walk_reason := ""
var stall := 0
var nudge_sign := 1
var combat_stall := 0
var dodge_sign := 1
var dodges := 0
var heals := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	scene = Campaign.new()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.saves.directory = ProjectSettings.globalize_path("res://").path_join("../qa/runtime-profile/route-test").simplify_path()
	scene.new_game()
	last_player = scene.combat.player
	build_route()
	wall_start = Time.get_ticks_msec()
	while not finished and tick < 60*60*18 and failed == "":
		tick += 1
		step_ticks += 1
		brain()
		if failed != "":
			break
		scene._physics_process(1.0/60)
		for event in scene.combat.events:
			if event.kind == "heal": heals += 1
		update_dialogue(1.0/60)
		if scene.overlay.visible:
			await process_frame
		min_hp = minf(min_hp,scene.combat.hp)
		if scene.combat.hp <= 0:
			deaths += 1
			var death_dump := []
			for e in scene.combat.enemies: death_dump.append([e.get("archetype","T1"),e.pos,e.hp])
			failed = "player died at step "+str(step().id)+" pending="+str(scene.pending_encounter)+" hp="+str(scene.combat.hp)+" enemies="+str(death_dump)
	if not finished and failed == "":
		var cap_dump := []
		for e in scene.combat.enemies: cap_dump.append([e.get("archetype","T1"),e.pos,e.hp,e.state])
		failed = "route tick cap at step "+str(step().id)+" pending="+str(scene.pending_encounter)+" player="+str(scene.combat.player)+" enemies="+str(cap_dump)
	if failed == "":
		check(scene.progress.has("S01") and scene.progress.has("P01") and scene.progress.has("S02"),"prologue main path committed")
		check(scene.progress.has("M1") and scene.progress.choice == ("light" if choice_m1 == "light" else "melee"),"M1 choice committed")
		check(scene.progress.has("S03") and scene.progress.has("E03") and scene.progress.has("E04"),"story and mine encounters committed")
		check(scene.progress.has("E05") and scene.progress.has("E06") and scene.progress.has("P02"),"light puzzle and pods committed")
		check(deaths == 0 and scene.combat.hp > 0,"route completed without death")
		check(scene.progress.has("P02"),"P02 committed")
		var auto: Dictionary = scene.saves.load_slot("auto")
		check(auto.ok and not str(auto.snapshot.get("node_id","")).is_empty(),"safe checkpoint loadable")
		check(scene.progress.seconds > 30.0 and scene.progress.seconds <= float(tick)/60.0 + 0.5,"effective time excludes paused dialogue")
		check(scene.progress.node_id == "N4-07" and scene.progress.ending_id() == ("seal" if seal_ending else "restore") and scene.progress.has("S12"),"G4 full route and ending")
		if sidequest_route:
			check(scene.progress.has("Q1") and scene.progress.has("Q2") and scene.progress.equipment().relic == "clear_mirror" and scene.progress.equipment().token == "ember_talisman","G4 both sidequests and equipment")
	else:
		check(false,"route finished: "+failed)
	var total := float(tick)/60.0
	write_report(total)
	var report_prefix := "ROUTE_SKIP_TEST" if skip_dialogue else "ROUTE_TEST"
	print("%s checks=%d failures=%d seconds=%.1f steps=%d deaths=%d" % [report_prefix,checks,failures,total,segments.size(),deaths])
	release_all()
	scene.combat_audio.stop_all()
	scene.free()
	await process_frame
	quit(1 if failures else 0)

func build_route() -> void:
	route = [
		{"id":"S01","type":"interact","to":Vector2(152,115),"flag":"S01"},
		{"id":"N0-02","type":"interact","to":Vector2(285,104),"node":"N0-02"},
		{"id":"core","type":"interact","to":Vector2(76,74),"flag":"core"},
		{"id":"P01","type":"interact","to":Vector2(178,68),"flag":"P01"},
		{"id":"tutorial","type":"light_target"},
		{"id":"E01","type":"combat","flag":"E01"},
		{"id":"M1","type":"interact","to":Vector2(245,120),"flag":"M1","choice":"melee"},
		{"id":"N0-03","type":"interact","to":Vector2(292,110),"node":"N0-03"},
		{"id":"scan","type":"press","to":Vector2(145,92),"key":KEY_Q,"wait":8},
		{"id":"pipe","type":"interact","to":Vector2(145,92),"flag":"pipe"},
		{"id":"S03","type":"interact","to":Vector2(218,89),"flag":"S03"},
		{"id":"N0-04","type":"interact","to":Vector2(292,110),"node":"N0-04"},
		{"id":"E02","type":"combat","flag":"E02"},
		{"id":"E03","type":"combat","flag":"E03"},
		{"id":"N1-01","type":"interact","to":Vector2(290,99),"node":"N1-01"},
		{"id":"E04","type":"combat","flag":"E04"},
		{"id":"L01","type":"lore","to":Vector2(278,155)},
		{"id":"N1-02","type":"interact","to":Vector2(300,130),"node":"N1-02"},
		{"id":"E05","type":"combat","flag":"E05"},
		{"id":"E06","type":"combat","flag":"E06"},
		{"id":"P02","type":"guides"},
		{"id":"N1-03","type":"interact","to":Vector2(292,144),"node":"N1-03"},
		{"id":"E07","type":"combat","flag":"E07"},
		{"id":"E08","type":"combat","flag":"E08"},
		{"id":"N1-04","type":"interact","to":Vector2(292,144),"node":"N1-04"},
		{"id":"E09","type":"combat","flag":"E09"},
		{"id":"E10","type":"combat","flag":"E10"},
		{"id":"L03","type":"lore","to":Vector2(150,140)},
		{"id":"N1-08","type":"interact","to":Vector2(292,144),"node":"N1-08"},
		{"id":"E35","type":"combat","flag":"E35"},
		{"id":"rest1c","type":"rest","to":Vector2(55,150)},
		{"id":"N1-05","type":"interact","to":Vector2(160,85),"node":"N1-05"},
		{"id":"E11","type":"combat","flag":"E11"},
		{"id":"L04","type":"lore","to":Vector2(150,60)},
		{"id":"M2","type":"interact","to":Vector2(180,140),"flag":"M2"},
		{"id":"N1-06","type":"interact","to":Vector2(292,144),"node":"N1-06"},
		{"id":"E12","type":"combat","flag":"E12"},
		{"id":"S04","type":"interact","to":Vector2(250,140),"flag":"S04"},
		{"id":"V01","type":"interact","to":Vector2(150,116),"flag":"V01"},
		{"id":"V02","type":"interact","to":Vector2(190,116),"flag":"V02"},
		{"id":"N1-07","type":"interact","to":Vector2(292,144),"node":"N1-07"},
		{"id":"E31","type":"combat","flag":"E31"},
		{"id":"rest1b","type":"rest","to":Vector2(55,150)},
		{"id":"N2-01","type":"interact","to":Vector2(160,85),"node":"N2-01"},
		{"id":"S05","type":"interact","to":Vector2(150,135),"flag":"S05"},
		{"id":"E13","type":"combat","flag":"E13"},
		{"id":"N2-02","type":"interact","to":Vector2(292,144),"node":"N2-02"},
		{"id":"E14","type":"combat","flag":"E14"},
		{"id":"V03","type":"interact","to":Vector2(145,116),"flag":"V03"},
		{"id":"V04","type":"interact","to":Vector2(190,116),"flag":"V04"},
		{"id":"N2-03","type":"interact","to":Vector2(292,144),"node":"N2-03"},
		{"id":"E15","type":"combat","flag":"E15"},
		{"id":"N2-01b","type":"interact","to":Vector2(25,110),"node":"N2-01"},
		{"id":"N2-04","type":"interact","to":Vector2(250,75),"node":"N2-04"},
		{"id":"E16","type":"combat","flag":"E16"},
		{"id":"V05","type":"interact","to":Vector2(145,116),"flag":"V05"},
		{"id":"V06","type":"interact","to":Vector2(190,116),"flag":"V06"},
		{"id":"N2-05","type":"interact","to":Vector2(292,144),"node":"N2-05"},
		{"id":"E17","type":"combat","flag":"E17"},
		{"id":"N2-01c","type":"interact","to":Vector2(25,110),"node":"N2-01"},
		{"id":"N2-06","type":"interact","to":Vector2(160,95),"node":"N2-06"},
		{"id":"rest2","type":"rest","to":Vector2(55,150)},
		{"id":"S06","type":"interact","to":Vector2(150,135),"flag":"S06"},
		{"id":"E18","type":"combat","flag":"E18"},
		{"id":"N2-07","type":"interact","to":Vector2(292,144),"node":"N2-07"},
		{"id":"E19","type":"combat","flag":"E19"},
		{"id":"rest2b","type":"rest","to":Vector2(55,150)},
		{"id":"N2-09","type":"interact","to":Vector2(292,144),"node":"N2-09"},
		{"id":"E32","type":"combat","flag":"E32"},
		{"id":"N2-08","type":"interact","to":Vector2(130,145),"node":"N2-08"},
		{"id":"S07","type":"interact","to":Vector2(80,60),"flag":"S07"},
		{"id":"E20","type":"combat","flag":"E20"},
		{"id":"V07","type":"interact","to":Vector2(145,100),"flag":"V07"},
		{"id":"V08","type":"interact","to":Vector2(190,100),"flag":"V08"},
		{"id":"M3","type":"interact","to":Vector2(180,140),"flag":"M3"},
		{"id":"N2-10","type":"interact","to":Vector2(292,144),"node":"N2-10"},
		{"id":"E34","type":"combat","flag":"E34"},
		{"id":"rest2c","type":"rest","to":Vector2(55,150)},
		{"id":"N3-01","type":"interact","to":Vector2(160,85),"node":"N3-01"},
		{"id":"rest3","type":"rest","to":Vector2(55,150)},
		{"id":"S08","type":"interact","to":Vector2(150,135),"flag":"S08"},
		{"id":"E21","type":"combat","flag":"E21"},
		{"id":"rest3d","type":"rest","to":Vector2(55,150)},
		{"id":"N3-02","type":"interact","to":Vector2(292,144),"node":"N3-02"},
		{"id":"E22","type":"combat","flag":"E22"},
		{"id":"rest3a","type":"rest","to":Vector2(55,150)},
		{"id":"V09","type":"interact","to":Vector2(140,116),"flag":"V09"},
		{"id":"V10","type":"interact","to":Vector2(180,116),"flag":"V10"},
		{"id":"V11","type":"interact","to":Vector2(205,116),"flag":"V11"},
		{"id":"rest4","type":"rest","to":Vector2(55,150)},
		{"id":"N3-03","type":"interact","to":Vector2(292,144),"node":"N3-03"},
		{"id":"E23","type":"combat","flag":"E23"},
		{"id":"rest3b","type":"rest","to":Vector2(55,150)},
		{"id":"N3-07","type":"interact","to":Vector2(292,144),"node":"N3-07"},
		{"id":"E33","type":"combat","flag":"E33"},
		{"id":"rest3e","type":"rest","to":Vector2(55,150)},
		{"id":"N3-04","type":"interact","to":Vector2(160,85),"node":"N3-04"},
		{"id":"E24","type":"combat","flag":"E24"},
		{"id":"E25","type":"combat","flag":"E25"},
		{"id":"N3-05","type":"interact","to":Vector2(292,144),"node":"N3-05"},
		{"id":"rest3c","type":"rest","to":Vector2(55,150)},
		{"id":"V12","type":"interact","to":Vector2(145,116),"flag":"V12"},
		{"id":"V13","type":"interact","to":Vector2(190,116),"flag":"V13"},
		{"id":"M4","type":"interact","to":Vector2(180,140),"flag":"M4"},
		{"id":"N3-06","type":"interact","to":Vector2(292,144),"node":"N3-06"},
		{"id":"E26","type":"combat","flag":"E26"},
		{"id":"N3-08","type":"interact","to":Vector2(292,144),"node":"N3-08"},
		{"id":"E36","type":"combat","flag":"E36"},
		{"id":"rest3f","type":"rest","to":Vector2(55,150)},
		{"id":"N4-01","type":"interact","to":Vector2(292,144),"node":"N4-01"},
		{"id":"E27","type":"combat","flag":"E27"},
		{"id":"V14","type":"interact","to":Vector2(150,116),"flag":"V14"},
		{"id":"N4-02","type":"interact","to":Vector2(292,144),"node":"N4-02"},
		{"id":"E28","type":"combat","flag":"E28"},
		{"id":"V15","type":"interact","to":Vector2(150,116),"flag":"V15"},
		{"id":"N4-03","type":"interact","to":Vector2(292,144),"node":"N4-03"},
		{"id":"E29","type":"combat","flag":"E29"},
		{"id":"V16","type":"interact","to":Vector2(150,116),"flag":"V16"},
		{"id":"N4-04","type":"interact","to":Vector2(292,144),"node":"N4-04"},
		{"id":"N4-05","type":"interact","to":Vector2(292,144),"node":"N4-05"},
		{"id":"rest5","type":"rest","to":Vector2(55,150)},
		{"id":"S09","type":"interact","to":Vector2(150,60),"flag":"S09"},
		{"id":"N4-06","type":"interact","to":Vector2(292,144),"node":"N4-06"},
		{"id":"E30","type":"combat","flag":"E30"},
		{"id":"ending","type":"interact","to":Vector2(150,120),"flag":"S11"},
		{"id":"N4-07","type":"interact","to":Vector2(292,144),"node":"N4-07"},
		{"id":"credits","type":"interact","to":Vector2(160,105),"flag":"S12"},
		{"id":"done","type":"finish"}
	]
	if sidequest_route:
		_insert_before("N1-03", {"id":"Q1a","type":"interact","to":Vector2(80,125),"flag":"Q1a"})
		_insert_before("N2-01b", {"id":"Q1b","type":"interact","to":Vector2(150,125),"flag":"Q1b"})
		_insert_before("N3-03", {"id":"Q1c","type":"interact","to":Vector2(90,125),"flag":"Q1c"})
		_insert_before("L03", {"id":"Q2a","type":"interact","to":Vector2(190,125),"flag":"Q2a"})
		_insert_before("N2-01c", {"id":"Q2b","type":"interact","to":Vector2(150,125),"flag":"Q2b"})
		_insert_before("M3", {"id":"Q2c","type":"interact","to":Vector2(250,125),"flag":"Q2c"})
	if branch_b:
		var start_a := -1
		var start_b := -1
		var merge := -1
		for i in route.size():
			match str(route[i].id):
				"N2-02": start_a = i
				"N2-04": start_b = i
				"N2-06": merge = i
		if start_a >= 0 and start_b > start_a and merge > start_b:
			var prefix: Array = route.slice(0,start_a)
			var a: Array = route.slice(start_a,start_b)
			var b: Array = route.slice(start_b,merge)
			var tail: Array = route.slice(merge)
			route = prefix + b + a + tail

func _insert_before(target_id: String, item: Dictionary) -> void:
	for i in route.size():
		if str(route[i].id) == target_id:
			route.insert(i,item)
			return

func step() -> Dictionary:
	if step_index >= route.size(): return {"id":"none","type":"finish"}
	return route[step_index]

func next_step() -> void:
	var current := step()
	segments.append({"id":current.id,"type":current.type,"ticks":step_ticks,"seconds":snappedf(float(step_ticks)/60.0,0.1),"hp":snappedf(scene.combat.hp,1.0)})
	step_index += 1
	step_ticks = 0
	stall = 0
	release_all()

func brain() -> void:
	if scene.dialogue_mode != "" or scene.choice_pending:
		handle_dialogue()
		return
	var enemies := alive_enemies()
	if not enemies.is_empty() and step().type != "light_target":
		combat(enemies)
		return
	if scene.combat.action == "heal":
		release_all()
		return
	if enemies.is_empty() and scene.combat.hp < 75 and scene.combat.potions > 0 and scene.combat.action == "idle":
		release_all()
		press_key(KEY_R)
		return
	release_attack()
	match str(step().type):
		"interact": do_interact()
		"light_target": do_light_target()
		"combat": do_combat()
		"press": do_press_step()
		"lore": do_lore()
		"guides": do_guides()
		"rest": do_rest()
		"finish": finish_route()
		_: failed = "unknown step type"

func update_dialogue(delta: float) -> void:
	var box = scene.get("dialogue_box")
	if box != null and box.is_open() and box.has_method("tick"):
		box.tick(delta)

func alive_enemies() -> Array:
	return scene.combat.enemies.filter(func(e): return e.hp > 0 and not e.dummy)

func at(position: Vector2, distance: float = 18.0) -> bool:
	return scene.combat.player.distance_to(position) <= distance

func nav_clear(start: Vector2, finish: Vector2) -> bool:
	var count := maxi(1,ceili(start.distance_to(finish)))
	for i in range(count+1):
		if scene.combat.blocked(start.lerp(finish,float(i)/count),6.0): return false
	return true

func walk_to(position: Vector2) -> void:
	var combat = scene.combat
	nav_age -= 1
	if position.distance_to(nav_goal) > 1.0 or nav_age <= 0:
		nav_goal = position
		nav_path = combat.navigator.route(combat.player,position,nav_clear)
		nav_age = 20
	while nav_path.size() >= 2 and combat.player.distance_to(nav_path[0]) < 1.2:
		nav_path.pop_front()
	var target := position
	if not nav_path.is_empty(): target = nav_path[0]
	var direction: Vector2 = (target - combat.player).normalized()
	if direction.is_zero_approx():
		release_all()
		return
	if nav_path.is_empty() and not combat.clear_body_path(combat.player,combat.player+direction*10):
		direction = avoid_direction(direction)
	set_direction(direction)
	if combat.player.distance_squared_to(last_player) < 0.0005:
		stall += 1
		if stall == 20:
			nav_age = 0
		if stall > 600:
			var enemy_dump := []
			for e in scene.combat.enemies:
				enemy_dump.append([e.get("archetype","T1"),e.pos,e.hp,e.dummy])
			failed = "movement stalled toward "+str(position)+" reason="+walk_reason+" step="+str(step().id)+" player="+str(combat.player)+" action="+combat.action+" hp="+str(combat.hp)+" paused="+str(scene.paused)+" running="+str(scene.running)+" keys="+str([Input.is_physical_key_pressed(KEY_W),Input.is_physical_key_pressed(KEY_A),Input.is_physical_key_pressed(KEY_S),Input.is_physical_key_pressed(KEY_D)])+" blocked="+str([combat.blocked(combat.player+Vector2(0,2)),combat.blocked(combat.player+Vector2(0,-2)),combat.blocked(combat.player+Vector2(2,0)),combat.blocked(combat.player+Vector2(-2,0))])+" path="+str(nav_path.slice(0,3))+" enemies="+str(enemy_dump)
	else:
		stall = 0
	last_player = combat.player

func walk_direct(direction: Vector2) -> void:
	set_direction(direction)
	last_player = scene.combat.player

func avoid_direction(direction: Vector2) -> Vector2:
	var combat = scene.combat
	var best := direction
	var best_score := -2.0
	for angle in [45.0,-45.0,90.0,-90.0,135.0,-135.0,180.0]:
		var candidate: Vector2 = direction.rotated(deg_to_rad(angle))
		if not combat.clear_body_path(combat.player,combat.player+candidate*16): continue
		var score: float = candidate.dot(direction)
		if score > best_score:
			best_score = score
			best = candidate
	return best

func do_interact() -> void:
	var data := step()
	if data.has("flag") and scene.progress.has(data.flag): next_step(); return
	if data.has("node") and scene.progress.node_id == data.node: next_step(); return
	if bool(data.get("overlay",false)) and scene.overlay.visible:
		click_named_button("返回探索")
		next_step()
		return
	var target: Vector2 = data.to
	if not at(target,10):
		walk_to(target)
		return
	release_all()
	if step_ticks % 24 == 1:
		press_key(KEY_E)
		data.attempts = int(data.get("attempts",0))+1
		if int(data.get("attempts",0)) > 30:
			failed = "interact timeout "+str(data.id)+" player="+str(scene.combat.player)+" near="+str(scene.nearest_object().get("id",""))+" notice="+scene.notice

func do_press_step() -> void:
	var data := step()
	if not at(data.to,10):
		walk_to(data.to)
		return
	release_all()
	var pressed_tick := int(data.get("pressed_tick",-1))
	if pressed_tick < 0:
		press_key(data.key)
		data.pressed_tick = step_ticks
		return
	if step_ticks < pressed_tick + 6: return
	if data.key == KEY_Q and not scene.scanned:
		data.pressed_tick = -1
		if step_ticks > 80: failed = "scan did not register"
		return
	next_step()

func do_light_target() -> void:
	if scene.progress.has("tutorial"):
		next_step(); return
	if not at(Vector2(205,72),14):
		walk_to(Vector2(205,72))
		return
	release_all()
	if step_ticks % 20 == 1:
		aim_press(MOUSE_BUTTON_RIGHT,Vector2(230,70))
	if step_ticks > 60 * 6: failed = "tutorial light did not commit"

func do_combat() -> void:
	var data := step()
	if scene.progress.has(data.flag):
		next_step(); return
	if step_ticks > 60 * 120:
		var dump := []
		for e in scene.combat.enemies: dump.append([e.get("archetype",""),e.pos,e.hp,e.state])
		failed = "combat timeout "+str(data.flag)+" node="+scene.progress.node_id+" pending="+scene.pending_encounter+" enemies="+str(dump)

func do_lore() -> void:
	var data := step()
	if int(data.get("phases",0)) == 0:
		if not at(data.to,12):
			walk_to(data.to)
			return
		release_all()
		press_key(KEY_E)
		data.phases = 1
		if scene.dialogue_mode != "lore":
			data.attempts = int(data.get("attempts",0))+1
			if int(data.attempts) >= 3:
				failed = "lore did not open: "+scene.notice
		return
	if scene.dialogue_mode == "":
		next_step()

func do_rest() -> void:
	var data := step()
	if not at(data.to,12):
		walk_to(data.to)
		return
	release_all()
	if scene.combat.hp >= scene.progress.max_hp()-1:
		next_step(); return
	if int(data.get("attempts",0)) > 20:
		var near: Dictionary = scene.nearest_object()
		var near_dump := []
		for obj in scene.progress.node().objects:
			near_dump.append([obj.id,obj.kind,obj.pos,scene.combat.player.distance_to(Vector2(obj.pos[0],obj.pos[1]))])
		failed = "rest timeout "+str(data.id)+" hp="+str(scene.combat.hp)+" max="+str(scene.progress.max_hp())+" player="+str(scene.combat.player)+" near="+str(near.get("id",""))+" notice="+scene.notice+" paused="+str(scene.paused)+" safe="+str(scene.SaveStore.is_safe(scene.safety()))+" objects="+str(near_dump)
		return
	if step_ticks % 24 == 1:
		press_key(KEY_E)
		data.attempts = int(data.get("attempts",0))+1

func do_guides() -> void:
	if scene.progress.has("P02"):
		next_step(); return
	var guide: Dictionary = {}
	for entry in scene.progress.guides():
		if not scene.guide_aligned(entry): guide = entry; break
	if guide.is_empty():
		next_step(); return
	var target := Vector2(guide.pos[0],guide.pos[1])
	if not at(target,10):
		walk_to(target)
		return
	release_all()
	if step_ticks % 30 == 1:
		press_key(KEY_E)
		guide.attempts = int(guide.get("attempts",0))+1
		if int(guide.attempts) > 12:
			failed = "guide timeout "+str(guide.id)+" notice="+scene.notice

func combat(enemies: Array) -> void:
	var combat_model = scene.combat
	var target: Dictionary = enemies[0]
	for enemy in enemies:
		if combat_model.player.distance_to(enemy.pos) < combat_model.player.distance_to(target.pos): target = enemy
	var offset: Vector2 = target.pos - combat_model.player
	var distance := offset.length()
	var archetype: String = target.get("archetype","T1")
	if combat_model.action == "heal":
		release_all()
		return
	if combat_model.hp < 62 and combat_model.potions > 0 and combat_model.action == "idle" and distance > 66:
		press_key(KEY_R)
		return
	if combat_model.hp < 48 and combat_model.potions > 0 and combat_model.action == "idle" and archetype not in ["T1","EL1"]:
		if distance < 62:
			walk_reason = "combat-retreat"
			walk_to(combat_model.player - offset.normalized()*42)
			return
		press_key(KEY_R)
		return
	if archetype == "BOSS" and target.state == "attack" and int(target.age) >= 26 and int(target.age) < 50 and distance < 60 and combat_model.action == "idle" and int(combat_model.cooldowns.get("dodge",0)) <= 0:
		var boss_side: Vector2 = offset.normalized().rotated(PI/2*dodge_sign)
		if not combat_model.clear_body_path(combat_model.player,combat_model.player+boss_side*34):
			dodge_sign = -dodge_sign
			boss_side = -boss_side
		walk_direct(boss_side)
		press_key(KEY_SPACE)
		dodges += 1
		return
	if archetype == "EL1" and target.state == "attack" and int(target.age) >= 28 and int(target.age) < 52 and distance < 46 and combat_model.action == "idle" and int(combat_model.cooldowns.get("dodge",0)) <= 0:
		var elite_side: Vector2 = offset.normalized().rotated(PI/2*dodge_sign)
		if not combat_model.clear_body_path(combat_model.player,combat_model.player+elite_side*30):
			dodge_sign = -dodge_sign
			elite_side = -elite_side
		walk_direct(elite_side)
		press_key(KEY_SPACE)
		dodges += 1
		return
	if archetype in ["T1"] and target.state == "attack" and int(target.age) < 24 and distance < 40 and combat_model.action == "idle" and int(combat_model.cooldowns.get("dodge",0)) <= 0:
		var side: Vector2 = offset.normalized().rotated(PI/2*dodge_sign)
		if not combat_model.clear_body_path(combat_model.player,combat_model.player+side*30):
			dodge_sign = -dodge_sign
			side = -side
		walk_direct(side)
		press_key(KEY_SPACE)
		dodges += 1
		return
	if archetype == "T3" and target.state == "attack" and int(target.age) >= 18 and int(target.age) < 42 and distance < 90:
		var charge_side: Vector2 = offset.normalized().rotated(PI/2*dodge_sign)
		if not combat_model.clear_body_path(combat_model.player,combat_model.player+charge_side*32):
			dodge_sign = -dodge_sign
			charge_side = -charge_side
		walk_direct(charge_side)
		if int(combat_model.cooldowns.get("dodge",0)) <= 0 and distance < 70:
			press_key(KEY_SPACE)
			dodges += 1
		return
	if combat_model.player.distance_squared_to(last_player) < 0.0005:
		combat_stall += 1
	else:
		combat_stall = 0
	last_player = combat_model.player
	if combat_stall > 300:
		failed = "combat stalled on "+str(target.get("archetype","T1"))+" at "+str(target.pos)+" player="+str(combat_model.player)+" dist="+str(distance)+" action="+combat_model.action
		return
	if archetype == "T5":
		if distance > 88 or not combat_model.clear_line(combat_model.player,target.pos):
			walk_reason = "t5-approach"
			walk_to(target.pos)
			return
		if distance > 52:
			release_all()
			combat_stall = 0
			if combat_model.focus >= 20 and combat_model.action == "idle" and step_ticks % 20 == 1:
				aim_press(MOUSE_BUTTON_RIGHT,target.pos)
			return
		walk_reason = "t5-backoff"
		walk_to(combat_model.player - offset.normalized()*16)
		return
	if distance > 22:
		if archetype == "BOSS" and distance < 100 and combat_model.focus >= 20 and combat_model.action == "idle" and combat_model.clear_line(combat_model.player,target.pos):
			aim_press(MOUSE_BUTTON_RIGHT,target.pos)
			return
		walk_reason = "combat-approach"
		walk_to(target.pos)
		if archetype == "T2" and combat_model.focus >= 20 and combat_model.action == "idle" and step_ticks % 24 == 1:
			aim_press(MOUSE_BUTTON_RIGHT,target.pos)
		return
	hold_attack(target.pos)

func hold_attack(aim: Vector2) -> void:
	for code in [KEY_W,KEY_A,KEY_S,KEY_D]:
		apply_key(code,false)
	mouse_down = true
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = aim * 4.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func release_attack() -> void:
	if not mouse_down: return
	mouse_down = false
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = scene.combat.player * 4.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func aim_press(button: int, aim: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = button
	down.pressed = true
	down.position = aim * 4.0
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	var up := InputEventMouseButton.new()
	up.button_index = button
	up.pressed = false
	up.position = aim * 4.0
	Input.parse_input_event(up)
	Input.flush_buffered_events()

func handle_dialogue() -> void:
	if scene.choice_pending:
		var second := false
		if scene.choice_mode == "ending":
			second = seal_ending
		elif scene.choice_mode == "growth":
			var pick := ""
			if scene.progress.active_event == "M1": pick = choice_m1
			elif scene.progress.active_event == "M2": pick = choice_m2
			elif scene.progress.active_event == "M3": pick = choice_m3
			elif scene.progress.active_event == "M4": pick = choice_m4
			second = pick in ["light","shield","rain","focus"]
		if second:
			press_key(KEY_S)
		press_key(KEY_E)
		return
	if skip_dialogue:
		press_key(KEY_TAB)
		return
	dialogue_wait += 1
	if dialogue_wait >= 55:
		dialogue_wait = 0
		press_key(KEY_E)

func click_named_button(fragment: String) -> void:
	for child in scene.menu.get_children():
		if child is Button and fragment in child.text:
			var center: Vector2 = child.get_global_rect().get_center()
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			press.position = center
			Input.parse_input_event(press)
			Input.flush_buffered_events()
			var release := InputEventMouseButton.new()
			release.button_index = MOUSE_BUTTON_LEFT
			release.pressed = false
			release.position = center
			Input.parse_input_event(release)
			Input.flush_buffered_events()
			return

func finish_route() -> void:
	finished = true
	segments.append({"id":"done","type":"finish","ticks":step_ticks,"seconds":snappedf(float(step_ticks)/60.0,0.1),"hp":snappedf(scene.combat.hp,1.0)})

func set_direction(direction: Vector2) -> void:
	apply_key(KEY_W,direction.y < -0.35)
	apply_key(KEY_S,direction.y > 0.35)
	apply_key(KEY_A,direction.x < -0.35)
	apply_key(KEY_D,direction.x > 0.35)

func apply_key(code: int, down: bool) -> void:
	if bool(held.get(code,false)) == down: return
	held[code] = down
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func press_key(code: int) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	var up := InputEventKey.new()
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()

func release_all() -> void:
	for code in [KEY_W,KEY_A,KEY_S,KEY_D]:
		apply_key(code,false)
	release_attack()

func write_report(total_seconds: float) -> void:
	var report := {"build_id":BUILD_ID,"route":"N0-01→N0-04→N1-01→N1-05→N2-01→N2-06→N3-06→N4-07","tick":tick,"seconds":snappedf(total_seconds,0.1),
		"wall_ms":Time.get_ticks_msec()-wall_start,"checks":checks,"failures":failures,"deaths":deaths,
		"min_hp":min_hp,"dodges":dodges,"heals":heals,"segments":segments,"path_queries":scene.combat.path_queries,
		"input":"Input.parse_input_event + flush, fixed 60Hz step; no teleport, no direct flag/reward writes","branch":"B" if branch_b else "A→B","ending":"seal" if seal_ending else "restore","tag":route_tag,
		"dialogue_model":("整段 Tab 跳过（选择页仍需手动确认）" if skip_dialogue else "每句约0.9秒模型化停留，再发送补全/推进输入；不属于真人阅读时间"),
		"failure":failed}
	var dir := "qa/evidence/"+BUILD_ID.substr(0,2)
	var suffix := ("-skip" if skip_dialogue else "") + ("" if route_tag.is_empty() else "-"+route_tag)
	var path := ProjectSettings.globalize_path("res://").path_join("../"+dir+"/"+BUILD_ID+"-route"+suffix+".json").simplify_path()
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report,"  "))
		file.close()
