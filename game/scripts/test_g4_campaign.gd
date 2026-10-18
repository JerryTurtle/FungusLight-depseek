extends SceneTree
## G4 campaign smoke: 31 rooms load, switches/growth work, Boss phases and both ends.
const Campaign = preload("res://scripts/campaign.gd")
const Store = preload("res://scripts/save_store.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func _initialize() -> void:
	var scene = Campaign.new()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.saves.directory = ProjectSettings.globalize_path("res://").path_join("../qa/runtime-profile/g4-campaign-"+str(Time.get_ticks_usec())).simplify_path()
	scene.new_game()
	check(scene.progress.node_id == "N0-01" and scene.combat.enemies.is_empty(), "G4 new game")
	var initial: Dictionary = scene.progress.snapshot(Vector2(72,136),100,100)
	check(scene.progress.validate(initial).is_empty(), "G4 initial save valid: "+scene.progress.validate(initial))
	# Every node loads with full progression and has reachable geometry.
	var progress = scene.progress
	for id in progress.flag_ids: progress.flags[id] = true
	for id in ["M1","M2","M3","M4"]: progress.choices[id] = {"M1":"melee","M2":"echo","M3":"rain","M4":"ward"}[id]
	progress.choice = "melee"
	progress.node_id = "N4-06"
	scene.load_room()
	check(scene.combat.player.x > 0 and not scene.combat.blocked(scene.combat.player,6),"G4 final room spawn")
	# Every room is structurally loadable and every exit target exists.
	var target_ids := {}
	for node in progress.content.nodes:
		target_ids[node.id] = true
	for node in progress.content.nodes:
		for object in node.objects:
			if str(object.kind) in ["exit","end"]:
				check(target_ids.has(str(object.get("target",""))), "exit target "+str(node.id)+":"+str(object.id))
	# Switch puzzle P03 at N1-06.
	progress.flags.P03 = false
	progress.flags.V01 = false
	progress.flags.V02 = false
	progress.flags.M2 = false
	progress.flags.M3 = false
	progress.flags.M4 = false
	progress.flags.S10 = false
	progress.flags.S11 = false
	progress.flags.S12 = false
	progress.flags.END_RESTORE = false
	progress.flags.END_SEAL = false
	progress.choices.M2 = ""
	progress.choices.M3 = ""
	progress.choices.M4 = ""
	progress.node_id = "N1-06"
	scene.load_room()
	var v01: Dictionary = progress.node().objects.filter(func(o): return o.id == "v01")[0]
	var v02: Dictionary = progress.node().objects.filter(func(o): return o.id == "v02")[0]
	check(not progress.has("P03"), "P03 starts closed")
	progress.set_switch(v01); progress.set_switch(v02)
	check(progress.has("P03") and progress.has("V01") and progress.has("V02"), "P03 opens with two switches")
	# M2 growth choice.
	progress.node_id = "N1-05"
	scene.load_room()
	var m2: bool = progress.start_event("M2")
	check(m2 and progress.finish_event("echo"), "M2 choice commits")
	check(progress.max_hp() == 140.0 and progress.skills().shield, "M2 HP and shield")
	# Boss phases at N4-06; restore late growth for a valid end-state save.
	progress.flags.M3 = true
	progress.flags.M4 = true
	progress.choices.M3 = "rain"
	progress.choices.M4 = "ward"
	progress.flags.E30 = false
	progress.flags.S09 = true
	progress.node_id = "N4-06"
	scene.load_room()
	check(scene.pending_encounter == "E30" and scene.combat.enemies.any(func(e): return e.get("archetype","") == "BOSS"), "Boss spawns")
	var boss: Dictionary = scene.combat.enemies.filter(func(e): return e.get("archetype","") == "BOSS")[0]
	boss.hp = boss.max_hp * 0.7
	scene.combat.step(Vector2.ZERO,Vector2.RIGHT)
	check(int(boss.phase) == 1 and int(boss.armor_layers) == 2, "Boss phase 1")
	boss.hp = boss.max_hp * 0.35
	scene.combat.step(Vector2.ZERO,Vector2.RIGHT)
	check(int(boss.phase) == 2 and int(boss.armor_layers) == 0 and bool(boss.core_open), "Boss phase 2 core")
	boss.hp = 0
	scene._physics_process(1.0/60.0)
	check(progress.has("E30") and scene.pending_encounter == "", "Boss commit")
	scene.show_ending_choice()
	check(scene.choice_pending, "ending choice opens")
	scene.choose_ending("restore")
	check(progress.ending_id() == "restore" and progress.has("S11"), "restore ending commits")
	# Save/load full G4 snapshot.
	scene.combat.player = Vector2(80,110)
	scene.combat.clear_hazards()
	scene.save_game("manual_1",true)
	var g4snap: Dictionary = scene.progress.snapshot(scene.combat.player,scene.combat.hp,scene.combat.focus)
	var g4error: String = scene.progress.validate(g4snap)
	check(scene.saves.load_slot("manual_1").ok,"G4 manual save written")
	scene.combat.hp = 12
	scene.load_game("manual_1")
	check(scene.progress.ending_id() == "restore" and scene.combat.hp > 12, "G4 save/load keeps ending and resources")
	check(scene.progress.validate(scene.progress.snapshot(scene.combat.player,scene.combat.hp,scene.combat.focus)).is_empty(), "restored G4 snapshot valid")
	scene.queue_free()
	await process_frame
	await process_frame
	print("G4_CAMPAIGN_TEST checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
