extends RefCounted
## Combat replay uses the production command entry, never changes simulation speed.
var frame := 0
var trace: Array[Dictionary] = []
var process_intervals: Array[float] = []
var started_usec := Time.get_ticks_usec()
var started_draws := Engine.get_frames_drawn()

func advance(model) -> bool:
	var history_start: int = model.history.size()
	var movement := Vector2.ZERO
	var aim := Vector2.RIGHT
	var commands: Array = []
	var held := false
	var paused := frame >= 90 and frame < 120
	if frame < 20: movement = Vector2.RIGHT
	if frame >= 24 and frame < 90: held = true
	if frame == 125: commands = ["light"]
	if frame == 155:
		commands = ["light","dodge"]
		movement = Vector2.LEFT
	if frame >= 180 and frame < 205: movement = Vector2.UP
	if frame >= 210 and frame < 240: movement = Vector2.RIGHT
	if frame == 180: model.set_door_open("test_gate",false)
	if frame == 210: model.set_door_open("test_gate",true)
	if frame == 215: commands = ["shield"]
	if frame == 290:
		commands = ["rain"]
		aim = Vector2(-35,0)
	if frame == 245: model.spawn_projectile(Vector2(280,90),(model.player-Vector2(280,90)).normalized()*80)
	if frame == 270: model.spawn_zone(model.player)
	if not paused: model.step_commands(movement,aim,commands,held)
	var actors: Array = []
	for enemy in model.ordered_enemies():
		actors.append({"id":enemy.id,"pos":[enemy.pos.x,enemy.pos.y],"hp":enemy.hp,"state":enemy.state,"age":enemy.age})
	trace.append({"frame":frame,"tick":model.tick,"input":{"move":[movement.x,movement.y],"aim":[aim.x,aim.y],"commands":commands,"held":held,"paused":paused},"player":[model.player.x,model.player.y],"hp":model.hp,"focus":model.focus,"action":model.action,"age":model.age,"cooldowns":model.cooldowns.duplicate(),"actors":actors,"projectiles":model.projectiles.size(),"zones":model.zones.size(),"shield":model.shield_hp,"shield_until":model.shield_until,"rains":model.rains.duplicate(true),"events":model.history.slice(history_start).duplicate(true)})
	frame += 1
	return frame >= 360

func save(path: String) -> Error:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"build":"G2-007","physics_hz":Engine.physics_ticks_per_second,"requested_fps":Engine.max_fps,"elapsed_seconds":float(Time.get_ticks_usec()-started_usec)/1000000,"drawn_frames":Engine.get_frames_drawn()-started_draws,"process_intervals":process_intervals,"trace":trace}))
	file.close()
	return OK

