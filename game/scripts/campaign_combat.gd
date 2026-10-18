extends "res://scripts/combat_model.gd"
## Campaign-only archetypes; inherited G2 attacks and player timings stay unchanged.
var enemy_specs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
var poison_attacks: Dictionary = {}
var poison_until := 0
var poison_next := 0

func add_archetype(kind: String, position: Vector2) -> Dictionary:
	var enemy := add_enemy(position)
	if kind == "T1": return enemy
	var spec: Dictionary = enemy_specs[kind]
	enemy.merge({"archetype":kind,"max_hp":spec.hp,"speed":spec.speed,"hp":float(spec.hp),"armor_layers":int(spec.get("armor",0)),"rearm_used":false,"charging":false,"exploded":false},true)
	if kind == "BOSS":
		enemy.merge({"phase":0,"boss_attack":"sweep","core_open":false,"phase_armed":false},true)
	return enemy

func enemy_can_begin(enemy: Dictionary) -> bool:
	if enemy.get("archetype","") == "BOSS": return true
	if not Rect2(12,32,296,122).has_point(enemy.pos) or not Rect2(12,32,296,122).has_point(player): return false
	var ranged: bool = enemy.get("archetype","") == "T2"
	var count := 0
	for other in enemies:
		if other.id != enemy.id and other.hp > 0 and other.state in ["attack","rearm"] and (other.get("archetype","") == "T2") == ranged: count += 1
	return count < (1 if ranged else 2)

func enemy_can_react(enemy: Dictionary, request: Dictionary) -> bool:
	var kind: String = enemy.get("archetype","T1")
	if kind == "BOSS": return false
	if kind == "T5": return false
	if kind == "T3" and enemy.get("charging",false): return false
	if kind == "EL1":
		var recovery: bool = enemy.state == "attack" and enemy.age >= int(enemy_specs.EL1.windup+enemy_specs.EL1.active)
		return recovery or bool(request.get("broke_armor",false))
	return true

func clear_hazards() -> void:
	super.clear_hazards()
	poison_until = 0
	poison_next = 0
	poison_attacks.clear()

func apply_player_damage(amount: float, id: int, source: int, dot: bool = false) -> bool:
	var before := hp
	var accepted := super.apply_player_damage(amount,id,source,dot)
	if accepted and not dot and hp > 0 and hp < before and poison_attacks.has(id):
		if poison_until <= 0 or poison_until < tick: poison_next = tick+60
		poison_until = tick+240
		emit("poison_start")
	return accepted

func update_hazards() -> void:
	super.update_hazards()
	if poison_until > 0 and tick <= poison_until and tick >= poison_next:
		poison_next += 60
		queue_damage(-1,0,allocate_attack_id(),4,"poison",{"independent":true,"origin":player,"dot":true})
	if tick > poison_until: poison_until = 0
	# Keep identities through this step's damage batch; expire next step.
	for id in poison_attacks.keys():
		if tick > poison_attacks[id]: poison_attacks.erase(id)

func update_special_enemy(enemy: Dictionary) -> void:
	var kind: String = enemy.archetype
	if kind == "BOSS":
		_update_boss(enemy)
		return
	var spec: Dictionary = enemy_specs[kind]
	enemy.stun_cd = maxi(0,enemy.stun_cd-1)
	var offset: Vector2 = player-enemy.pos
	var visible := clear_line(enemy.pos,player)
	if enemy.returning:
		if enemy.pos.distance_to(enemy.spawn) < 1:
			enemy.pos = enemy.spawn
			enemy.returning = false
			enemy.alert = false
			enemy.hp = float(spec.hp)
			enemy.armor_layers = int(spec.get("armor",0))
			enemy.rearm_used = false
			emit("enemy_returned",{"target":enemy.id})
		else: navigate_enemy(enemy,enemy.spawn)
		return
	if visible and offset.length() <= 112: enemy.alert = true
	if not visible and offset.length() > 144: enemy.lost_ticks += 1
	else: enemy.lost_ticks = 0
	if enemy.lost_ticks >= 120 or not Rect2(12,32,296,122).has_point(player):
		enemy.returning = true
		enemy.state = "idle"
		enemy.charging = false
		enemy.path.clear()
		return
	if enemy.state == "hurt":
		enemy.age += 1
		if enemy.age >= 7: enemy.state = "idle"
		return
	# G4-006: the old EL1 half-health rearm restored two shell layers and made
	# the gatekeeper read as unkillable in the front hall. Shell damage already
	# gives the fight its pacing; no second shell is granted.
	enemy.rearm_used = true
	if enemy.state == "idle":
		if kind == "T2" and visible and offset.length() < 60:
			var previous: Vector2 = enemy.pos
			enemy.pos = move_body(enemy.pos,-offset.normalized()*float(spec.speed)/60,false,enemy.id)
			if enemy.pos.distance_to(previous) > 0.01: return
		var trigger := float(spec.range)
		if kind == "T2": trigger = 90
		if kind == "T3": trigger = 100
		if kind == "T5": trigger = 48
		if offset.length() <= trigger and visible and enemy_can_begin(enemy):
			enemy.state = "attack"
			enemy.age = 1
			enemy.dir = offset.normalized()
			enemy.attack_id = allocate_attack_id()
			enemy.hit = false
			enemy.charging = false
		elif enemy.alert and kind != "T5":
			if kind == "T2" and offset.length() < 60:
				enemy.pos = move_body(enemy.pos,-offset.normalized()*float(spec.speed)/60,false,enemy.id)
			else: navigate_enemy(enemy,player)
		return
	if enemy.state != "attack": return
	var windup := int(spec.windup)
	var active := int(spec.active)
	if kind == "T2":
		if enemy.age < windup/2: enemy.dir = offset.normalized()
		if enemy.age == windup and visible:
			var shot := spawn_projectile(enemy.pos,enemy.dir*80,enemy.id)
			if not shot.is_empty(): poison_attacks[shot.id] = tick+int(shot.ttl)
	elif kind == "T3":
		if enemy.age >= windup and enemy.age < windup+active:
			enemy.charging = true
			var before: Vector2 = enemy.pos
			var movement: Vector2 = enemy.dir*float(spec.charge_speed)/60
			enemy.pos = move_body(enemy.pos,movement,true,enemy.id)
			var crossed: bool = Sweep.circle(before,enemy.pos-before,player,float(config.player.hurt_radius)+5) <= 1
			if crossed and not enemy.hit and clear_line(before,player):
				queue_damage(enemy.id,0,enemy.attack_id,float(spec.damage),"charge")
				enemy.hit = true
			if enemy.pos.distance_to(before) < movement.length()-0.001:
				enemy.age = windup+active
				enemy.charging = false
				emit("charge_blocked",{"target":enemy.id})
		else: enemy.charging = false
	elif kind == "T5":
		if enemy.age == windup:
			if offset.length() <= float(spec.range) and visible: queue_damage(enemy.id,0,enemy.attack_id,float(spec.damage),"spore_burst")
			spawn_zone(enemy.pos)
			enemy.exploded = true
			enemy.hp = 0
	else:
		if enemy.age < windup/2: enemy.dir = offset.normalized()
		if enemy.age >= windup and enemy.age < windup+active and not enemy.hit and offset.length() <= float(spec.range) and visible and enemy.dir.dot(offset.normalized()) >= 0.707:
			queue_damage(enemy.id,0,enemy.attack_id,float(spec.damage),"guard_sweep")
			enemy.hit = true
	enemy.age += 1
	if enemy.age >= windup+active+int(spec.recovery):
		enemy.state = "idle"
		enemy.charging = false


func _update_boss(enemy: Dictionary) -> void:
	var spec: Dictionary = enemy_specs.BOSS
	var max_hp := float(spec.hp)
	enemy.alert = true
	enemy.hp = minf(float(enemy.hp), max_hp)
	# Phase transitions clamp once, never rewind and never kill the player.
	if int(enemy.phase) == 0 and float(enemy.hp) <= max_hp*0.7:
		enemy.phase = 1
		enemy.hp = max_hp*0.7
		enemy.armor_layers = 2
		enemy.state = "idle"; enemy.age = 0; enemy.boss_attack = "water"
		emit("boss_phase", {"phase":1})
		return
	if int(enemy.phase) == 1 and float(enemy.hp) <= max_hp*0.35:
		enemy.phase = 2
		enemy.hp = max_hp*0.35
		enemy.armor_layers = 0
		enemy.state = "idle"; enemy.age = 0; enemy.boss_attack = "double"
		enemy.core_open = true
		emit("boss_phase", {"phase":2})
		return
	if enemy.state == "idle":
		var offset: Vector2 = player - enemy.pos
		if offset.length() <= 260:
			enemy.state = "attack"; enemy.age = 0; enemy.hit = false
			enemy.attack_id = allocate_attack_id()
			enemy.dir = offset.normalized()
			enemy.boss_attack = "sweep" if int(enemy.phase) == 0 else ("water" if int(enemy.phase) == 1 else "double")
		return
	if enemy.state != "attack": return
	var windup := int(spec.windup)
	if int(enemy.age) < windup/2: enemy.dir = (player-enemy.pos).normalized()
	if int(enemy.age) == windup:
		if enemy.boss_attack == "sweep":
			enemy.hit = false
		elif enemy.boss_attack == "water":
			spawn_zone(player)
		else:
			spawn_zone(player)
			spawn_zone(player + Vector2(40,0))
	if int(enemy.age) >= windup and int(enemy.age) < windup+int(spec.active) and not enemy.hit:
		var offset2: Vector2 = player-enemy.pos
		if offset2.length() <= float(spec.range)+22 and clear_line(enemy.pos,player):
			queue_damage(enemy.id,0,enemy.attack_id,float(spec.damage),"boss_sweep")
			enemy.hit = true
	enemy.age += 1
	if int(enemy.age) >= windup+int(spec.active)+int(spec.recovery):
		enemy.state = "idle"; enemy.age = 0; enemy.hit = false
