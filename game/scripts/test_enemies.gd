extends SceneTree
## Campaign enemy/elite mechanics: poison thrower, twin-spore thrower (T6),
## charger (T3), sewer elite (EL2), spore-pod elite shell refit (EL1), guard (T4).
const Combat = preload("res://scripts/campaign_combat.gd")
var checks := 0
var failures := 0

func check(ok: bool, name: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",name)

func arena():
	var m = Combat.new()
	m.reset()
	m.enemies.clear()
	m.doors.clear()
	m.walls = m.DEFAULT_WALLS.slice(0,4)
	m.player = Vector2(100,100)
	return m

func advance(m, count: int) -> void:
	for i in count: m.step(Vector2.ZERO,Vector2.RIGHT)

func hit(m, enemy, damage: float, kind: String = "melee") -> void:
	m.snapshot_living()
	m.queue_damage(0,enemy.id,m.allocate_attack_id(),damage,kind)
	m.resolve_damage_batch()

func free_lane_height(rect: Rect2) -> float:
	# Tallest horizontal corridor inside the playable band for one fixed lane.
	return maxf(rect.position.y-32.0,154.0-rect.end.y)

func _initialize() -> void:
	var m = arena()
	var e: Dictionary = m.add_archetype("T2",Vector2(175,100))
	advance(m,36)
	check(m.projectiles.is_empty(),"T2 full windup before shot")
	advance(m,2)
	check(m.projectiles.size() == 1,"T2 one shot after telegraph")
	check(m.projectiles[0].source == e.id,"shot has stable owner")
	hit(m,e,1000)
	check(m.projectiles.size() == 1,"released projectile survives owner death")
	advance(m,60)
	check(m.hp == 90 and m.poison_until > m.tick,"real damage applies poison")
	var next: int = m.poison_next
	advance(m,next-m.tick)
	check(m.hp == 86,"poison tick four damage")
	check(m.action == "idle","poison does not interrupt")
	m.protection = 70
	advance(m,60)
	check(m.hp == 86,"poison respects invulnerability without catchup")
	m.protection = 0
	advance(m,60)
	check(m.hp == 82,"subsequent poison tick normal, no catchup")
	m.reset()
	check(m.poison_until == 0 and m.poison_attacks.is_empty(),"reset clears poison and ownership")
	m = arena()
	e = m.add_archetype("T2",Vector2(175,100))
	m.shield_hp = 25
	m.shield_until = 999
	advance(m,98)
	check(m.hp == 100 and m.poison_until == 0,"fully shielded projectile does not poison")
	m = arena()
	e = m.add_archetype("T2",Vector2(135,100))
	advance(m,20)
	check(e.pos.x > 135 and e.state == "idle","T2 retreats to firing distance")
	m = arena()
	e = m.add_archetype("T2",Vector2(175,100))
	m.walls.append(Rect2(135,30,8,125))
	advance(m,80)
	check(m.projectiles.is_empty(),"T2 does not fire through wall")

	# ── T6: design twin-spore thrower ───────────────────────────────────────
	m = arena()
	e = m.add_archetype("T6",Vector2(175,100))
	check(int(e.max_hp) == 90 and int(e.speed) == 34,"T6 production 90 HP / 34 speed")
	check(int(e.armor_layers) == 0,"T6 keeps no shell")
	advance(m,45)
	check(m.projectiles.is_empty(),"T6 waits for its full 0.75s windup")
	advance(m,1)
	check(m.projectiles.size() == 1,"T6 first pellet after windup")
	check(m.projectiles[0].source == e.id and float(m.projectiles[0].damage) == 10.0,"T6 first pellet 10 damage with stable owner")
	advance(m,3)
	check(m.projectiles.size() == 1,"T6 pellets are not fired on the same tick")
	advance(m,9)
	check(m.projectiles.size() == 2,"T6 second pellet arrives about 12 ticks later")
	check(float(m.projectiles[1].damage) == 10.0,"T6 second pellet 10 damage")
	var spawn_ticks: Array = []
	for event in m.history:
		if event.kind == "projectile_spawn": spawn_ticks.append(int(event.tick))
	check(spawn_ticks.size() == 2 and int(spawn_ticks[1])-int(spawn_ticks[0]) == 12,"T6 salvo gap is exactly 12 ticks")
	check(m.history.any(func(event): return event.kind == "t6_shot"),"T6 emits shot events")
	m = arena()
	e = m.add_archetype("T6",Vector2(175,100))
	advance(m,120)
	check(m.hp == 90 and m.poison_until == 0,"T6 pellets deal 10 direct damage without a T2 poison status")
	m = arena()
	e = m.add_archetype("T6",Vector2(135,100))
	advance(m,20)
	check(e.pos.x > 135 and e.state == "idle","T6 keeps 60px stand-off distance")
	m = arena()
	e = m.add_archetype("T6",Vector2(150,100))
	for i in 20:
		m.projectiles.append({"id":m.allocate_attack_id(),"source":e.id,"pos":Vector2(300,20),"velocity":Vector2.ZERO,"radius":3.0,"damage":10.0,"ttl":999})
	var capped: Dictionary = m.spawn_projectile(Vector2(150,90),Vector2(-80,0),e.id)
	check(capped.is_empty() and m.projectiles.size() == 20,"T6 never exceeds the 20-projectile cap")
	m = arena()
	for i in 3: m.add_archetype("T6",Vector2(175,75+i*25))
	advance(m,1)
	check(m.enemies.filter(func(x): return x.state == "attack").size() == 1,"T6 counts as ranged for the attack slot")

	# ── T3 charger (unchanged) ──────────────────────────────────────────────
	m = arena()
	e = m.add_archetype("T3",Vector2(180,100))
	advance(m,1)
	var locked: Vector2 = e.dir
	m.player = Vector2(100,140)
	advance(m,30)
	check(e.dir == locked and e.pos == Vector2(180,100),"T3 telegraph locks direction before charge")
	advance(m,50)
	check(m.hp == 100 and e.pos.y == 100,"sidestep avoids locked charge")
	m = arena()
	e = m.add_archetype("T3",Vector2(160,100))
	advance(m,65)
	check(m.hp == 82,"T3 contact sweep damages once")
	advance(m,15)
	check(m.hp == 82,"no repeated charge damage")
	m = arena()
	e = m.add_archetype("T3",Vector2(180,100))
	advance(m,40)
	m.walls.append(Rect2(150,70,6,65))
	advance(m,30)
	check(e.pos.x >= 161 and m.hp == 100 and not e.charging,"charge stops at wall without hitting through")
	check(m.history.any(func(event): return event.kind == "charge_blocked"),"blocked charge emits recovery event")
	m = arena()
	e = m.add_archetype("T3",Vector2(180,100))
	advance(m,45)
	var before: Vector2 = e.pos
	hit(m,e,5)
	check(e.state == "attack" and e.pos == before,"charge active resists ordinary interrupt and push")

	# ── EL2: sewer patroller elite ──────────────────────────────────────────
	m = arena()
	e = m.add_archetype("EL2",Vector2(180,100))
	check(int(e.max_hp) == 520 and int(e.speed) == 38,"EL2 production 520 HP / 38 speed")
	check(int(e.armor_layers) == 0,"EL2 tests water movement, not shell")
	advance(m,1)
	var el2_locked: Vector2 = e.dir
	m.player = Vector2(100,140)
	advance(m,30)
	check(e.dir == el2_locked and e.pos == Vector2(180,100),"EL2 charge telegraph locks direction")
	advance(m,50)
	check(m.hp == 100 and e.pos.y == 100,"sidestep avoids locked elite charge")
	m = arena()
	e = m.add_archetype("EL2",Vector2(160,100))
	advance(m,75)
	check(m.hp == 80,"EL2 charge contact damages once for 20")
	advance(m,15)
	check(m.hp == 80,"EL2 charge does not repeat damage")
	m = arena()
	e = m.add_archetype("EL2",Vector2(180,100))
	advance(m,1)
	m.walls.append(Rect2(150,70,6,65))
	advance(m,60)
	check(e.pos.x >= 160 and m.hp == 100 and not e.charging,"EL2 charge stops at a wall")
	check(m.history.any(func(event): return event.kind == "charge_blocked"),"EL2 blocked charge emits recovery event")
	m = arena()
	e = m.add_archetype("EL2",Vector2(180,100))
	advance(m,1)
	var guard := 0
	while e.state != "idle" and guard < 400:
		m.step(Vector2.ZERO,Vector2.RIGHT)
		guard += 1
	check(guard < 400,"EL2 first charge cycle completes")
	m.player = Vector2(100,124)
	m.hp = 100
	m.protection = 0
	guard = 0
	while (e.state != "attack" or str(e.elite_attack) != "water") and guard < 300:
		m.step(Vector2.ZERO,Vector2.RIGHT)
		guard += 1
	check(guard < 300 and str(e.elite_attack) == "water","EL2 alternates charge then fixed water lane")
	var water: Array = m.field_hazards.filter(func(h): return h.kind == "water")
	check(water.size() == 1,"EL2 warns exactly one fixed water lane")
	check(water.size() == 1 and (water[0].rect as Rect2) == Rect2(0,112,320,24),"EL2 floods the fixed lane under the player")
	check(water.size() == 1 and free_lane_height(water[0].rect) >= 48.0,"water lane always leaves a 3-grid corridor")
	var warn_window: int = int(water[0].warn_until)-m.tick
	check(warn_window == 60,"EL2 water lane has a 1s warning")
	advance(m,60)
	check(m.hp == 90,"EL2 water lane deals 10 when it starts flowing")
	advance(m,60)
	check(m.hp == 80,"EL2 water lane deals 10 again one second later")
	advance(m,61)
	check(m.field_hazards.filter(func(h): return h.kind == "water").is_empty(),"EL2 water lane ends after two seconds")
	advance(m,60)
	check(m.hp == 80,"EL2 water lane does not deal a third tick")
	m.hp = 10000
	m.player = Vector2(100,90)
	var max_water := 0
	for i in 500:
		m.step(Vector2.ZERO,Vector2.RIGHT)
		max_water = maxi(max_water,m.field_hazards.filter(func(h): return h.kind == "water").size())
	check(max_water <= 1,"EL2 never floods both fixed lanes at once")
	guard = 0
	while (e.state != "attack" or str(e.elite_attack) != "charge") and guard < 400:
		m.step(Vector2.ZERO,Vector2.RIGHT)
		guard += 1
	check(guard < 400 and str(e.elite_attack) == "charge","EL2 returns to charge after the water lane")

	# ── T5 spore pod ────────────────────────────────────────────────────────
	m = arena()
	e = m.add_archetype("T5",Vector2(135,100))
	advance(m,20)
	hit(m,e,35)
	advance(m,70)
	check(m.zones.is_empty() and m.hp == 100,"early pod destruction suppresses explosion")
	m = arena()
	e = m.add_archetype("T5",Vector2(120,100))
	advance(m,48)
	check(m.hp == 100 and m.zones.is_empty(),"pod complete warning interval")
	advance(m,1)
	check(m.hp == 92 and m.zones.size() == 1 and e.hp == 0,"pod bursts once then leaves zone")
	advance(m,181)
	check(m.zones.is_empty(),"pod zone expires")

	# ── T4 guard ────────────────────────────────────────────────────────────
	m = arena()
	e = m.add_archetype("T4",Vector2(120,100))
	hit(m,e,24,"light")
	check(e.armor_layers == 1 and e.hp == 112,"guard light strips before reduction")
	hit(m,e,24,"light")
	check(e.armor_layers == 0 and e.hp == 88,"guard second light breaks shell")

	# ── EL1: elite shell + one readable half-health refit ──────────────────
	m = arena()
	e = m.add_archetype("EL1",Vector2(120,100))
	check(int(e.max_hp) == 450,"EL1 production 450 HP")
	advance(m,1)
	hit(m,e,18)
	check(e.state == "attack","elite windup resists ordinary hits")
	hit(m,e,24,"light")
	check(e.state == "attack","elite first shell strip is not break")
	hit(m,e,24,"light")
	check(e.state == "hurt","elite shell break interrupts")
	advance(m,8)
	e.armor_layers = 0
	e.hp = e.max_hp*0.5
	e.state = "idle"
	e.age = 0
	advance(m,1)
	check(e.state == "rearm" and bool(e.rearm_used),"EL1 half health starts one shell refit")
	check(m.history.any(func(event): return event.kind == "elite_rearm"),"EL1 shell refit emits a readable event")
	advance(m,47)
	check(e.state == "rearm" and int(e.armor_layers) == 0,"EL1 shell refit telegraph lasts 0.8s")
	advance(m,1)
	check(int(e.armor_layers) == 2 and e.state != "rearm","EL1 shell refit restores two layers after the telegraph")
	check(m.history.any(func(event): return event.kind == "elite_rearm_done"),"EL1 shell refit completion event")
	e.state = "idle"
	e.armor_layers = 0
	e.hp = e.max_hp*0.4
	advance(m,1)
	check(e.state != "rearm" and int(e.armor_layers) == 0,"EL1 can only refit its shell once")
	m = arena()
	for i in 4: m.add_archetype("T4",Vector2(116,84+i*9))
	advance(m,1)
	check(m.enemies.filter(func(x): return x.state == "attack").size() <= 2,"melee attack slots bounded")
	m = arena()
	for i in 3: m.add_archetype("T2",Vector2(175,75+i*25))
	advance(m,1)
	check(m.enemies.filter(func(x): return x.state == "attack").size() == 1,"ranged attack slot bounded")
	m = arena()
	e = m.add_archetype("T3",Vector2(180,100))
	m.player = Vector2(400,100)
	advance(m,5)
	check(e.state != "attack","offscreen player does not trigger new attacks")
	print("ENEMY_TEST checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
