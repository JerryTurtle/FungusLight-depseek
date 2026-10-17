extends SceneTree
const Progress = preload("res://scripts/campaign_state.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Combat = preload("res://scripts/combat_model.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)

func _initialize() -> void:
	call_deferred("run")

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = false
	root.push_input(event)

func run() -> void:
	var healing = Combat.new()
	healing.reset()
	healing.enemies.clear()
	healing.hp = 50
	check(not healing.can_start("heal"),"legacy healing disabled")
	healing.healing_enabled = true
	check(healing.can_start("heal"),"campaign heal available")
	healing.step(Vector2.ZERO,Vector2.RIGHT,"heal")
	for i in 34: healing.step(Vector2.ZERO,Vector2.RIGHT)
	check(healing.hp == 50 and healing.potions == 3,"no heal or bottle debit before 36 steps")
	healing.step(Vector2.ZERO,Vector2.RIGHT)
	check(healing.hp == 85 and healing.potions == 2 and healing.action == "idle","heal commits exactly once at completion")
	healing.step(Vector2.ZERO,Vector2.RIGHT,"heal")
	healing.step(Vector2.RIGHT,Vector2.RIGHT)
	check(healing.action == "idle" and healing.hp == 85 and healing.potions == 2,"movement cancels without cost")
	healing.step(Vector2.ZERO,Vector2.RIGHT,"heal")
	healing.step(Vector2.ZERO,Vector2.RIGHT,"dodge")
	check(healing.action == "dodge" and healing.potions == 2,"dodge cancels heal")
	for i in 12: healing.step(Vector2.ZERO,Vector2.RIGHT)
	healing.step(Vector2.ZERO,Vector2.RIGHT,"heal")
	for i in 34: healing.step(Vector2.ZERO,Vector2.RIGHT)
	healing.spawn_zone(healing.player)
	# Direct hit during preparation must cancel and preserve the potion.
	healing.damage_player(10)
	healing.step(Vector2.ZERO,Vector2.RIGHT)
	check(healing.hp == 75 and healing.potions == 2 and healing.action == "hurt","damage interrupts pending heal")
	healing.clear_hazards()
	healing.action = "idle"
	healing.hp = 99
	healing.step(Vector2.ZERO,Vector2.RIGHT,"heal")
	for i in 35: healing.step(Vector2.ZERO,Vector2.RIGHT)
	check(healing.hp == 100 and healing.potions == 1,"heal clamps capacity")
	check(not healing.can_start("heal"),"full health rejects heal")
	healing.hp = 50
	healing.potions = 0
	check(not healing.can_start("heal"),"empty bottles reject heal")
	healing.potions = 3
	healing.step(Vector2.RIGHT,Vector2.RIGHT,"heal")
	check(healing.action == "idle","cannot begin healing while moving")
	var p = Progress.new()
	check(not p.start_event("M1"),"reward cannot start early")
	check(p.start_event("S01"),"S01 start")
	check(not p.start_event("S02"),"blocking event isolation")
	check(p.finish_event(),"S01 commit")
	check(not p.start_event("S01"),"S01 idempotent")
	p.node_id = "N0-02"
	p.apply_interaction("socket")
	check(not p.has("P01"),"socket requires actual core")
	p.apply_interaction("chest")
	p.apply_interaction("chest")
	check(p.has("core") and not p.has("P01"),"pickup is not puzzle completion")
	p.apply_interaction("socket")
	check(p.start_event("S02"),"unlock intro gated by actual puzzle")
	p.finish_event()
	check(p.skills().light and not p.skills().shield and not p.skills().rain,"only prologue skill unlocked")
	check(not p.has("tutorial") and not p.has("E01") and not p.has("M1"),"skip does not solve tutorial or battle")
	p.flags.tutorial = true
	p.flags.E01 = true
	check(p.start_event("M1"),"earned reward opens")
	check(not p.finish_event() and not p.has("M1"),"skip cannot auto select")
	check(not p.finish_event("invalid"),"invalid choice rejected")
	check(p.finish_event("light") and p.max_hp() == 120,"choice and base/equipment commit together")
	check(not p.start_event("M1") and not p.finish_event("melee"),"reward cannot regrant or change via duplicate")
	var snapshot: Dictionary = p.snapshot(Vector2(40,110),90,60)
	check(p.validate(snapshot).is_empty(),"valid snapshot")
	var restored = Progress.new()
	check(restored.restore(snapshot) and restored.choice == "light" and restored.max_hp() == 120,"reward restored without second grant")
	for field in ["node_id","chapter_id"]:
		var bad := snapshot.duplicate(true)
		bad[field] = "unknown"
		check(not restored.restore(bad),"unknown identity "+field)
	var wall_save := snapshot.duplicate(true)
	wall_save.safe_position = [140,60]
	check(not restored.restore(wall_save),"wall spawn rejected")
	var bad_skill := snapshot.duplicate(true)
	bad_skill.skills.rain = true
	check(not restored.restore(bad_skill),"future ability injection rejected")
	var bad_reward := snapshot.duplicate(true)
	bad_reward.story.erase("tutorial")
	check(not restored.restore(bad_reward),"missing prerequisite rejected")
	var unknown := snapshot.duplicate(true)
	unknown.encounters.E99 = true
	check(not restored.restore(unknown),"unknown encounter rejected")
	unknown = snapshot.duplicate(true)
	unknown.quests.future = true
	check(not restored.restore(unknown),"unknown quest rejected")
	p.node_id = "N0-03"
	p.apply_interaction("pipe",false)
	check(not p.has("pipe"),"scan required")
	p.apply_interaction("pipe",true)
	check(p.start_event("S03") and p.finish_event(),"evidence before S03")
	check(p.has("S03"),"S03 committed")
	for entry in p.content.nodes:
		var world_model = Combat.new()
		world_model.reset()
		world_model.enemies.clear()
		world_model.doors.clear()
		world_model.walls = world_model.DEFAULT_WALLS.slice(0,4)
		for wall in entry.walls: world_model.walls.append(Rect2(wall[0],wall[1],wall[2],wall[3]))
		var spawn := Vector2(entry.spawn[0],entry.spawn[1])
		check(not world_model.blocked(spawn),"spawn walkable "+entry.id)
		for object in entry.objects:
			var target := Vector2(object.pos[0],object.pos[1])
			check(not world_model.navigator.route(spawn,target,world_model.clear_body_path).is_empty(),"object reachable "+entry.id+":"+object.id)
			if object.kind == "exit": check(not p.node(object.target).is_empty(),"exit resolves "+object.target)
	# Actual scene, actual engine event dispatch; no OS input or route timing claim.
	var scene = Campaign.new()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.saves.directory = ProjectSettings.globalize_path("res://").path_join("../qa/runtime-profile/campaign-test-"+str(Time.get_ticks_usec())).simplify_path()
	scene.new_game()
	check(scene.running and not scene.paused and scene.combat.enemies.is_empty(),"new game safe camp")
	check(scene.saves.load_slot("auto").ok,"new checkpoint written")
	scene.combat.poison_until = scene.combat.tick+240
	check(not scene.SaveStore.is_safe(scene.safety()),"active poison blocks checkpoint")
	scene.combat.clear_hazards()
	scene.combat.player = Vector2(88,100)
	key(KEY_E)
	check(scene.progress.active_event == "S01" and scene.paused,"E actual scene dialogue")
	scene._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(scene.overlay.visible and scene.progress.active_event == "S01" and not scene.progress.has("S01"),"window close warns without committing dialogue")
	scene.show_dialogue()
	scene.finish_dialogue()
	check(scene.progress.has("S01") and not scene.paused,"skip commits only current intro")
	scene.combat.player = Vector2(285,110)
	scene.interact()
	check(scene.progress.node_id == "N0-02" and scene.combat.enemies.is_empty(),"door transition does not spawn combat before teaching")
	scene.combat.player = Vector2(76,80)
	scene.interact()
	scene.combat.player = Vector2(178,88)
	scene.interact()
	check(scene.progress.active_event == "S02","pickup and socket start unlock")
	scene.finish_dialogue()
	check(scene.pending_encounter == "tutorial" and scene.combat.enemies[0].dummy,"teaching target harmless")
	scene.combat.player = Vector2(190,70)
	scene.combat.step(Vector2.ZERO,Vector2.RIGHT,"light")
	for i in 30: scene.combat.step(Vector2.ZERO,Vector2.RIGHT)
	scene._physics_process(1.0/60)
	check(scene.progress.has("tutorial") and scene.pending_encounter == "E01","real light hit unlocks battle")
	check(not scene.SaveStore.is_safe(scene.safety()),"living hostile blocks save")
	var old_health: float = scene.saves.load_slot("auto").snapshot.health
	scene.save_game("auto",true)
	check(scene.saves.load_slot("auto").snapshot.health == old_health,"unsafe save preserves checkpoint")
	# Controlled placement exercises actual combat, separate from normal-input route acceptance.
	for enemy in scene.combat.enemies:
		if enemy.hp > 0:
			enemy.dummy = true
			enemy.pos = Vector2(235,96)
			scene.combat.player = Vector2(215,96)
	for i in 110:
		for enemy in scene.combat.enemies:
			if enemy.hp > 0: scene.combat.player = enemy.pos-Vector2(18,0)
		scene.combat.step(Vector2.ZERO,Vector2.RIGHT,"",true)
	scene._physics_process(1.0/60)
	check(scene.progress.has("E01"),"combat death marks E01 once")
	while scene.combat.action != "idle": scene.combat.step(Vector2.ZERO,Vector2.RIGHT)
	scene.combat.player = Vector2(245,136)
	scene.interact()
	scene.finish_dialogue()
	check(not scene.progress.has("M1") and scene.overlay.visible,"scene skip still requires choice")
	scene.dialogue_index = scene.progress.content.dialogues.M1.size()
	scene._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	scene.show_dialogue()
	check(not scene.progress.has("M1") and scene.dialogue_index < scene.progress.content.dialogues.M1.size(),"cancel close at choice safely restores dialogue")
	scene.choose_growth("melee")
	check(scene.progress.has("M1") and scene.combat.config.actions.melee.damage == 21 and scene.combat.hp <= 100,"growth changes damage without free healing")
	scene.save_game("manual_1")
	check(scene.saves.load_slot("manual_1").ok,"manual save scene wiring")
	scene.progress.flags.E02 = true
	scene.load_game("manual_1")
	check(not scene.progress.has("E02") and scene.progress.choice == "melee","load rolls world/rewards back together")
	var old_tick: int = scene.combat.tick
	scene.show_pause()
	scene._physics_process(1.0/60)
	check(scene.combat.tick == old_tick,"pause freezes simulation")
	scene.resume()
	key(KEY_H)
	key(KEY_B)
	key(KEY_V)
	check(scene.combat.projectiles.is_empty() and scene.combat.zones.is_empty(),"campaign debug controls disabled")
	scene.combat_audio.stop_all()
	scene.queue_free()
	await process_frame
	await process_frame
	print("CAMPAIGN_TEST checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
