extends "res://scripts/combat_model.gd"
## Campaign-only archetypes; inherited G2 attacks and player timings stay unchanged.
var enemy_specs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
var poison_attacks: Dictionary = {}
var poison_until := 0
var poison_next := 0
## Hazard fields own one shape each. enemy_warnings draws that exact shape and
## update_field_hazards damages with it, so a warning can never disagree with
## the hit test. Used by the BOSS spore bursts/water lanes and the EL2 water lane.
var field_hazards: Array[Dictionary] = []

func add_archetype(kind: String, position: Vector2) -> Dictionary:
	var enemy := add_enemy(position)
	if kind == "T1": return enemy
	var spec: Dictionary = enemy_specs[kind]
	enemy.merge({"archetype":kind,"max_hp":spec.hp,"speed":spec.speed,"hp":float(spec.hp),"armor_layers":int(spec.get("armor",0)),"rearm_used":false,"charging":false,"exploded":false,"shots_fired":0,"elite_attack":"charge","elite_toggle":0,"water_toggle":0},true)
	if kind == "BOSS":
		enemy.merge({"phase":0,"boss_attack":"","core_open":false,"boss_cycle":0},true)
	return enemy

func enemy_can_begin(enemy: Dictionary) -> bool:
	if enemy.get("archetype","") == "BOSS": return true
	if not Rect2(12,32,296,122).has_point(enemy.pos) or not Rect2(12,32,296,122).has_point(player): return false
	var ranged: bool = str(enemy.get("archetype","")) in ["T2","T6"]
	var count := 0
	for other in enemies:
		if other.id != enemy.id and other.hp > 0 and other.state in ["attack","rearm"] and (str(other.get("archetype","")) in ["T2","T6"]) == ranged: count += 1
	return count < (1 if ranged else 2)

func enemy_can_react(enemy: Dictionary, request: Dictionary) -> bool:
	var kind: String = enemy.get("archetype","T1")
	if kind == "BOSS": return false
	if kind == "T5": return false
	if kind == "T3" and enemy.get("charging",false): return false
	if kind == "EL1":
		var recovery: bool = enemy.state == "attack" and enemy.age >= int(enemy_specs.EL1.windup+enemy_specs.EL1.active)
		return recovery or bool(request.get("broke_armor",false))
	if kind == "EL2":
		if enemy.get("charging",false): return false
		var spec: Dictionary = enemy_specs.EL2
		var active_end := int(spec.windup+spec.active)
		if str(enemy.get("elite_attack","charge")) == "water":
			active_end = int(spec.get("water_warn",60))+int(spec.get("water_active",120))
		return enemy.state == "attack" and enemy.age >= active_end
	return true

func enemy_hurt_rect(enemy: Dictionary) -> Rect2:
	if str(enemy.get("archetype","")) == "BOSS":
		# The mother uses the native 155x135 battler at half world scale. The
		# foot is the anchor point, so the full drawn body is the hit target.
		var size := Vector2(155,135)*0.5
		return Rect2(enemy.pos+Vector2(-size.x*0.5,-size.y),size)
	return super.enemy_hurt_rect(enemy)

func enemy_damage_allowed(_enemy: Dictionary) -> bool:
	# The mother is vulnerable at all times; core-open windows are now only a
	# readable damage-amplification/visual cue, not a hit gate.
	return true

func enemy_on_death(enemy: Dictionary) -> void:
	if str(enemy.get("archetype","")) != "BOSS": return
	field_hazards.clear()
	zones.clear()
	projectiles.clear()
	emit("boss_death", {"phase":int(enemy.get("phase",0)),"max_hp":float(enemy.get("max_hp",0))})

func clear_hazards() -> void:
	super.clear_hazards()
	field_hazards.clear()
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
	_update_field_hazards()

# ── Hazard fields shared by Boss and EL2 ────────────────────────────────────

func add_field_hazard(kind: String, shape: String, rect: Rect2, pos: Vector2, radius: float, warn_ticks: float, active_ticks: float, damage: float, interval: int, dot: bool, source: int) -> Dictionary:
	var warn_until := tick+int(warn_ticks)
	var active_end := warn_until+int(active_ticks)
	# A zero-length active window is a single burst on the warning's last tick.
	if int(active_ticks) <= 0: active_end = warn_until+1
	var hazard := {"id":allocate_attack_id(),"source":source,"kind":kind,"shape":shape,"rect":rect,"pos":pos,"radius":radius,"warn_start":tick,"warn_until":warn_until,"active_end":active_end,"next_tick":warn_until,"interval":interval,"damage":damage,"dot":dot}
	field_hazards.append(hazard)
	emit("hazard_warn", {"hazard_id":hazard.id,"kind":kind,"shape":shape,"warn_until":warn_until,"active_end":active_end,"pos":pos,"radius":radius,"rect":rect})
	return hazard

func _update_field_hazards() -> void:
	if field_hazards.is_empty(): return
	for hazard in field_hazards.duplicate():
		if tick >= int(hazard.active_end):
			field_hazards.erase(hazard)
			emit("hazard_end", {"hazard_id":hazard.id,"kind":hazard.kind})
			continue
		if tick < int(hazard.next_tick): continue
		var hit := false
		if str(hazard.shape) == "circle":
			hit = player.distance_to(hazard.pos) <= float(hazard.radius)
		else:
			hit = (hazard.rect as Rect2).grow(float(config.player.body_radius)).has_point(player)
		if hit:
			queue_damage(-1,0,int(hazard.id),float(hazard.damage),str(hazard.kind)+"_field",{"independent":true,"origin":hazard.pos,"dot":bool(hazard.dot)})
		emit("hazard_fire", {"hazard_id":hazard.id,"kind":hazard.kind,"hit":hit})
		if int(hazard.interval) > 0:
			hazard.next_tick = int(hazard.next_tick)+int(hazard.interval)
		else:
			hazard.next_tick = int(hazard.active_end)+1

func _water_band_rects(spec: Dictionary) -> Array[Rect2]:
	var bands: Array[Rect2] = []
	for entry in spec.get("water_bands",[]):
		bands.append(Rect2(float(entry[0]),float(entry[1]),float(entry[2]),float(entry[3])))
	return bands

func _pick_water_band(enemy: Dictionary) -> Rect2:
	var spec: Dictionary = enemy_specs[str(enemy.archetype)]
	var bands := _water_band_rects(spec)
	if bands.is_empty(): return Rect2(0,80,320,24)
	var best_distance := INF
	for band in bands:
		var distance := absf(player.y-band.get_center().y)
		if (band as Rect2).grow(float(config.player.body_radius)).has_point(player): distance = 0.0
		best_distance = minf(best_distance,distance)
	var candidates: Array[Rect2] = []
	for band in bands:
		var distance := absf(player.y-band.get_center().y)
		if (band as Rect2).grow(float(config.player.body_radius)).has_point(player): distance = 0.0
		if absf(distance-best_distance) <= 0.5: candidates.append(band)
	var index := int(enemy.get("water_toggle",0)) % candidates.size()
	enemy["water_toggle"] = int(enemy.get("water_toggle",0))+1
	return candidates[index]

func _spawn_water_band(enemy: Dictionary) -> void:
	var spec: Dictionary = enemy_specs[str(enemy.archetype)]
	var band := _pick_water_band(enemy)
	add_field_hazard("water","rect",band,band.get_center(),0.0,float(spec.get("water_warn",60)),float(spec.get("water_active",120)),float(spec.get("water_damage",10)),60,true,int(enemy.id))
	emit("water_lane", {"target":enemy.id,"rect":band})

func _clamp_arena(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x,28.0,292.0),clampf(point.y,38.0,150.0))

func t6_muzzle(enemy: Dictionary, index: int) -> Vector2:
	var side: Vector2 = enemy.dir.orthogonal()*4.0
	return enemy.pos+enemy.dir*8.0+side*(1.0 if index%2 == 0 else -1.0)

# ── Boss readable geometry (warning and damage read the same values) ────────

func boss_sweep_shape(enemy: Dictionary) -> Dictionary:
	var spec: Dictionary = enemy_specs.BOSS
	return {"origin":enemy.pos,"direction":enemy.dir,"radius":float(spec.get("sweep_radius",88)),"half_angle":deg_to_rad(float(spec.get("sweep_half_angle_degrees",50)))}

func sector_contains(origin: Vector2, direction: Vector2, radius: float, half_angle: float, point: Vector2) -> bool:
	var offset := point-origin
	if offset.length() > radius: return false
	if offset.length_squared() < 0.0001: return true
	return direction.normalized().dot(offset.normalized()) >= cos(half_angle)

func boss_sweep_contains(enemy: Dictionary, point: Vector2) -> bool:
	var shape := boss_sweep_shape(enemy)
	return sector_contains(shape.origin,shape.direction,shape.radius,shape.half_angle,point)

# ── Regular + elite AI ──────────────────────────────────────────────────────

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
			# User feedback: returning to a spawn may not heal or restore shell.
			# Keep current HP/armor so retreat is not a free reset.
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
	# EL1: one readable half-health shell refit; the telegraph is the rearm state.
	if kind == "EL1":
		if enemy.state == "rearm":
			enemy.age += 1
			if enemy.age >= int(spec.get("rearm_telegraph",48)):
				enemy.armor_layers = mini(int(spec.get("rearm_layers",2)),int(config.enemy_t1.armor_max_layers))
				enemy.state = "idle"
				enemy.age = 0
				emit("elite_rearm_done", {"target":enemy.id,"armor_layers":enemy.armor_layers})
			return
		if enemy.state == "idle" and not bool(enemy.rearm_used) and float(enemy.hp) <= float(enemy.max_hp)*0.5 and float(enemy.hp) > 0:
			enemy.state = "rearm"
			enemy.age = 0
			enemy.rearm_used = true
			emit("elite_rearm", {"target":enemy.id,"hp":enemy.hp,"max_hp":enemy.max_hp})
			return
	if enemy.state == "idle":
		if kind == "T2" and visible and offset.length() < 60:
			var previous: Vector2 = enemy.pos
			enemy.pos = move_body(enemy.pos,-offset.normalized()*float(spec.speed)/60,false,enemy.id)
			if enemy.pos.distance_to(previous) > 0.01: return
		if kind == "T6" and visible and offset.length() < float(spec.get("keep_min",60)):
			var previous6: Vector2 = enemy.pos
			enemy.pos = move_body(enemy.pos,-offset.normalized()*float(spec.speed)/60,false,enemy.id)
			if enemy.pos.distance_to(previous6) > 0.01: return
		var trigger := float(spec.range)
		if kind == "T2": trigger = 90
		if kind == "T3": trigger = 100
		if kind == "T5": trigger = 48
		if kind == "T6": trigger = float(spec.range)
		if kind == "EL2": trigger = float(spec.get("trigger",120))
		if offset.length() <= trigger and visible and enemy_can_begin(enemy):
			enemy.state = "attack"
			enemy.age = 1
			enemy.dir = offset.normalized()
			enemy.attack_id = allocate_attack_id()
			enemy.hit = false
			enemy.charging = false
			enemy.shots_fired = 0
			if kind == "EL2":
				# Charge and the fixed water lane take turns.
				enemy.elite_attack = "charge" if int(enemy.get("elite_toggle",0))%2 == 0 else "water"
				enemy.elite_toggle = int(enemy.get("elite_toggle",0))+1
				if enemy.elite_attack == "water": _spawn_water_band(enemy)
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
	elif kind == "T6":
		if enemy.age < windup/2: enemy.dir = offset.normalized()
		var gap := int(spec.get("gap",12))
		var shots := int(spec.get("shots",2))
		if visible and int(enemy.shots_fired) < shots and (enemy.age == windup or enemy.age == windup+gap):
			var muzzle := t6_muzzle(enemy,int(enemy.shots_fired))
			var shot6 := spawn_projectile(muzzle,enemy.dir*80,enemy.id)
			if not shot6.is_empty():
				# T6's table entry is twin 10-damage pellets only; the spore-poison
				# status stays a T2 property, so do not register a poison source.
				enemy.shots_fired = int(enemy.shots_fired)+1
				emit("t6_shot", {"target":enemy.id,"shot":int(enemy.shots_fired),"attack_id":shot6.id})
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
	elif kind == "EL2":
		if str(enemy.elite_attack) == "charge":
			# Direction is locked when the telegraph starts: sidestep reads.
			if enemy.age >= windup and enemy.age < windup+active:
				enemy.charging = true
				var before2: Vector2 = enemy.pos
				var movement2: Vector2 = enemy.dir*float(spec.charge_speed)/60
				enemy.pos = move_body(enemy.pos,movement2,true,enemy.id)
				var crossed2: bool = Sweep.circle(before2,enemy.pos-before2,player,float(config.player.hurt_radius)+5) <= 1
				if crossed2 and not enemy.hit and clear_line(before2,player):
					queue_damage(enemy.id,0,enemy.attack_id,float(spec.damage),"charge")
					enemy.hit = true
				if enemy.pos.distance_to(before2) < movement2.length()-0.001:
					# A wall ends the charge immediately instead of sliding along it.
					enemy.age = windup+active
					enemy.charging = false
					emit("charge_blocked",{"target":enemy.id})
			else: enemy.charging = false
		else:
			# The fixed water lane was spawned on the begin tick; hold position.
			enemy.charging = false
			if enemy.age < windup: enemy.dir = offset.normalized()
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
	var total := windup+active+int(spec.recovery)
	if kind == "T6": total = windup+int(spec.get("gap",12))+int(spec.recovery)
	if kind == "EL2" and str(enemy.elite_attack) == "water": total = int(spec.get("water_warn",60))+int(spec.get("water_active",120))+int(spec.recovery)
	if enemy.age >= total:
		enemy.state = "idle"
		enemy.charging = false

# ── BOSS ────────────────────────────────────────────────────────────────────

func _update_boss(enemy: Dictionary) -> void:
	var spec: Dictionary = enemy_specs.BOSS
	var max_hp := float(enemy.max_hp)
	enemy.alert = true
	# One transition per threshold, clamped there: overkill never crosses phases.
	if int(enemy.phase) == 0 and float(enemy.hp) <= max_hp*0.7:
		_boss_enter_phase(enemy,1,max_hp*0.7)
		return
	if int(enemy.phase) == 1 and float(enemy.hp) <= max_hp*0.35:
		_boss_enter_phase(enemy,2,max_hp*0.35)
		return
	match str(enemy.state):
		"transition": _boss_tick_transition(enemy,spec)
		"idle": _boss_tick_idle(enemy,spec)
		"attack": _boss_tick_attack(enemy,spec)
		_:
			enemy.state = "idle"
			enemy.age = 0

func _boss_enter_phase(enemy: Dictionary, phase: int, clamped_hp: float) -> void:
	enemy.phase = phase
	enemy.hp = clamped_hp
	# Phases 1 and 2 grant a fresh two-layer shell once; the core phase has none.
	enemy.armor_layers = 2 if phase < 2 else 0
	enemy.state = "transition"
	enemy.age = 0
	enemy.boss_cycle = 0
	enemy.boss_attack = ""
	enemy.hit = false
	_clear_boss_battlefield()
	_boss_set_core(enemy,true,"phase_"+str(phase))
	emit("boss_phase", {"phase":phase,"hp":enemy.hp,"max_hp":float(enemy.max_hp)})

func _clear_boss_battlefield() -> void:
	var cleared := field_hazards.size()+zones.size()+projectiles.size()
	field_hazards.clear()
	zones.clear()
	projectiles.clear()
	emit("hazards_cleared", {"count":cleared})

func _boss_set_core(enemy: Dictionary, open: bool, window: String = "") -> void:
	if bool(enemy.get("core_open",false)) == open: return
	enemy["core_open"] = open
	emit("boss_core", {"open":open,"phase":int(enemy.get("phase",0)),"window":window})

func _boss_tick_transition(enemy: Dictionary, spec: Dictionary) -> void:
	enemy.age += 1
	if enemy.age >= int(spec.get("safe_window",72)):
		enemy.state = "idle"
		enemy.age = 0
		_boss_set_core(enemy,false,"phase_end")

func _boss_tick_idle(enemy: Dictionary, spec: Dictionary) -> void:
	enemy.age += 1
	if enemy.age >= int(spec.get("idle_window",24)):
		_boss_begin_attack(enemy,spec)

func _boss_begin_attack(enemy: Dictionary, spec: Dictionary) -> void:
	enemy.state = "attack"
	enemy.age = 0
	enemy.hit = false
	enemy.attack_id = allocate_attack_id()
	enemy.dir = (player-enemy.pos).normalized()
	var phase := int(enemy.phase)
	var cycle := int(enemy.boss_cycle)
	enemy.boss_cycle = cycle+1
	var attack := ""
	if phase == 0: attack = "sweep" if cycle%2 == 0 else "spore"
	elif phase == 1: attack = "water" if cycle%2 == 0 else "sweep"
	else: attack = "double" if cycle%2 == 0 else "core"
	enemy.boss_attack = attack
	emit("boss_attack", {"attack":attack,"phase":phase})
	if attack == "core":
		_boss_set_core(enemy,true,"expose")
	elif attack == "spore":
		_boss_spawn_spore(enemy,spec,_clamp_arena(player))
	elif attack == "double":
		var first := _clamp_arena(player)
		var second := _clamp_arena(first+Vector2(0,48))
		if second.distance_to(first) < 40: second = _clamp_arena(first-Vector2(0,48))
		_boss_spawn_spore(enemy,spec,first)
		_boss_spawn_spore(enemy,spec,second)
	elif attack == "water":
		_spawn_water_band(enemy)

func _boss_spawn_spore(enemy: Dictionary, spec: Dictionary, center: Vector2) -> void:
	add_field_hazard("spore","circle",Rect2(),center,float(spec.get("spore_radius",24)),float(spec.get("spore_warn",60)),0,float(spec.get("spore_damage",16)),0,false,int(enemy.id))

func _boss_tick_attack(enemy: Dictionary, spec: Dictionary) -> void:
	var attack := str(enemy.boss_attack)
	var timing: Dictionary = spec.get("attacks",{}).get(attack,{})
	var windup := int(timing.get("warn",0))
	var active := int(timing.get("active",1))
	var recovery := int(timing.get("recovery",0))
	if attack == "core":
		# Phase 3's exposed core is itself a 3-second damage window.
		enemy.age += 1
		if enemy.age >= active:
			_boss_set_core(enemy,false,"expose")
			enemy.state = "idle"
			enemy.age = 0
		return
	if attack == "sweep":
		if enemy.age < windup/2: enemy.dir = (player-enemy.pos).normalized()
		if enemy.age >= windup and enemy.age < windup+active and not enemy.hit:
			# Same sector helper the warning geometry is derived from.
			if boss_sweep_contains(enemy,player) and clear_line(enemy.pos,player):
				queue_damage(int(enemy.id),0,int(enemy.attack_id),float(spec.get("sweep_damage",20)),"boss_sweep")
				enemy.hit = true
	enemy.age += 1
	if enemy.age >= windup+active:
		if recovery > 0 and not bool(enemy.core_open):
			_boss_set_core(enemy,true,"recover_"+attack)
		if enemy.age >= windup+active+recovery:
			if bool(enemy.core_open): _boss_set_core(enemy,false,"recover_"+attack)
			enemy.state = "idle"
			enemy.age = 0
