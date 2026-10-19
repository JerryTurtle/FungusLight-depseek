extends SceneTree

const Model = preload("res://scripts/combat_model.gd")
var checks := 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("FAIL ",message)

func _initialize() -> void:
	var m = Model.new()
	m.reset()
	m.enemies.clear()
	m.walls.clear()
	var initial: Vector2 = m.player
	for i in range(60): m.step(Vector2.RIGHT,Vector2.RIGHT)
	var horizontal: float = m.player.distance_to(initial)
	m.reset()
	m.enemies.clear()
	m.walls.clear()
	initial = m.player
	for i in range(60): m.step(Vector2.ONE,Vector2.RIGHT)
	check(absf(m.player.distance_to(initial)-horizontal)/horizontal < 0.02,"A01 normalized diagonal")
	check(absf(horizontal-80) < 0.01,"A01 configured speed")
	for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
		for repetition in range(25):
			m.reset()
			m.enemies.clear()
			var target: Dictionary = m.add_enemy(m.player+direction*18,true)
			m.step(Vector2.ZERO,direction,"melee")
			check(m.action == "melee","A02 immediate start")
			for i in range(24): m.step(Vector2.ZERO,direction)
			check(target.hp == 54,"A03 once per swing")
	m.reset()
	m.enemies.clear()
	m.focus = 50
	m.step(Vector2.ZERO,Vector2.RIGHT,"melee")
	for i in range(24): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(is_equal_approx(m.focus,51.25),"A03 whiff grants regeneration only")
	m.reset()
	m.enemies.clear()
	m.walls.clear()
	m.walls.append(Rect2(150,32,12,40))
	m.player = Vector2(140,50)
	var hidden: Dictionary = m.add_enemy(Vector2(163,50),true)
	m.step(Vector2.ZERO,Vector2.RIGHT,"light")
	for i in range(29): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(hidden.hp == 72,"A04 beam wall occlusion")
	check(m.focus < 82,"A06 released beam costs focus")
	m.reset()
	m.enemies.clear()
	m.step(Vector2.RIGHT,Vector2.RIGHT,"dodge")
	check(not m.damage_player(12),"A05 dodge early invulnerability")
	for i in range(5): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.damage_player(12),"A05 invulnerability ends at tick six")
	m.reset()
	m.enemies.clear()
	m.step(Vector2.ZERO,Vector2.RIGHT,"light")
	m.step(Vector2.ZERO,Vector2.RIGHT,"dodge")
	check(m.focus == 100 and m.cooldowns.light == 0,"A06 windup cancel free")
	for i in range(20):
		m.reset()
		check(m.history.is_empty() and m.action == "idle" and m.attack_id == 0,"A09 reset state")
	check_batch_damage()
	check_body_collisions()
	check_navigation()
	check_hazards()
	check_input_boundaries()
	check_gate_edges()
	check_g2_spells()
	check_armor()
	print("G1_INITIAL_TESTS checks=",checks," failures=",failures.size())
	print("Partial checks only: A01-A09 gate is NOT yet passed.")
	quit(0 if failures.is_empty() else 1)

func check_batch_damage() -> void:
	# Drive both real active windows through step(), varying creation order.
	for enemy_first in [false,true]:
		var m = Model.new()
		m.reset()
		m.enemies.clear()
		var enemy: Dictionary = m.add_enemy(m.player+Vector2(18,0))
		enemy.hp = 18
		m.hp = 12
		m.focus = 50
		if enemy_first: enemy.attack_id = m.allocate_attack_id()
		m.begin("melee",Vector2.ZERO,Vector2.RIGHT)
		if not enemy_first: enemy.attack_id = m.allocate_attack_id()
		m.age = 6
		enemy.state = "attack"
		enemy.age = 24
		enemy.dir = Vector2.LEFT
		m.step(Vector2.ZERO,Vector2.RIGHT)
		check(enemy.hp == 0 and m.hp == 0,"A06 mutual lethal regardless creation order")
		check(m.action == "dead" and enemy.state == "dead","A06 commit both deaths")
		check(m.focus > 54 and m.focus < 55,"A06 melee credit survives earlier player hurt")
		var deaths := 0
		var hits := 0
		for event in m.events:
			if event.kind == "death": deaths += 1
			if event.kind in ["hit","hurt"]:
				hits += 1
				check(deaths == 0,"A06 death events after damage batch")
		check(hits == 2 and deaths == 2,"A06 exactly two hits and deaths")
		var last_id: int = m.attack_id
		m.step(Vector2.ZERO,Vector2.RIGHT,"melee",true)
		check(m.attack_id == last_id and m.events.is_empty(),"A06 dead actors cannot attack next step")
		check(m.damage_requests.is_empty(),"A09 batch cleared")
	# Enemies reordered in the scene list must not change first accepted source.
	for reverse_order in [false,true]:
		var m = Model.new()
		m.reset()
		m.enemies.clear()
		var first: Dictionary = m.add_enemy(m.player+Vector2(18,0))
		var second: Dictionary = m.add_enemy(m.player+Vector2(-18,0))
		for enemy in [first,second]:
			enemy.state = "attack"
			enemy.age = 24
			enemy.dir = (m.player-enemy.pos).normalized()
			enemy.attack_id = m.allocate_attack_id()
		if reverse_order: m.enemies.reverse()
		m.step(Vector2.ZERO,Vector2.RIGHT)
		check(m.hp == 88,"A06 same-batch protection prevents double damage")
		var accepted_sources: Array[int] = []
		for event in m.events:
			if event.kind == "hurt": accepted_sources.append(int(event.source))
		check(accepted_sources == [int(first.id)],"A06 stable attack creation order")
		check(m.age == 0 and m.protection == 30,"A06 hurt frame not consumed on application")
	# Stable IDs also order newly created attacks, not just existing requests.
	for reverse_order in [false,true]:
		var n = Model.new()
		n.reset()
		n.enemies.clear()
		var a: Dictionary = n.add_enemy(n.player+Vector2(18,0))
		var b: Dictionary = n.add_enemy(n.player+Vector2(-18,0))
		if reverse_order: n.enemies.reverse()
		n.step(Vector2.ZERO,Vector2.RIGHT)
		check(a.attack_id < b.attack_id,"A06 same-step creation independent of list order")
	# Duplicate requests and a dead source are rejected by the batch boundary.
	var m = Model.new()
	m.reset()
	m.enemies.clear()
	var enemy: Dictionary = m.add_enemy(m.player+Vector2(18,0))
	m.snapshot_living()
	var id: int = m.allocate_attack_id()
	m.queue_damage(enemy.id,0,id,12,"enemy_melee")
	m.queue_damage(enemy.id,0,id,12,"enemy_melee")
	m.resolve_damage_batch()
	check(m.hp == 88,"A03 duplicate request only once")
	enemy.hp = 0
	m.protection = 0
	m.snapshot_living()
	m.queue_damage(enemy.id,0,m.allocate_attack_id(),12,"enemy_melee")
	m.resolve_damage_batch()
	check(m.hp == 88,"A06 dead-at-step-start source rejected")
	m.reset()
	check(m.damage_requests.is_empty() and m.alive_at_step_start.is_empty() and m.next_attack_sequence == 0,"A09 reset batch and sequence")

func check_body_collisions() -> void:
	for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2.ONE.normalized()]:
		var m = Model.new()
		m.reset()
		m.enemies.clear()
		m.walls.clear()
		var start: Vector2 = m.player
		var enemy: Dictionary = m.add_enemy(start+direction*18,true)
		m.step(direction,direction,"dodge")
		for i in range(4): m.step(direction,direction)
		check(m.dodge_stopped,"A05 dodge latches after body collision")
		check(m.player.distance_to(enemy.pos) >= 9.999,"A05 dodge does not penetrate body")
		check(m.player.distance_to(start) < 9,"A05 dodge stops before body")
		var stopped: Vector2 = m.player
		enemy.pos += direction*80
		for i in range(6): m.step(Vector2.ZERO,direction)
		check(m.player.is_equal_approx(stopped),"A05 removing blocker does not resume same dodge")
		check(m.action == "idle" and m.cooldowns.dodge == 50,"A05 collision preserves duration and cooldown")
		m.reset()
		m.enemies.clear()
		m.walls.clear()
		start = m.player
		enemy = m.add_enemy(start+direction*18,true)
		for i in range(40): m.step(direction,direction)
		check(m.player.distance_to(enemy.pos) >= 9.999,"A01 walking respects bodies")
		check(m.hp == 100,"A01 contact alone causes no damage")
		# Sweep an enemy against the player through the same collision entry.
		enemy.pos = start+direction*40
		m.player = start
		enemy.pos = m.move_body(enemy.pos,-direction*80,true,int(enemy.id))
		check(enemy.pos.distance_to(m.player) >= 9.999 and (enemy.pos-m.player).dot(direction) > 0,"A01 enemy sweep cannot cross player")
	# Actual combat entry: a nonlethal hit applies six pixels of push.
	var m = Model.new()
	m.reset()
	m.enemies.clear()
	m.walls.clear()
	var target: Dictionary = m.add_enemy(m.player+Vector2(18,0),true)
	var start: Vector2 = target.pos
	m.step(Vector2.ZERO,Vector2.RIGHT,"melee")
	for i in range(6): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(target.hp == 54 and target.pos.is_equal_approx(start+Vector2(6,0)),"A06 melee hit pushes six pixels")
	# Push stops at a one-pixel wall and does not tunnel.
	m.reset()
	m.enemies.clear()
	m.walls.clear()
	target = m.add_enemy(m.player+Vector2(18,0),true)
	m.walls.append(Rect2(target.pos.x+7,50,1,90))
	m.step(Vector2.ZERO,Vector2.RIGHT,"melee")
	for i in range(6): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(not m.blocked(target.pos) and target.pos.x < 90,"A06 enemy knockback stops before thin wall")
	# Player hit next to a corner cannot push through either wall.
	m.reset()
	m.enemies.clear()
	m.walls.clear()
	m.player = Vector2(106,106)
	m.walls.append(Rect2(100,0,1,180))
	m.walls.append(Rect2(0,100,320,1))
	var attacker: Dictionary = m.add_enemy(Vector2(118,118))
	attacker.state = "attack"
	attacker.age = 24
	attacker.dir = (m.player-attacker.pos).normalized()
	attacker.attack_id = m.allocate_attack_id()
	start = m.player
	m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.hp == 88 and m.player.is_equal_approx(start),"A06 player corner knockback clipped")
	check(not m.blocked(m.player),"A06 player remains outside walls")
	# Dodge invulnerability rejects push as well as health damage.
	m.reset()
	m.enemies.clear()
	m.walls.clear()
	attacker = m.add_enemy(m.player+Vector2(18,0))
	attacker.state = "attack"
	attacker.age = 24
	attacker.dir = Vector2.LEFT
	attacker.attack_id = m.allocate_attack_id()
	start = m.player
	m.step(Vector2.ZERO,Vector2.RIGHT,"dodge")
	check(m.hp == 100 and m.action == "dodge","A05 invulnerable hit does not interrupt")
	check(is_equal_approx(m.player.distance_to(start),32.0/11),"A05 invulnerable hit does not add push")
	# Bodies stop knockback too.
	m.reset()
	m.enemies.clear()
	m.walls.clear()
	target = m.add_enemy(m.player+Vector2(18,0),true)
	var blocker: Dictionary = m.add_enemy(target.pos+Vector2(11,0),true)
	m.step(Vector2.ZERO,Vector2.RIGHT,"melee")
	for i in range(6): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(target.pos.distance_to(blocker.pos) >= 9.999,"A06 knockback cannot overlap another enemy")
	# Reset restores default map and all transient movement state.
	m.walls.clear()
	m.dodge_stopped = true
	m.knockbacks[0] = Vector2.ONE
	m.reset()
	check(m.walls == Model.DEFAULT_WALLS and not m.dodge_stopped and m.knockbacks.is_empty(),"A09 restore map and movement state")
	m.enemies.clear()
	for i in range(100): m.step(Vector2.UP,Vector2.UP)
	check(m.player.y >= 32,"A12 player cannot enter top HUD")
	for i in range(150): m.step(Vector2.DOWN,Vector2.DOWN)
	check(m.player.y <= 154,"A12 player cannot enter bottom HUD")

func check_navigation() -> void:
	for layout in ["corner","ring","narrow"]:
		var m = Model.new()
		m.reset()
		m.enemies.clear()
		m.doors.clear()
		m.walls.clear()
		m.walls.append(Rect2(0,0,320,27))
		m.walls.append(Rect2(0,159,320,21))
		m.walls.append(Rect2(0,0,8,180))
		m.walls.append(Rect2(312,0,8,180))
		m.player = Vector2(100,95)
		var enemy: Dictionary = m.add_enemy(Vector2(210,95))
		enemy.alert = true
		if layout == "corner":
			m.walls.append(Rect2(150,60,12,70))
		elif layout == "ring":
			m.walls.append(Rect2(140,60,12,70))
			m.walls.append(Rect2(140,60,72,10))
			m.walls.append(Rect2(140,120,72,10))
		else:
			m.walls.append(Rect2(150,27,12,53))
			m.walls.append(Rect2(150,96,12,63))
		var traversed_safely := true
		for frame in range(900):
			m.step(Vector2.ZERO,Vector2.RIGHT)
			if m.blocked(enemy.pos): traversed_safely = false
			if enemy.pos.distance_to(m.player) <= 20: break
		check(enemy.pos.distance_to(m.player) <= 20,"A15 reaches player around "+layout)
		check(traversed_safely,"A15 no wall penetration "+layout)
		check(m.path_queries <= ceili(float(m.tick)/15)+1,"A15 bounded path query rate "+layout)
	# Door occupancy, occlusion and reopening all use the same rectangle.
	var m = Model.new()
	m.reset()
	m.enemies.clear()
	m.player = Vector2(156,90)
	check(not m.set_door_open("test_gate",false),"A15 refuse door closure on player")
	m.player = Vector2(125,90)
	var enemy: Dictionary = m.add_enemy(Vector2(156,90))
	check(not m.set_door_open("test_gate",false),"A15 refuse door closure on enemy")
	enemy.pos = Vector2(185,90)
	enemy.spawn = enemy.pos
	enemy.alert = true
	check(m.set_door_open("test_gate",false),"A15 close empty doorway")
	check(m.blocked(Vector2(156,90)) and not m.clear_line(m.player,enemy.pos),"A15 closed door blocks body and ray")
	for frame in range(60): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.hp == 100 and enemy.pos.x > 162,"A15 closed door prevents attacks and crossing")
	check(m.set_door_open("test_gate",true),"A15 reopen doorway")
	for frame in range(150):
		m.step(Vector2.ZERO,Vector2.RIGHT)
		if enemy.pos.distance_to(m.player) <= 20: break
	check(enemy.pos.distance_to(m.player) <= 20,"A15 reopening invalidates stale path")
	# No line of sight means no initial aggro through the wall.
	m.reset()
	m.enemies.clear()
	m.player = Vector2(140,50)
	enemy = m.add_enemy(Vector2(174,50))
	for frame in range(30): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(not enemy.alert and enemy.pos == enemy.spawn and m.hp == 100,"A15 no through-wall initial aggro")
	# A fully sealed route recovers at a safe spawn, without a death/reward event.
	m.reset()
	m.enemies.clear()
	m.player = Vector2(125,90)
	enemy = m.add_enemy(Vector2(230,90))
	enemy.pos = Vector2(185,90)
	enemy.alert = true
	m.set_door_open("test_gate",false)
	for frame in range(185): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(enemy.pos == enemy.spawn and not enemy.alert,"A15 failed route recovers after three seconds")
	var recoveries := 0
	var deaths := 0
	for event in m.history:
		if event.kind == "enemy_recovered": recoveries += 1
		if event.kind == "death": deaths += 1
	check(recoveries == 1 and deaths == 0,"A15 recovery is not a kill or repeated reward")
	# Safe recovery must not overlap another actor occupying the spawn.
	m.reset()
	m.enemies.clear()
	m.player = Vector2(125,90)
	enemy = m.add_enemy(Vector2(230,90))
	enemy.pos = Vector2(185,90)
	enemy.alert = true
	var occupant: Dictionary = m.add_enemy(enemy.spawn,true)
	m.set_door_open("test_gate",false)
	for frame in range(185): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(enemy.pos.distance_to(occupant.pos) >= 10 and enemy.pos != enemy.spawn,"A15 occupied spawn prevents unsafe recovery")
	# After 2 seconds out of sight and beyond leash, return without attacking.
	m.reset()
	m.enemies.clear()
	m.player = Vector2(290,90)
	m.walls.append(Rect2(150,27,12,132))
	enemy = m.add_enemy(Vector2(70,90))
	enemy.pos = Vector2(110,90)
	enemy.hp = 36
	enemy.alert = true
	for frame in range(240): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(enemy.pos == enemy.spawn and enemy.hp == 36 and not enemy.alert,"A15 lost sight returns without healing")
	var returned := 0
	for event in m.history:
		if event.kind == "enemy_returned": returned += 1
	check(returned == 1 and m.hp == 100,"A15 return is single and nonattacking")
	# Trigger radius exceeds hit radius: the specified short lunge must bridge it.
	m.reset()
	m.enemies.clear()
	enemy = m.add_enemy(m.player+Vector2(19,0))
	for frame in range(27): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.hp == 88,"A15 enemy naturally lands attack from trigger distance")
	m.reset()
	check(m.doors[0].open and m.navigation_revision == 0 and m.path_queries == 0,"A09 reset door and navigation")

func hazard_world():
	var m = Model.new()
	m.reset()
	m.enemies.clear()
	m.walls.clear()
	m.doors.clear()
	return m

func check_hazards() -> void:
	var m = hazard_world()
	m.spawn_projectile(Vector2(10,95),Vector2(6000,0))
	m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.hp == 90 and m.projectiles.is_empty(),"A07 fast projectile hits crossed target exactly once")
	for frame in range(40): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.hp == 90,"A07 consumed projectile cannot repeat damage")
	m = hazard_world()
	m.walls.append(Rect2(40.25,80,0.1,30))
	m.spawn_projectile(Vector2(10,95),Vector2(6000,0))
	m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.hp == 100 and m.projectiles.is_empty(),"A07 subpixel thin wall blocks high speed")
	m = hazard_world()
	m.config.player.hurt_radius = 0.1
	var shot: Dictionary = m.spawn_projectile(Vector2(10,95),Vector2(6000,0))
	shot.radius = 0.1
	m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.hp == 90,"A07 sweep cannot miss subpixel target")
	m = hazard_world()
	m.player = Vector2(70,95)
	m.walls.append(Rect2(40,60,1,30))
	shot = m.spawn_projectile(Vector2(10,92),Vector2(6000,0))
	m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.hp == 100 and m.projectiles.is_empty(),"A07 projectile radius blocks edge graze")
	# Actual released projectile survives its source's later death.
	m = hazard_world()
	var source: Dictionary = m.add_enemy(Vector2(10,95),true)
	m.spawn_projectile(source.pos,Vector2(6000,0),int(source.id))
	source.hp = 0
	m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.hp == 90,"A06 released projectile survives attacker death")
	check(m.spawn_projectile(source.pos,Vector2.RIGHT,int(source.id)).is_empty(),"A06 dead source cannot emit new projectile")
	# Invulnerability consumes the projectile, without knockback or delayed hit.
	m = hazard_world()
	var before: Vector2 = m.player
	m.protection = 2
	m.spawn_projectile(Vector2(10,95),Vector2(6000,0))
	m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.hp == 100 and m.player == before and m.projectiles.is_empty(),"A05 projectile respects invulnerability")
	m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.hp == 100,"A07 rejected projectile does not hit next tick")
	# Zone damage is periodic, does not interrupt and never grants hurt protection.
	m = hazard_world()
	m.spawn_zone(m.player)
	for frame in range(59): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.hp == 100,"A07 zone has no per-frame damage")
	m.step(Vector2.ZERO,Vector2.RIGHT,"melee")
	check(m.hp == 96 and m.action == "melee" and m.protection == 0,"A07 DOT does not stun or refresh protection")
	for frame in range(120): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.hp == 88 and m.zones.is_empty(),"A07 three-second zone has three ticks and expires")
	m = hazard_world()
	m.spawn_zone(m.player)
	for frame in range(59): m.step(Vector2.ZERO,Vector2.RIGHT)
	m.protection = 2
	m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.hp == 100,"A07 protected DOT tick skipped")
	for frame in range(59): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.hp == 100,"A07 skipped DOT not replayed after protection")
	m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.hp == 96,"A07 next scheduled DOT proceeds")
	m = hazard_world()
	m.spawn_zone(m.player+Vector2(30,0))
	for frame in range(60): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.hp == 100,"A07 outside zone takes no damage")
	m = hazard_world()
	m.walls.append(Rect2(80,60,1,70))
	m.spawn_zone(m.player+Vector2(20,0))
	for frame in range(60): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.hp == 100,"A07 zone does not damage across wall")
	# Limits, lifetime, viewport cleanup, and twenty full retries.
	m = hazard_world()
	for i in range(21): m.spawn_projectile(Vector2(20,40),Vector2.ZERO)
	check(m.projectiles.size() == 20,"A07 projectile count cap")
	for frame in range(120): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.projectiles.is_empty(),"A07 expired projectiles cleaned")
	m.spawn_projectile(Vector2(310,40),Vector2(6000,0))
	m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.projectiles.is_empty(),"A07 offscreen projectile cleaned")
	for i in range(20):
		m.spawn_projectile(Vector2(20,40),Vector2.RIGHT)
		m.spawn_zone(Vector2(90,130))
		m.reset()
		check(m.projectiles.is_empty() and m.zones.is_empty(),"A09 retry clears all hazards")
	m = hazard_world()
	m.hp = 4
	m.spawn_zone(m.player)
	m.spawn_projectile(Vector2(20,40),Vector2.ZERO)
	for frame in range(60): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.hp == 0 and m.action == "dead" and m.projectiles.is_empty() and m.zones.is_empty(),"A09 player death clears independent hazards")
	check(m.spawn_zone(m.player).is_empty() and m.spawn_projectile(Vector2(20,40),Vector2.ZERO).is_empty(),"A09 no hazard creation after death")

func check_input_boundaries() -> void:
	for state in ["melee","light"]:
		for frame in range(22 if state == "melee" else 27):
			var m = hazard_world()
			m.begin(state,Vector2.ZERO,Vector2.RIGHT)
			m.age = frame
			var expected: bool = frame >= 16 if state == "melee" else (frame < 12 or frame >= 21)
			check(m.can_start("dodge") == expected,"A06 cancel window %s/%d" % [state,frame])
	# Last seven ticks queue one action; repeated invalid input cannot starve it.
	var m = hazard_world()
	m.begin("melee",Vector2.ZERO,Vector2.RIGHT)
	m.age = 15
	m.step(Vector2.ZERO,Vector2.RIGHT,"light")
	check(m.buffered == "light" and m.buffer_ttl == 7,"A02 queue at seven-tick boundary")
	for frame in range(7): m.step(Vector2.ZERO,Vector2.RIGHT,"nonsense")
	check(m.action == "light" and m.age == 1 and m.buffered.is_empty(),"A02 invalid commands cannot starve ready buffer")
	var starts := 0
	for event in m.history:
		if event.kind == "action" and event.action == "light": starts += 1
	check(starts == 1,"A02 cached command starts once")
	for frame in range(60): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.action == "idle","A02 no second cached action")
	m = hazard_world()
	m.begin("melee",Vector2.ZERO,Vector2.RIGHT)
	m.age = 14
	m.step(Vector2.ZERO,Vector2.RIGHT,"light")
	check(m.buffered.is_empty(),"A02 eight-tick early input not buffered")
	m = hazard_world()
	m.begin("dodge",Vector2.ZERO,Vector2.RIGHT)
	m.age = 4
	m.step(Vector2.ZERO,Vector2.RIGHT,"light")
	m.focus = 0
	for frame in range(9): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.buffered.is_empty() and m.action == "idle","A02 unaffordable buffer expires")
	m = hazard_world()
	m.step_commands(Vector2.ZERO,Vector2.RIGHT,["light","melee","dodge"])
	check(m.action == "dodge","A02 same-tick priority dodge first")
	m = hazard_world()
	m.cooldowns.dodge = 20
	m.step_commands(Vector2.ZERO,Vector2.RIGHT,["dodge","light","melee"])
	check(m.action == "light","A02 invalid high priority falls back")
	m = hazard_world()
	m.cooldowns.dodge = 1
	m.step_commands(Vector2.ZERO,Vector2.RIGHT,["dodge","light"])
	check(m.action == "dodge","A02 cooldown-ready tick is eligible")
	m = hazard_world()
	m.begin("melee",Vector2.ZERO,Vector2.RIGHT)
	m.age = 15
	m.step(Vector2.ZERO,Vector2.RIGHT,"light")
	m.step(Vector2.ZERO,Vector2.RIGHT,"dodge")
	check(m.action == "dodge" and m.buffered.is_empty() and m.buffer_ttl == 0,"A02 immediate action consumes old buffer")
	m = hazard_world()
	for frame in range(66): m.step(Vector2.ZERO,Vector2.RIGHT,"",true)
	starts = 0
	for event in m.history:
		if event.kind == "action": starts += 1
	check(starts == 3 and m.action == "idle","A02 held melee repeats complete 22-tick actions")

func check_gate_edges() -> void:
	for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
		for sample in [[21.9,0.0,true],[22.1,0.0,false],[18.0,44.9,true],[18.0,45.1,false],[18.0,180.0,false]]:
			var m = hazard_world()
			var target: Dictionary = m.add_enemy(m.player+direction.rotated(deg_to_rad(sample[1]))*sample[0],true)
			m.step(Vector2.ZERO,direction,"melee")
			for i in range(6): m.step(Vector2.ZERO,direction)
			check((target.hp == 54) == sample[2],"A04 four-direction radial/angular edge")
		var m = hazard_world()
		var target: Dictionary = m.add_enemy(m.player+direction*20,true)
		var midpoint: Vector2 = m.player+direction*10
		m.walls.append(Rect2(midpoint-Vector2(1,8),Vector2(2,16)) if direction.x != 0 else Rect2(midpoint-Vector2(8,1),Vector2(16,2)))
		m.step(Vector2.ZERO,direction,"melee")
		for i in range(24): m.step(Vector2.ZERO,direction)
		check(target.hp == 72,"A04 four-direction wall blocks melee")
	var m = hazard_world()
	m.focus = 50
	var a: Dictionary = m.add_enemy(m.player+Vector2(18,-6),true)
	var b: Dictionary = m.add_enemy(m.player+Vector2(18,6),true)
	m.step(Vector2.ZERO,Vector2.RIGHT,"melee")
	for i in range(6): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(a.hp == 54 and b.hp == 54,"A04 one swing hits multiple valid targets")
	check(is_equal_approx(m.focus,54.35),"A03 multiple targets grant focus only once")
	m = hazard_world()
	a = m.add_enemy(m.player+Vector2(18,0),true)
	a.hp = 0
	m.focus = 50
	m.step(Vector2.ZERO,Vector2.RIGHT,"melee")
	for i in range(6): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(is_equal_approx(m.focus,50.35),"A03 corpse grants no focus")
	m = hazard_world()
	a = m.add_enemy(m.player+Vector2(30,0),true)
	b = m.add_enemy(m.player+Vector2(60,0),true)
	m.enemies.reverse()
	m.step(Vector2.ZERO,Vector2.RIGHT,"light")
	for i in range(12): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(a.hp == 48 and b.hp == 48,"A04 beam hits every enemy on its path")
	var paid_focus: float = m.focus
	var paid_cooldown: int = m.cooldowns.light
	m.damage_player(12)
	check(m.focus == paid_focus and m.cooldowns.light == paid_cooldown,"A06 released skill never refunded on interruption")
	for boundary in range(12):
		m = hazard_world()
		m.begin("dodge",Vector2.RIGHT,Vector2.RIGHT)
		for i in range(boundary): m.step(Vector2.ZERO,Vector2.RIGHT)
		check(m.damage_player(1) == (boundary >= 6),"A05 full dodge invulnerability boundary %d" % boundary)
	m = hazard_world()
	m.step(Vector2.RIGHT,Vector2.RIGHT,"dodge")
	for i in range(59): m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.cooldowns.dodge == 1,"A05 cooldown one tick before ready")
	m.step(Vector2.ZERO,Vector2.RIGHT,"dodge")
	check(m.action == "dodge" and m.cooldowns.dodge == 60,"A05 cooldown ready exact tick")
	m = hazard_world()
	m.player = Vector2(90,80)
	m.walls.append(Rect2(100,50,8,60))
	var clear := true
	for i in range(60):
		m.step(Vector2(1,1),Vector2.RIGHT)
		clear = clear and not m.blocked(m.player)
	check(clear and m.player.y > 115,"A01 continuous corner slide stays clear")
	for i in range(25): m.step(Vector2.RIGHT,Vector2.RIGHT)
	check(m.player.x > 110,"A01 leaves wall corner without sticking")
func spell_fixture():
	var m = Model.new()
	m.reset()
	m.enemies.clear()
	return m

func check_g2_spells() -> void:
	var m = spell_fixture()
	m.step(Vector2.ZERO,Vector2.RIGHT,"shield")
	for i in 8: m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.shield_hp == 0 and m.focus == 100,"shield windup has no effect or charge")
	m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.shield_hp == 25 and m.cooldowns.shield == 480 and m.focus == 75,"shield release charges once")
	m.damage_player(12)
	check(m.hp == 100 and m.shield_hp == 13 and m.action == "hurt" and m.protection == 30,"full shield absorption still interrupts and protects")
	m.damage_player(12)
	check(m.shield_hp == 13,"protection does not consume shield")
	m.protection = 0
	m.damage_player(20)
	check(m.hp == 93 and m.shield_hp == 0 and m.shield_until == 0,"shield overflow and break")
	m = spell_fixture()
	m.step(Vector2.ZERO,Vector2.RIGHT,"shield")
	for i in 9: m.step(Vector2.ZERO,Vector2.RIGHT)
	for i in 119: m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.shield_hp == 25,"shield alive before expiry boundary")
	m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.shield_hp == 0,"shield expires at exact 120 tick boundary")
	m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.events.filter(func(e): return e.kind == "shield_end").is_empty(),"shield expiry emitted once")
	for command in ["shield","rain"]:
		m = spell_fixture()
		m.step(Vector2.ZERO,Vector2(40,0),command)
		m.step(Vector2.ZERO,Vector2.RIGHT,"dodge")
		check(m.action == "dodge" and m.focus == 100 and m.cooldowns[command] == 0,"spell windup cancellation free "+command)
		m = spell_fixture()
		m.step(Vector2.ZERO,Vector2(40,0),command)
		m.damage_player(5)
		for i in 40: m.step(Vector2.ZERO,Vector2.RIGHT)
		check(m.shield_hp == 0 and m.rains.is_empty() and m.cooldowns[command] == 0,"hurt cancels spell before release "+command)
	m = spell_fixture()
	m.step_commands(Vector2.ZERO,Vector2(40,0),["rain","light","shield","melee"])
	check(m.action == "shield","shield has priority over other spells")
	for target in [Vector2(113,0),Vector2(85,-40),Vector2(0,-90)]:
		m = spell_fixture()
		m.step(Vector2.ZERO,target,"rain")
		check(m.action == "idle" and m.focus == 100,"rain rejects range wall or outside world "+str(target))
	m = spell_fixture()
	var target = m.add_enemy(Vector2(110,95),true)
	m.step(Vector2.ZERO,Vector2(40,0),"rain")
	for i in 20: m.step(Vector2.ZERO,Vector2(-20,0))
	check(m.rains.is_empty() and m.focus == 100,"rain waits for release")
	m.step(Vector2.ZERO,Vector2(-20,0))
	check(m.rains.size() == 1 and m.rains[0].pos == Vector2(110,95),"rain locks initial aim")
	check(m.focus == 65 and m.cooldowns.rain == 360,"rain charges at release")
	for i in 29: m.step(Vector2.ZERO,Vector2.RIGHT)
	check(target.hp == 72,"rain no early damage")
	m.step(Vector2.ZERO,Vector2.RIGHT)
	check(target.hp == 27,"rain impacts once after 30 steps")
	for i in 16: m.step(Vector2.ZERO,Vector2.RIGHT)
	check(target.hp == 27 and m.rains.is_empty(),"rain no repeated damage and clears afterglow")
	m = spell_fixture()
	target = m.add_enemy(Vector2(110,95),true)
	m.step(Vector2.ZERO,Vector2(40,0),"rain")
	for i in 21: m.step(Vector2.ZERO,Vector2.RIGHT)
	target.pos = Vector2(140,95)
	var newcomer = m.add_enemy(Vector2(110,95),true)
	for i in 2: m.step(Vector2.ZERO,Vector2.RIGHT)
	m.step(Vector2.ZERO,Vector2.LEFT,"dodge")
	check(m.action == "dodge" and m.rains.size() == 1,"released rain survives recovery cancel")
	for i in 30: m.step(Vector2.ZERO,Vector2.RIGHT)
	check(target.hp == 72 and newcomer.hp == 27,"rain queries current positions at impact")
	m = spell_fixture()
	m.step(Vector2.ZERO,Vector2(40,0),"rain")
	m.walls.append(Rect2(90,80,2,30))
	for i in 21: m.step(Vector2.ZERO,Vector2.RIGHT)
	check(m.rains.is_empty() and m.focus == 100 and m.cooldowns.rain == 0,"rain revalidates new wall at release without charge")
	m = spell_fixture()
	m.step(Vector2.ZERO,Vector2(40,0),"rain")
	for i in 21: m.step(Vector2.ZERO,Vector2.RIGHT)
	m.shield_hp = 25
	m.reset()
	check(m.shield_hp == 0 and m.rains.is_empty() and m.cooldowns.rain == 0,"reset clears new spell state")
	m = spell_fixture()
	m.step(Vector2.ZERO,Vector2(40,0),"rain")
	for i in 21: m.step(Vector2.ZERO,Vector2.RIGHT)
	m.damage_player(200)
	check(m.rains.is_empty() and m.shield_hp == 0,"death clears released spells")
	m = spell_fixture()
	m.shield_hp = 25
	m.shield_until = 100
	m.step(Vector2.ZERO,Vector2.RIGHT,"dodge")
	m.damage_player(12)
	check(m.shield_hp == 25 and m.hp == 100,"dodge rejects damage before shield consumption")
	m.action = "idle"
	m.apply_player_damage(4,10,-1,true)
	check(m.shield_hp == 21 and m.hp == 100 and m.action == "idle" and m.protection == 0,"shield absorbs DOT without stun or protection")
	m = spell_fixture()
	m.step(Vector2.ZERO,Vector2(40,0),"rain")
	for i in 21: m.step(Vector2.ZERO,Vector2.RIGHT)
	m.damage_player(4)
	check(m.rains.size() == 1 and m.cooldowns.rain == 360 and m.focus == 65,"released rain survives hurt without refund")
	for offset in [Vector2(27.9,0),Vector2(28.1,0),Vector2(0,27.9),Vector2(0,28.1)]:
		m = spell_fixture()
		target = m.add_enemy(Vector2(110,95)+offset,true)
		m.step(Vector2.ZERO,Vector2(40,0),"rain")
		for i in 51: m.step(Vector2.ZERO,Vector2.RIGHT)
		check(target.hp == (27 if offset.length() < 28 else 72),"rain radius boundary "+str(offset))
	m = spell_fixture()
	target = m.add_enemy(Vector2(130,95),true)
	m.step(Vector2.ZERO,Vector2(40,0),"rain")
	for i in 21: m.step(Vector2.ZERO,Vector2.RIGHT)
	m.walls.append(Rect2(120,80,2,30))
	for i in 30: m.step(Vector2.ZERO,Vector2.RIGHT)
	check(target.hp == 72,"rain impact does not cross newly inserted wall")
func check_armor() -> void:
	for layers in [0,1,2,9]:
		for kind in ["melee","light","rain"]:
			var m = spell_fixture()
			var target = m.add_enemy(Vector2(100,95),true)
			target.armor_layers = layers
			m.snapshot_living()
			var id: int = m.allocate_attack_id()
			m.queue_damage(0,target.id,id,24,kind)
			m.queue_damage(0,target.id,id,24,kind)
			m.resolve_damage_batch()
			var remaining: int = mini(layers,2)
			if kind == "light": remaining = maxi(0,remaining-1)
			check(target.hp == 72-24*(1-remaining*0.25),"armor damage once "+kind+str(layers))
			check(target.armor_layers == remaining,"armor strip before damage "+kind+str(layers))
			check(m.events.filter(func(e): return e.kind == "armor_break").size() == (1 if kind == "light" and layers == 1 else 0),"armor break exactly once "+kind+str(layers))
	var m = spell_fixture()
	var target = m.add_enemy(Vector2(100,95),true)
	target.armor_layers = 2
	for i in 3:
		m.snapshot_living()
		m.queue_damage(0,target.id,m.allocate_attack_id(),1,"light")
		m.resolve_damage_batch()
	check(m.history.filter(func(e): return e.kind == "armor_break").size() == 1,"repeated light only breaks last layer once")
	m.reset()
	check(m.enemies[0].armor_layers == 0,"reset removes test armor")
