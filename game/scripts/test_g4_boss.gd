extends SceneTree
## G4 Boss production kit: 2200 HP, three clamped phases, alternating phase
## moves, safe transition windows, core-only damage, readable warnings that
## match the hit tests, and the original BOSS battler wiring.
const Combat = preload("res://scripts/campaign_combat.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func hit(c, enemy: Dictionary, damage: float, kind: String = "melee") -> void:
	c.snapshot_living()
	c.queue_damage(0,int(enemy.id),c.allocate_attack_id(),damage,kind)
	c.resolve_damage_batch()

func free_lane_height(rect: Rect2) -> float:
	return maxf(rect.position.y-32.0,154.0-rect.end.y)

func _initialize() -> void:
	var c = Combat.new()
	c.reset()
	c.enemies.clear()
	c.player = Vector2(100,100)
	c.hp = 5000
	var boss: Dictionary = c.add_archetype("BOSS",Vector2(200,90))
	check(int(boss.max_hp) == 2200 and int(boss.phase) == 0,"boss production HP 2200, phase 0")
	check(int(boss.armor_layers) == 2 and not bool(boss.core_open),"opening phase starts with two shells, core closed")
	var spec: Dictionary = c.enemy_specs.BOSS
	check(int(spec.sweep_damage) == 20 and int(spec.spore_damage) == 16 and int(spec.water_damage) == 10,"boss damage 20 / 16 / 10 per second")

	# Core-only damage: closed core rejects direct and shell-stripping hits.
	var hp0: float = boss.hp
	hit(c,boss,18,"melee")
	check(boss.hp == hp0,"closed core rejects melee damage")
	check(c.history.any(func(ev): return ev.kind == "hit_rejected"),"closed core emits hit_rejected")
	hit(c,boss,24,"light")
	check(boss.hp == hp0 and int(boss.armor_layers) == 2,"closed core does not strip shell")
	check(not bool(boss.core_open),"core stays closed outside windows")

	# Sector warning and hit test share one geometry helper.
	boss.dir = Vector2.LEFT
	var shape: Dictionary = c.boss_sweep_shape(boss)
	check(is_equal_approx(float(shape.radius),72.0),"sweep warning radius equals the hit radius")
	check(is_equal_approx(float(shape.half_angle),deg_to_rad(50.0)),"sweep warning half-angle equals the hit half-angle")
	check(c.boss_sweep_contains(boss,boss.pos+Vector2(-70,0)),"sweep sector covers forward")
	check(not c.boss_sweep_contains(boss,boss.pos+Vector2(70,0)),"sweep sector never covers behind")
	check(not c.boss_sweep_contains(boss,boss.pos+Vector2(-100,0)),"sweep sector stops at its radius")
	boss.state = "attack"
	boss.boss_attack = "sweep"
	boss.age = 48
	boss.hit = false
	boss.dir = Vector2.LEFT
	c.player = boss.pos+Vector2(-48,0)
	var player_hp: float = c.hp
	c.step(Vector2.ZERO,Vector2.RIGHT)
	check(c.hp == player_hp-20.0,"sweep hits for 20 inside its warning sector")
	check(c.history.any(func(ev): return ev.kind == "hurt" and int(ev.target) == 0 and is_equal_approx(float(ev.damage),20.0)),"sweep emits its 20-damage hurt event")
	c.protection = 0
	c.player = boss.pos+Vector2(48,0)
	boss.age = 48
	boss.hit = false
	boss.dir = Vector2.LEFT
	c.step(Vector2.ZERO,Vector2.RIGHT)
	check(c.hp == player_hp-20.0,"sweep never hits behind the boss")

	# Phase 1 at 70%: clamp, fresh shell, safe transition, cleared hazards.
	boss.hp = 2200.0*0.7
	c.spawn_zone(c.player)
	c.spawn_projectile(Vector2(40,40),Vector2(10,0),-1)
	c.add_field_hazard("water","rect",Rect2(0,44,320,24),Vector2(160,56),0.0,60,120,10,60,true,boss.id)
	c.step(Vector2.ZERO,Vector2.RIGHT)
	check(int(boss.phase) == 1 and int(boss.hp) == 1540,"phase 1 clamps life at 70% exactly")
	check(int(boss.armor_layers) == 2,"phase 1 grants its fresh two-layer shell")
	check(boss.state == "transition" and bool(boss.core_open),"phase transition opens a short safe core window")
	check(c.zones.is_empty() and c.projectiles.is_empty() and c.field_hazards.is_empty(),"phase transition clears old danger zones")
	check(c.history.any(func(ev): return ev.kind == "boss_phase" and int(ev.phase) == 1),"boss_phase event for phase 1")
	check(c.history.any(func(ev): return ev.kind == "boss_core" and bool(ev.open)),"boss_core open event")
	for i in 80: c.step(Vector2.ZERO,Vector2.RIGHT)
	check(boss.state == "idle" and not bool(boss.core_open),"safe window closes before the next warning")

	# Phase 1 alternates water lane and sweep; water warns one fixed lane.
	c.player = Vector2(100,124)
	var guard := 0
	while (boss.state != "attack" or str(boss.boss_attack) != "water") and guard < 300:
		c.step(Vector2.ZERO,Vector2.RIGHT)
		guard += 1
	check(guard < 300 and str(boss.boss_attack) == "water","phase 1 first move is the water lane")
	var water: Array = c.field_hazards.filter(func(h): return h.kind == "water")
	check(water.size() == 1,"water lane warns exactly one fixed band")
	check(water.size() == 1 and (water[0].rect as Rect2) == Rect2(0,112,320,24),"water lane uses the fixed channel under the player")
	check(water.size() == 1 and free_lane_height(water[0].rect) >= 48.0,"water lane always leaves a 3-grid corridor")
	check(water.size() == 1 and int(water[0].warn_until)-c.tick == 60,"water lane warns for 1 second")
	check(water.size() == 1 and int(water[0].active_end)-int(water[0].warn_until) == 120,"water lane flows for 2 seconds")
	check(bool(water[0].dot),"water lane ticks without hit-stun")
	check(not bool(boss.core_open),"core is closed while the water lane flows")
	var flow_hp: float = c.hp
	c.step(Vector2.ZERO,Vector2.RIGHT)
	for i in 59: c.step(Vector2.ZERO,Vector2.RIGHT)
	check(c.hp == flow_hp-10.0,"water lane deals 10 at flow start")
	for i in 60: c.step(Vector2.ZERO,Vector2.RIGHT)
	check(c.hp == flow_hp-20.0,"water lane deals 10 again one second later")
	for i in 61: c.step(Vector2.ZERO,Vector2.RIGHT)
	check(c.field_hazards.filter(func(h): return h.kind == "water").is_empty(),"water lane ends after two seconds")
	check(bool(boss.core_open),"water recovery opens the core window")
	var core_hp: float = boss.hp
	hit(c,boss,18,"melee")
	check(is_equal_approx(boss.hp,core_hp-9.0),"exposed core takes melee through the phase-1 shell")
	for i in 80: c.step(Vector2.ZERO,Vector2.RIGHT)
	check(boss.state == "idle" and not bool(boss.core_open),"phase-1 recovery window closes")

	# Phase 2 at 35%: clamp, no shell, core exposed by the transition.
	boss.hp = 2200.0*0.35
	c.step(Vector2.ZERO,Vector2.RIGHT)
	check(int(boss.phase) == 2 and int(boss.hp) == 770,"phase 2 clamps life at 35% exactly")
	check(int(boss.armor_layers) == 0,"phase 2 carries no shell")
	check(bool(boss.core_open),"phase-2 transition exposes the core")
	check(c.history.any(func(ev): return ev.kind == "boss_phase" and int(ev.phase) == 2),"boss_phase event for phase 2")
	for i in 80: c.step(Vector2.ZERO,Vector2.RIGHT)
	check(boss.state == "idle" and not bool(boss.core_open),"phase-2 safe window closes")
	c.player = Vector2(100,100)
	guard = 0
	while (boss.state != "attack" or str(boss.boss_attack) != "double") and guard < 300:
		c.step(Vector2.ZERO,Vector2.RIGHT)
		guard += 1
	check(guard < 300 and str(boss.boss_attack) == "double","phase 2 first move is the double spore burst")
	var spores: Array = c.field_hazards.filter(func(h): return h.kind == "spore")
	check(spores.size() == 2,"double burst warns two separate spore zones")
	var spore_ok := true
	for spore in spores:
		spore_ok = spore_ok and str(spore.shape) == "circle" and is_equal_approx(float(spore.radius),24.0) and is_equal_approx(float(spore.damage),16.0)
	check(spore_ok,"each spore zone is radius 24 / damage 16")
	check(spores.size() == 2 and int(spores[0].warn_until)-c.tick == 60,"spore zones share a 1s readable warning")
	check(not bool(boss.core_open),"core is closed during the double burst")
	c.player = Vector2(40,40)
	var away_hp: float = c.hp
	for i in 61: c.step(Vector2.ZERO,Vector2.RIGHT)
	check(c.hp == away_hp and c.field_hazards.filter(func(h): return h.kind == "spore").is_empty(),"spore warning is dodgeable and clears after the burst")
	guard = 0
	while (boss.state != "attack" or str(boss.boss_attack) != "core") and guard < 400:
		c.step(Vector2.ZERO,Vector2.RIGHT)
		guard += 1
	check(guard < 400 and str(boss.boss_attack) == "core" and bool(boss.core_open),"phase 2 alternates into a 3-second core exposure")
	var expose_hp: float = boss.hp
	hit(c,boss,18,"melee")
	check(is_equal_approx(boss.hp,expose_hp-18.0),"phase-2 core window takes full damage without a shell")
	for i in 180: c.step(Vector2.ZERO,Vector2.RIGHT)
	check(not bool(boss.core_open),"core exposure closes after about three seconds")
	check(c.history.any(func(ev): return ev.kind == "boss_core" and not bool(ev.open)),"boss_core close event")

	# Core-phase death keeps the mother body and emits one boss_death.
	boss.state = "idle"
	boss.age = 23
	boss.boss_cycle = 1
	boss.core_open = false
	c.step(Vector2.ZERO,Vector2.RIGHT)
	check(bool(boss.core_open) and str(boss.boss_attack) == "core","forced core window before the finisher")
	boss.hp = 1
	hit(c,boss,100,"melee")
	check(boss.hp <= 0 and boss.state == "dead","boss dies inside the exposed core window")
	check(c.enemies.has(boss),"mother body stays in the encounter for the ending")
	check(c.history.filter(func(ev): return ev.kind == "boss_death").size() == 1,"boss_death event emitted once")

	# Overkill cannot skip a phase: each threshold clamps once.
	var c2 = Combat.new()
	c2.reset()
	c2.enemies.clear()
	c2.player = Vector2(100,100)
	c2.hp = 5000
	var boss2: Dictionary = c2.add_archetype("BOSS",Vector2(200,90))
	boss2.hp = 10.0
	c2.step(Vector2.ZERO,Vector2.RIGHT)
	check(int(boss2.phase) == 1 and int(boss2.hp) == 1540,"overkill clamps at 70% without skipping a phase")
	boss2.hp = 10.0
	c2.step(Vector2.ZERO,Vector2.RIGHT)
	check(int(boss2.phase) == 2 and int(boss2.hp) == 770,"one transition per threshold: 35% clamp on the next step")

	# EL1 gatekeeper: production HP, one readable shell refit, then killable.
	var em = Combat.new()
	em.reset()
	em.enemies.clear()
	em.player = Vector2(100,100)
	var elite: Dictionary = em.add_archetype("EL1",Vector2(120,100))
	check(int(elite.max_hp) == 450 and int(elite.armor_layers) == 2,"EL1 gatekeeper shell")
	elite.armor_layers = 0
	elite.hp = elite.max_hp*0.5
	elite.state = "idle"
	elite.age = 0
	em.step(Vector2.ZERO,Vector2.RIGHT)
	check(elite.state == "rearm","EL1 reaches half health and starts the shell refit")
	for i in 47: em.step(Vector2.ZERO,Vector2.RIGHT)
	check(elite.state == "rearm" and int(elite.armor_layers) == 0,"EL1 refit telegraph still readable")
	em.step(Vector2.ZERO,Vector2.RIGHT)
	check(int(elite.armor_layers) == 2,"EL1 refit restores two layers")
	elite.state = "idle"
	elite.armor_layers = 0
	elite.hp = elite.max_hp*0.3
	em.step(Vector2.ZERO,Vector2.RIGHT)
	check(elite.state != "rearm","EL1 shell refit happens only once")
	elite.hp = 5
	elite.armor_layers = 0
	em.snapshot_living()
	em.queue_damage(0,int(elite.id),em.allocate_attack_id(),100,"melee",{"independent":true,"origin":Vector2(200,90)})
	em.resolve_damage_batch()
	check(elite.hp <= 0 and elite.state == "dead","EL1 gatekeeper killable")

	# The mother uses the original 155x135 battler; other elites keep the King sheet.
	var art = preload("res://scripts/world_art.gd").new()
	check(art.enemy_texture("BOSS") == art.boss,"BOSS uses the original battler texture")
	check(art.boss.get_width() == 155 and art.boss.get_height() == 135,"BOSS battler is the native 155x135 art")
	check(art.enemy_texture("T6") != art.boss and art.enemy_texture("EL1") != art.boss and art.enemy_texture("EL2") != art.boss,"elites keep the King sheet")
	check(is_equal_approx(float(art.BOSS_DRAW_SCALE),0.5),"boss is drawn at half world scale to stay readable at 320x180")

	print("G4_BOSS_TEST checks=%d failures=%d hp=%d phase=%d" % [checks,failures,int(c.hp),int(boss.phase)])
	quit(1 if failures else 0)
