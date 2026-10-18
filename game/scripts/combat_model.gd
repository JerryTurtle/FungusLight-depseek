extends RefCounted
## Fixed-tick simulation shared by gameplay input and automated replay.
## G1 prototype. No rendering or wall-clock timing in combat rules.

var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/actions.json"))
var tick := 0
var player := Vector2(70, 95)
var facing := Vector2.RIGHT
var hp := 100.0
var focus := 100.0
var action := "idle"
var age := 0
var locked := Vector2.RIGHT
var attack_id := 0
var hit_targets: Dictionary = {}
var focus_awarded := false
var protection := 0
var cooldowns: Dictionary = {"dodge":0, "light":0, "shield":0, "rain":0}
const DEFAULT_WALLS: Array[Rect2] = [Rect2(0,0,320,27),Rect2(0,159,320,21),Rect2(0,0,8,180),Rect2(312,0,8,180),Rect2(150,32,12,40),Rect2(150,110,12,38)]
var walls: Array[Rect2] = DEFAULT_WALLS.duplicate()
var blockers: Array[Rect2] = []
var npcs: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var events: Array[Dictionary] = []
var history: Array[Dictionary] = []
var beam_end := Vector2.ZERO
var beam_from := Vector2.ZERO
var buffered := ""
var buffer_ttl := 0
var buffer_until := 0
var next_id := 1
var next_attack_sequence := 0
var damage_requests: Array[Dictionary] = []
var alive_at_step_start: Dictionary = {}
var resolving_batch := false
var player_interrupted_this_step := false
var dodge_stopped := false
var knockbacks: Dictionary = {}
var navigator = preload("res://scripts/grid_navigation.gd").new()
var doors: Array[Dictionary] = []
var navigation_revision := 0
var path_queries := 0
const Sweep = preload("res://scripts/sweep.gd")
var projectiles: Array[Dictionary] = []
var zones: Array[Dictionary] = []
var shield_hp := 0.0
var shield_until := 0
var requested_target := Vector2.ZERO
var rain_target := Vector2.ZERO
var rains: Array[Dictionary] = []
var healing_enabled := false
var potions := 3

func reset() -> void:
	clear_hazards()
	walls = DEFAULT_WALLS.duplicate()
	blockers.clear()
	npcs.clear()
	doors = [{"id":"test_gate","rect":Rect2(150,72,12,38),"open":true}]
	navigation_revision = 0
	path_queries = 0
	dodge_stopped = false
	knockbacks.clear()
	tick = 0
	player = Vector2(70,95)
	facing = Vector2.RIGHT
	hp = 100
	focus = 100
	action = "idle"
	age = 0
	attack_id = 0
	protection = 0
	buffered = ""
	buffer_ttl = 0
	buffer_until = 0
	hit_targets.clear()
	cooldowns = {"dodge":0,"light":0,"shield":0,"rain":0}
	enemies.clear()
	history.clear()
	events.clear()
	next_id = 1
	next_attack_sequence = 0
	damage_requests.clear()
	alive_at_step_start.clear()
	resolving_batch = false
	player_interrupted_this_step = false
	potions = 3
	beam_from = Vector2.ZERO
	beam_end = Vector2.ZERO
	add_enemy(Vector2(112,95), true)
	add_enemy(Vector2(240,90), false)

func add_enemy(pos: Vector2, dummy: bool = false) -> Dictionary:
	var enemy := {"id":next_id,"pos":pos,"hp":72.0,"dummy":dummy,"state":"idle","age":0,"dir":Vector2.LEFT,"hit":false,"stun_cd":0,"attack_id":0,"death_committed":false,"armor_layers":0}
	enemy.merge({"spawn":pos,"alert":false,"returning":false,"lost_ticks":0,"path":[],"repath":0,"nav_revision":-1,"stuck":0})
	next_id += 1
	enemies.append(enemy)
	return enemy

func emit(kind: String, fields: Dictionary = {}) -> void:
	var event := fields.duplicate()
	event["tick"] = tick
	event["kind"] = kind
	events.append(event)
	history.append(event)
	if history.size() > 4096:
		history.pop_front()

func blocked(pos: Vector2, radius: float = 5.0) -> bool:
	for wall in walls:
		if wall.grow(radius).has_point(pos):
			return true
	for door in doors:
		if not door.open and door.rect.grow(radius).has_point(pos): return true
	for blocker in blockers:
		if blocker.grow(radius).has_point(pos): return true
	for npc in npcs:
		if pos.distance_to(npc.pos) < radius+float(npc.radius)-0.0001: return true
	return false

func set_door_open(id: String, opened: bool) -> bool:
	for door in doors:
		if door.id != id: continue
		if door.open == opened: return true
		if not opened:
			if hp > 0 and door.rect.grow(float(config.player.body_radius)).has_point(player):
				emit("door_blocked", {"id":id})
				return false
			for enemy in enemies:
				if enemy.hp > 0 and door.rect.grow(float(config.enemy_t1.body_radius)).has_point(enemy.pos):
					emit("door_blocked", {"id":id})
					return false
		door.open = opened
		navigation_revision += 1
		emit("door_changed", {"id":id,"open":opened})
		return true
	return false

func clear_body_path(start: Vector2, finish: Vector2) -> bool:
	var count := maxi(1,ceili(start.distance_to(finish)))
	for i in range(count+1):
		if blocked(start.lerp(finish,float(i)/count),float(config.enemy_t1.body_radius)): return false
	return true

func navigate_enemy(enemy: Dictionary, goal: Vector2) -> void:
	enemy.repath = maxi(0,int(enemy.repath)-1)
	if enemy.nav_revision != navigation_revision:
		enemy.path.clear()
		enemy.nav_revision = navigation_revision
		enemy.repath = 0
	var target := goal
	if not clear_body_path(enemy.pos,goal):
		if enemy.repath <= 0:
			enemy.path = navigator.route(enemy.pos,goal,clear_body_path)
			enemy.repath = int(config.enemy_t1.repath_ticks)
			path_queries += 1
		while not enemy.path.is_empty() and enemy.pos.distance_to(enemy.path[0]) < 1:
			enemy.path.pop_front()
		if enemy.path.is_empty():
			enemy.stuck += 1
			recover_stuck_enemy(enemy)
			return
		target = enemy.path[0]
	else:
		enemy.path.clear()
	var delta: Vector2 = target-enemy.pos
	var distance := minf(delta.length(),float(enemy.get("speed",config.enemy_t1.speed))/60)
	var before: Vector2 = enemy.pos
	enemy.pos = move_body(enemy.pos,delta.normalized()*distance,false,int(enemy.id))
	if enemy.pos.distance_to(before) < 0.01:
		# Local sidestep is deterministic and respects all body collisions.
		for angle in [PI/4,-PI/4,PI/2,-PI/2]:
			var candidate := move_body(before,delta.normalized().rotated(angle)*distance,true,int(enemy.id))
			if candidate.distance_to(before) > 0.1:
				enemy.pos = candidate
				break
	if enemy.pos.distance_to(before) < 0.01: enemy.stuck += 1
	else: enemy.stuck = 0
	recover_stuck_enemy(enemy)

func recover_stuck_enemy(enemy: Dictionary) -> void:
	if enemy.stuck < int(config.enemy_t1.failed_path_ticks): return
	if body_blocked(enemy.spawn,int(enemy.id)): return
	enemy.pos = enemy.spawn
	enemy.state = "idle"
	enemy.returning = false
	enemy.alert = false
	enemy.lost_ticks = 0
	enemy.path.clear()
	enemy.stuck = 0
	enemy.hp = float(enemy.get("max_hp",config.enemy_t1.hp))
	emit("enemy_recovered", {"target":enemy.id})

func body_blocked(pos: Vector2, mover_id: int) -> bool:
	var radius := float(config.player.body_radius if mover_id == 0 else config.enemy_t1.body_radius)
	if blocked(pos,radius): return true
	if mover_id != 0 and hp > 0 and pos.distance_to(player) < radius+float(config.player.body_radius)-0.0001:
		return true
	for enemy in enemies:
		if enemy.id != mover_id and enemy.hp > 0 and pos.distance_to(enemy.pos) < radius+float(config.enemy_t1.body_radius)-0.0001:
			return true
	return false

func move_body(pos: Vector2, displacement: Vector2, stop_on_collision: bool = false, mover_id: int = 0) -> Vector2:
	var steps := maxi(1, ceili(displacement.length()))
	var part := displacement / steps
	for i in range(steps):
		if stop_on_collision and body_blocked(pos + part,mover_id):
			break
		if not body_blocked(pos + Vector2(part.x,0),mover_id):
			pos.x += part.x
		if not body_blocked(pos + Vector2(0,part.y),mover_id):
			pos.y += part.y
	return pos

func wall_blocked(pos: Vector2, radius: float = 0.0) -> bool:
	for wall in walls:
		if wall.grow(radius).has_point(pos): return true
	for door in doors:
		if not door.open and door.rect.grow(radius).has_point(pos): return true
	return false

func clear_wall_line(start: Vector2, finish: Vector2) -> bool:
	# Interaction sight: props may sit on the target, walls still block.
	var count := maxi(1,ceili(start.distance_to(finish)))
	for i in range(count+1):
		if wall_blocked(start.lerp(finish,float(i)/count)): return false
	return true

func clear_line(start: Vector2, finish: Vector2) -> bool:
	var count := maxi(1, ceili(start.distance_to(finish)))
	for i in range(count + 1):
		if blocked(start.lerp(finish, float(i)/count),0):
			return false
	return true

func cardinal(direction: Vector2) -> Vector2:
	if is_equal_approx(absf(direction.x), absf(direction.y)):
		return facing
	if absf(direction.x) > absf(direction.y):
		return Vector2(signf(direction.x),0)
	return Vector2(0,signf(direction.y))

func can_start(command: String) -> bool:
	if hp <= 0 or command not in ["melee","light","shield","rain","dodge","heal"]:
		return false
	if command == "heal" and (not healing_enabled or potions <= 0 or hp >= float(config.player.hp)): return false
	var spec: Dictionary = config.actions[command]
	if command == "rain" and not valid_rain_target(requested_target): return false
	if int(cooldowns.get(command,0)) > 0 or focus < float(spec.cost):
		return false
	if action == "idle":
		return true
	if action == "heal": return command == "dodge"
	if command != "dodge" or action in ["dodge","hurt","dead"]:
		return false
	var current: Dictionary = config.actions[action]
	if action in ["light","shield","rain"] and age < int(current.windup):
		return true
	return age >= int(current.windup + current.active + current.recovery - current.cancel_last_ticks)

func begin(command: String, movement: Vector2, aim: Vector2) -> void:
	clear_input_buffer()
	action = command
	if command == "rain": rain_target = requested_target
	age = 0
	attack_id = allocate_attack_id()
	hit_targets.clear()
	focus_awarded = false
	locked = cardinal(aim) if command == "melee" else aim.normalized()
	if command == "dodge":
		dodge_stopped = false
		locked = movement.normalized() if movement.length() > 0 else facing
		cooldowns.dodge = int(config.actions.dodge.cooldown)
	facing = cardinal(locked)
	emit("action", {"action":action,"attack_id":attack_id})

func clear_input_buffer() -> void:
	buffered = ""
	buffer_ttl = 0
	buffer_until = 0

func can_buffer(command: String) -> bool:
	if command == "rain" and not valid_rain_target(requested_target): return false
	if hp <= 0 or action in ["idle","dead"] or command not in ["dodge","shield","light","rain","melee"]: return false
	if int(cooldowns.get(command,0)) > 0 or focus < float(config.actions[command].cost): return false
	var remaining := 10-age
	if action != "hurt":
		var spec: Dictionary = config.actions[action]
		remaining = int(spec.windup+spec.active+spec.recovery)-age
		if command == "dodge" and action in ["melee","light","shield","rain"]:
			remaining -= int(spec.cancel_last_ticks)
	return remaining > 0 and remaining <= int(config.input.buffer_ticks)

func choose_command(commands: Array) -> String:
	for candidate in ["dodge","heal","shield","light","rain","melee"]:
		if candidate in commands and (can_start(candidate) or can_buffer(candidate)): return candidate
	return ""

func step_commands(movement: Vector2, aim: Vector2, commands: Array, held_melee: bool = false) -> void:
	step(movement,aim,"",held_melee,commands)

func damage_enemy(enemy: Dictionary, damage: float) -> void:
	if not alive_at_step_start.get(enemy.id,false) or hit_targets.has(enemy.id):
		return
	hit_targets[enemy.id] = true
	queue_damage(0,int(enemy.id),attack_id,damage,action)

func allocate_attack_id() -> int:
	next_attack_sequence += 1
	return next_attack_sequence

func snapshot_living() -> void:
	alive_at_step_start = {0:hp > 0}
	for enemy in enemies:
		alive_at_step_start[enemy.id] = enemy.hp > 0

func queue_damage(source: int, target: int, id: int, amount: float, kind: String, options: Dictionary = {}) -> void:
	var independent := bool(options.get("independent",false))
	if (not independent and not alive_at_step_start.get(source,false)) or not alive_at_step_start.get(target,false):
		return
	var from_pos: Vector2 = options.origin if independent else (player if source == 0 else enemy_by_id(source).pos)
	var to_pos: Vector2 = player if target == 0 else enemy_by_id(target).pos
	damage_requests.append({"source":source,"target":target,"attack_id":id,"created":id,"amount":amount,"action":kind,"push":(to_pos-from_pos).normalized(),"independent":independent,"dot":bool(options.get("dot",false))})

func clear_hazards() -> void:
	shield_hp = 0
	shield_until = 0
	rains.clear()
	rain_target = Vector2.ZERO
	requested_target = Vector2.ZERO
	projectiles.clear()
	zones.clear()

func spawn_projectile(origin: Vector2, velocity: Vector2, source: int = -1) -> Dictionary:
	if hp <= 0 or projectiles.size() >= int(config.hazards.projectile_cap): return {}
	if source != -1 and (enemy_by_id(source).is_empty() or enemy_by_id(source).hp <= 0): return {}
	var spec: Dictionary = config.hazards.projectile
	var shot := {"id":allocate_attack_id(),"source":source,"pos":origin,"velocity":velocity,"radius":float(spec.radius),"damage":float(spec.damage),"ttl":int(spec.lifetime_ticks)}
	projectiles.append(shot)
	emit("projectile_spawn", {"attack_id":shot.id})
	return shot

func spawn_zone(center: Vector2) -> Dictionary:
	if hp <= 0 or zones.size() >= int(config.hazards.zone_cap): return {}
	var spec: Dictionary = config.hazards.zone
	var zone := {"id":allocate_attack_id(),"pos":center,"radius":float(spec.radius),"next_tick":tick+int(spec.interval_ticks),"expires":tick+int(spec.duration_ticks)}
	zones.append(zone)
	return zone

func update_hazards() -> void:
	for shot in projectiles.duplicate():
		var start: Vector2 = shot.pos
		var motion: Vector2 = shot.velocity/float(config.physics_hz)
		var wall_time := INF
		for wall in walls:
			wall_time = minf(wall_time,Sweep.rect(start,motion,wall.grow(shot.radius)))
		for door in doors:
			if not door.open: wall_time = minf(wall_time,Sweep.rect(start,motion,door.rect.grow(shot.radius)))
		var target_time := Sweep.circle(start,motion,player,float(config.player.hurt_radius)+float(shot.radius))
		if wall_time <= target_time and wall_time <= 1:
			shot.pos = start+motion*wall_time
			emit("projectile_wall", {"attack_id":shot.id,"position":shot.pos})
			projectiles.erase(shot)
		elif target_time <= 1:
			shot.pos = start+motion*target_time
			queue_damage(int(shot.source),0,int(shot.id),float(shot.damage),"projectile",{"independent":true,"origin":start})
			projectiles.erase(shot)
		else:
			shot.pos += motion
			shot.ttl -= 1
			if shot.ttl <= 0 or not Rect2(0,0,320,180).grow(shot.radius).has_point(shot.pos): projectiles.erase(shot)
	for zone in zones.duplicate():
		if tick >= zone.next_tick:
			zone.next_tick += int(config.hazards.zone.interval_ticks)
			if player.distance_to(zone.pos) <= zone.radius and clear_line(zone.pos,player):
				queue_damage(-1,0,int(zone.id),float(config.hazards.zone.damage),"zone",{"independent":true,"origin":zone.pos,"dot":true})
		if tick >= zone.expires: zones.erase(zone)

func enemy_by_id(id: int) -> Dictionary:
	for enemy in enemies:
		if enemy.id == id:
			return enemy
	return {}

func ordered_enemies() -> Array[Dictionary]:
	var ordered: Array[Dictionary] = enemies.duplicate()
	ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.id < b.id)
	return ordered

func resolve_damage_batch() -> void:
	resolving_batch = true
	knockbacks.clear()
	damage_requests.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a.created != b.created: return a.created < b.created
		if a.attack_id != b.attack_id: return a.attack_id < b.attack_id
		return a.target < b.target)
	var resolved: Dictionary = {}
	for request in damage_requests:
		var key := "%d:%d" % [request.attack_id,request.target]
		if resolved.has(key):
			continue
		resolved[key] = true
		if (not request.independent and not alive_at_step_start.get(request.source,false)) or not alive_at_step_start.get(request.target,false):
			continue
		if request.target == 0:
			var accepted := apply_player_damage(float(request.amount),int(request.attack_id),int(request.source),bool(request.dot))
			if accepted:
				if not request.dot: knockbacks[0] = request.push * float(config.player.knockback_distance)
				var attacker := enemy_by_id(int(request.source))
				if not attacker.is_empty() and request.action == "enemy_melee": attacker.hit = true
		else:
			var enemy := enemy_by_id(int(request.target))
			if enemy.is_empty(): continue
			var layers := clampi(int(enemy.get("armor_layers",0)),0,int(config.enemy_t1.armor_max_layers))
			if request.action == "light" and layers > 0:
				layers -= 1
				request["broke_armor"] = layers == 0
				emit("armor_strip", {"target":enemy.id,"remaining":layers})
				if layers == 0: emit("armor_break", {"target":enemy.id,"position":enemy.pos})
			enemy.armor_layers = layers
			var amount: float = request.amount
			if not request.dot: amount *= 1.0-layers*float(config.enemy_t1.armor_reduction_per_layer)
			enemy.hp = maxf(0,enemy.hp-amount)
			emit("hit", {"attack_id":request.attack_id,"source":request.source,"target":request.target,"damage":amount,"armor_layers":layers})
			if request.action == "melee" and not focus_awarded:
				focus = minf(100,focus+float(config.player.hit_focus))
				focus_awarded = true
			if enemy.hp > 0 and enemy_can_react(enemy,request):
				knockbacks[int(enemy.id)] = request.push * float(config.enemy_t1.knockback_distance)
			if enemy.hp > 0 and enemy.stun_cd <= 0 and enemy_can_react(enemy,request):
				enemy.state = "hurt"
				enemy.age = 0
				enemy.stun_cd = int(config.enemy_t1.interrupt_cooldown)
	# Death is committed only after every collected, legal request is resolved.
	for enemy in ordered_enemies():
		if enemy.hp <= 0 and not enemy.death_committed:
			enemy.death_committed = true
			enemy.state = "dead"
			emit("death", {"target":enemy.id})
	if hp <= 0:
		clear_hazards()
		action = "dead"
		clear_input_buffer()
		if alive_at_step_start.get(0,false): emit("death", {"target":0})
	# Move only after all hit geometry was collected; push cannot erase a mutual hit.
	var pushed_ids: Array = knockbacks.keys()
	pushed_ids.sort()
	for id in pushed_ids:
		if id == 0 and hp > 0:
			var before := player
			player = move_body(player,knockbacks[id],true,0)
			emit("knockback", {"target":0,"distance":before.distance_to(player)})
		elif id != 0:
			var enemy := enemy_by_id(id)
			if enemy.hp > 0:
				var before: Vector2 = enemy.pos
				enemy.pos = move_body(enemy.pos,knockbacks[id],true,id)
				emit("knockback", {"target":id,"distance":before.distance_to(enemy.pos)})
	knockbacks.clear()
	damage_requests.clear()
	resolving_batch = false

func damage_player(amount: float) -> bool:
	# Direct hazard/testing entry. Gameplay enemy attacks always enqueue first.
	snapshot_living()
	var id := allocate_attack_id()
	var prior_hp := hp
	queue_damage(0,0,id,amount,"hazard")
	resolve_damage_batch()
	return hp < prior_hp

func apply_player_damage(amount: float, id: int, source: int, dot: bool = false) -> bool:
	if hp <= 0 or protection > 0 or (action == "dodge" and age < int(config.actions.dodge.invulnerable_ticks)):
		emit("rejected_hit", {"attack_id":id,"source":source,"target":0,"reason":"dead_or_invulnerable"})
		return false
	if shield_hp > 0:
		var absorbed := minf(shield_hp,amount)
		shield_hp -= absorbed
		amount -= absorbed
		emit("shield_absorb", {"amount":absorbed,"remaining":shield_hp})
		if shield_hp <= 0:
			shield_until = 0
			emit("shield_end", {"reason":"broken"})
	hp = maxf(0,hp-amount)
	if dot:
		emit("dot", {"attack_id":id,"source":source,"target":0,"damage":amount,"hp":hp})
		return true
	protection = int(config.player.hurt_protection_ticks)
	action = "hurt"
	age = 0
	clear_input_buffer()
	player_interrupted_this_step = true
	emit("hurt", {"attack_id":id,"source":source,"target":0,"damage":amount,"hp":hp})
	return true

func light_attack() -> void:
	var spec: Dictionary = config.actions.light
	focus -= float(spec.cost)
	cooldowns.light = int(spec.cooldown)
	beam_from = player
	beam_end = player + locked * float(spec.range)
	var selected: Dictionary = {}
	var candidates := ordered_enemies()
	for distance in range(int(spec.range)+1):
		var point := player + locked * distance
		if blocked(point,0):
			beam_end = point
			break
		for enemy in candidates:
			if enemy.hp > 0 and point.distance_to(enemy.pos) <= 10:
				selected = enemy
				beam_end = point
				break
		if not selected.is_empty():
			break
	if not selected.is_empty():
		damage_enemy(selected,float(spec.damage))
	emit("release", {"action":"light","attack_id":attack_id})

func valid_rain_target(target: Vector2) -> bool:
	return Rect2(8,27,304,132).has_point(target) and player.distance_to(target) <= float(config.actions.rain.range) and not blocked(target,0) and clear_line(player,target)

func release_spell() -> void:
	var spec: Dictionary = config.actions[action]
	if action == "rain" and not valid_rain_target(rain_target):
		emit("release_rejected", {"action":"rain","reason":"target_blocked_or_out_of_range"})
		return
	focus -= float(spec.cost)
	cooldowns[action] = int(spec.cooldown)
	if action == "shield":
		shield_hp = float(spec.capacity)
		shield_until = tick+int(spec.duration)
	else:
		rains.append({"id":attack_id,"pos":rain_target,"impact_tick":tick+int(spec.delay),"hit":false})
	emit("release", {"action":action,"attack_id":attack_id})

func update_rains() -> void:
	for rain in rains:
		if not rain.hit and tick >= int(rain.impact_tick):
			rain.hit = true
			for enemy in ordered_enemies():
				if enemy.hp > 0 and enemy.pos.distance_to(rain.pos) <= float(config.actions.rain.radius) and clear_line(rain.pos,enemy.pos):
					queue_damage(0,int(enemy.id),int(rain.id),float(config.actions.rain.damage),"rain",{"independent":true,"origin":rain.pos})
			emit("rain_impact", {"attack_id":rain.id,"position":rain.pos})
	rains = rains.filter(func(item): return tick < int(item.impact_tick)+15)

func step(movement: Vector2, aim: Vector2, command: String = "", held_melee: bool = false, commands: Array = []) -> void:
	events.clear()
	damage_requests.clear()
	player_interrupted_this_step = false
	snapshot_living()
	tick += 1
	if hp <= 0:
		return
	requested_target = player+aim
	if action == "heal" and movement.length_squared() > 0:
		action = "idle"
		age = 0
		emit("heal_cancel", {"reason":"movement"})
		if command == "heal": command = ""
		commands.erase("heal")
	if movement.length_squared() > 0:
		if command == "heal": command = ""
		commands.erase("heal")
	if shield_hp > 0 and tick >= shield_until:
		shield_hp = 0
		shield_until = 0
		emit("shield_end", {"reason":"expired"})
	if aim.length_squared() < 0.001:
		aim = facing
	if protection > 0:
		protection -= 1
	for key in cooldowns:
		cooldowns[key] = maxi(0,int(cooldowns[key])-1)
	focus = minf(100,focus + float(config.player.focus_regen)/60.0)
	if not commands.is_empty(): command = choose_command(commands)
	if not buffered.is_empty() and tick > buffer_until: clear_input_buffer()
	buffer_ttl = maxi(0,buffer_until-tick)
	if not command.is_empty() and can_start(command):
		begin(command,movement,aim)
	elif not buffered.is_empty() and can_start(buffered):
		begin(buffered,movement,aim)
	elif held_melee and can_start("melee"):
		begin("melee",movement,aim)
	elif buffered.is_empty() and can_buffer(command):
		buffered = command
		buffer_ttl = int(config.input.buffer_ticks)
		buffer_until = tick+buffer_ttl
	var speed := float(config.player.speed)
	if action == "idle":
		facing = cardinal(aim)
	elif action == "dodge":
		speed = 0
		if not dodge_stopped:
			var displacement := locked * float(config.actions.dodge.distance)/int(config.actions.dodge.active)
			var before := player
			player = move_body(player,displacement,true)
			if player.distance_to(before) < displacement.length()-0.0001:
				dodge_stopped = true
				emit("dodge_blocked")
	elif action in ["melee","light","shield","rain"]:
		var spec: Dictionary = config.actions[action]
		if age < int(spec.windup):
			speed *= 0.4 if action == "melee" else 0.35
		elif age < int(spec.windup + spec.active):
			speed = 0
		else:
			speed *= 0.6 if action == "melee" else 1.0
		if action == "melee" and age >= int(spec.windup) and age < int(spec.windup+spec.active):
			for enemy in enemies:
				var offset: Vector2 = enemy.pos-player
				if offset.length() <= float(spec.range) and (offset.is_zero_approx() or locked.dot(offset.normalized()) >= cos(deg_to_rad(float(spec.angle_degrees)/2))) and clear_line(player,enemy.pos):
					damage_enemy(enemy,float(spec.damage))
		if action == "light" and age == int(spec.windup):
			light_attack()
		if action in ["shield","rain"] and age == int(spec.windup): release_spell()
	elif action == "hurt":
		speed = 0
	elif action == "heal":
		speed = 0
	player = move_body(player,movement.limit_length() * speed/60.0)
	update_enemies()
	update_hazards()
	update_rains()
	resolve_damage_batch()
	# Commit healing only after same-tick hostile hits have had a chance to interrupt.
	if action == "heal" and not player_interrupted_this_step and age == int(config.actions.heal.windup)-1:
		potions -= 1
		var restored := minf(float(config.actions.heal.healing),float(config.player.hp)-hp)
		hp += restored
		emit("heal", {"amount":restored,"potions":potions})
	if action != "idle" and action != "dead" and not player_interrupted_this_step:
		age += 1
		var duration := 10
		if action != "hurt":
			var spec: Dictionary = config.actions[action]
			duration = int(spec.windup + spec.active + spec.recovery)
		if age >= duration:
			action = "idle"
			age = 0

func update_enemies() -> void:
	# New attacks in the same step are created in stable actor-ID order.
	for enemy in ordered_enemies():
		if enemy.hp <= 0 or enemy.dummy:
			continue
		if enemy.get("archetype","T1") != "T1":
			update_special_enemy(enemy)
			continue
		enemy.stun_cd = maxi(0,int(enemy.stun_cd)-1)
		var offset: Vector2 = player-enemy.pos
		var spec: Dictionary = config.enemy_t1
		var visible := clear_line(enemy.pos,player)
		if enemy.returning:
			if enemy.pos.distance_to(enemy.spawn) < 1:
				enemy.pos = enemy.spawn
				enemy.returning = false
				enemy.alert = false
				enemy.hp = float(spec.hp)
				enemy.lost_ticks = 0
				emit("enemy_returned", {"target":enemy.id})
			else: navigate_enemy(enemy,enemy.spawn)
			continue
		if visible and offset.length() <= float(spec.sense_range): enemy.alert = true
		if enemy.state != "idle": enemy.alert = true
		if not visible and offset.length() > float(spec.leash_distance): enemy.lost_ticks += 1
		else: enemy.lost_ticks = 0
		if enemy.alert and enemy.lost_ticks >= int(spec.lost_sight_ticks):
			enemy.returning = true
			enemy.state = "idle"
			enemy.path.clear()
			continue
		if enemy.state == "hurt":
			enemy.age += 1
			if enemy.age >= int(spec.hurt_ticks):
				enemy.state = "idle"
		elif enemy.state == "idle":
			if offset.length() <= float(spec.trigger_range) and visible and enemy_can_begin(enemy):
				enemy.state = "attack"
				enemy.age = 0
				enemy.dir = offset.normalized()
				enemy.hit = false
				enemy.attack_id = allocate_attack_id()
			elif enemy.alert:
				navigate_enemy(enemy,player)
		else:
			if enemy.age < int(spec.windup)/2:
				enemy.dir = offset.normalized()
			if enemy.age == int(spec.windup):
				enemy.pos = move_body(enemy.pos,enemy.dir*float(spec.lunge_distance),true,int(enemy.id))
				offset = player-enemy.pos
			if enemy.age >= int(spec.windup) and enemy.age < int(spec.windup+spec.active) and not enemy.hit:
				if offset.length() <= float(spec.range) and enemy.dir.dot(offset.normalized()) >= 0.707 and clear_line(enemy.pos,player):
					queue_damage(int(enemy.id),0,int(enemy.attack_id),float(spec.damage),"enemy_melee")
			enemy.age += 1
			if enemy.age >= int(spec.windup+spec.active+spec.recovery):
				enemy.state = "idle"

func update_special_enemy(_enemy: Dictionary) -> void:
	pass

func enemy_can_begin(_enemy: Dictionary) -> bool:
	return true

func enemy_can_react(_enemy: Dictionary, _request: Dictionary) -> bool:
	return true
