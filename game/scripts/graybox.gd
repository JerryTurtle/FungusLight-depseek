extends Node2D

const Model = preload("res://scripts/combat_model.gd")
const CORPSE_LINGER := 210
const CORPSE_FADE := 45
var combat = Model.new()
var dead_since: Dictionary = {}
var hide_player := false
var paused := false
var hud: Label
var status: Label
var world: Node2D
var floating_ui: Node2D
var commands: Array[String] = []
var replay = null
var replay_done := false
var capture_frames := 0
var art = preload("res://scripts/world_art.gd").new()
var sewer := false
var debug_shapes := false
var pose_view := false
var grip_review := false
var pose_playing := true
var pose_tick := 0
var player_moving := false
var preferences = preload("res://scripts/presentation_settings.gd").new()
var settings_panel = preload("res://scripts/settings_panel.gd").new()
var feedback = preload("res://scripts/combat_feedback.gd").new()
var settings_was_paused := false
var review_mode := false
var show_rain_aim := true
var review_zoom := 4.0
var demo_driver = null
var environment_fx := false
var practice := false
var death_age := 0
var scan_tick := -1000
var queued_pointer := Vector2.INF
var combat_audio = preload("res://scripts/combat_audio.gd").new()

func _ready() -> void:
	if not review_mode:
		ThemeDB.fallback_font = load("res://assets/fonts/FusionPixel12px-zh_hans.ttf")
		ThemeDB.fallback_font_size = 24
	combat.reset()
	add_child(combat_audio)
	if "--integration" in OS.get_cmdline_user_args():
		preferences.path = "user://presentation-test.cfg"
	else:
		preferences.read_settings()
	combat_audio.set_volume(preferences.sfx_volume)
	grip_review = "--grip-review" in OS.get_cmdline_user_args()
	pose_view = "--poses" in OS.get_cmdline_user_args() or grip_review
	if grip_review: pose_playing = false
	sewer = "--sewer" in OS.get_cmdline_user_args()
	world = Node2D.new()
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.scale = Vector2(4,4)
	world.draw.connect(draw_world)
	add_child(world)
	floating_ui = Node2D.new()
	floating_ui.draw.connect(func():
		if not pose_view: feedback.draw_numbers(floating_ui,combat.tick,preferences))
	add_child(floating_ui)
	var panel := ColorRect.new()
	# Text sits directly on the world; readability comes from the label outline.
	panel.color = Color(0.03,0.06,0.08,0.0)
	panel.size = Vector2(1280,100)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	hud = Label.new()
	hud.position = Vector2(28,12)
	hud.add_theme_font_size_override("font_size",24)
	hud.add_theme_constant_override("outline_size",4)
	hud.add_theme_color_override("font_outline_color",Color(0.02,0.035,0.04,0.95))
	add_child(hud)
	status = Label.new()
	status.position = Vector2(28,654)
	status.add_theme_font_size_override("font_size",24)
	status.add_theme_constant_override("outline_size",4)
	status.add_theme_color_override("font_outline_color",Color(0.02,0.035,0.04,0.95))
	add_child(status)
	if review_mode:
		panel.hide()
		hud.hide()
		status.hide()
	settings_panel.preferences = preferences
	add_child(settings_panel)
	settings_panel.dismissed.connect(toggle_settings)
	settings_panel.changed.connect(func(): combat_audio.set_volume(preferences.sfx_volume))
	get_window().focus_exited.connect(func():
		if replay == null and "--stress" not in OS.get_cmdline_user_args():
			paused = true
			combat_audio.stop_all())
	if "--replay" in OS.get_cmdline_user_args():
		replay = preload("res://scripts/replay_driver.gd").new()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("G2_READY | G2-007 | 60Hz | prototype")
	if "--hazard-demo" in OS.get_cmdline_user_args():
		combat.spawn_zone(Vector2(90,130))
		combat.spawn_projectile(Vector2(280,90),Vector2.LEFT*float(combat.config.hazards.projectile.speed))
	if "--spell-demo" in OS.get_cmdline_user_args() or "--impact-demo" in OS.get_cmdline_user_args():
		combat.enemies.clear()
		combat.add_enemy(Vector2(110,95),true)
		combat.step(Vector2.ZERO,Vector2(40,0),"shield")
		for i in 18: combat.step(Vector2.ZERO,Vector2(40,0))
		combat.step(Vector2.ZERO,Vector2(40,0),"rain")
		for i in 21: combat.step(Vector2.ZERO,Vector2(40,0))
		if "--impact-demo" in OS.get_cmdline_user_args():
			for i in 30: combat.step(Vector2.ZERO,Vector2.RIGHT)
	if "--feedback-demo" in OS.get_cmdline_user_args():
		combat.enemies.clear()
		var target = combat.add_enemy(Vector2(110,95),true)
		target.armor_layers = 1
		combat.step(Vector2.ZERO,Vector2.RIGHT,"light")
		feedback.consume(combat)
		for i in 12:
			combat.step(Vector2.ZERO,Vector2.RIGHT)
			feedback.consume(combat)
		paused = true
	if "--low-effects" in OS.get_cmdline_user_args():
		preferences.low_effects = true
		preferences.reduced_motion = true
		preferences.reduced_flash = true
	if "--settings-demo" in OS.get_cmdline_user_args(): toggle_settings()
	if "--armor-demo" in OS.get_cmdline_user_args():
		combat.enemies[0].armor_layers = 2
	if "--integration" in OS.get_cmdline_user_args():
		set_physics_process(false)
		call_deferred("start_integration")

func start_integration() -> void:
	var runner = preload("res://scripts/integration_test.gd").new()
	add_child(runner)
	runner.run(self)

func _unhandled_input(event: InputEvent) -> void:
	if "--stress" in OS.get_cmdline_user_args(): return
	if replay != null: return
	if review_mode and event is InputEventKey and event.physical_keycode in [KEY_F1,KEY_F2,KEY_F3,KEY_F4,KEY_F6]: return
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_F1 or (settings_panel.visible and event.physical_keycode == KEY_ESCAPE)):
		toggle_settings()
		get_viewport().set_input_as_handled()
		return
	if settings_panel.visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F6:
				grip_review = not grip_review
				pose_view = true
				pose_playing = not grip_review
				commands.clear()
				combat_audio.stop_all()
			KEY_F2:
				pose_view = not pose_view
				commands.clear()
				combat_audio.stop_all()
			KEY_F3:
				sewer = not sewer
			KEY_F4:
				debug_shapes = not debug_shapes
			KEY_COMMA:
				pose_playing = not pose_playing
			KEY_PERIOD:
				if pose_view:
					pose_playing = false
					pose_tick += 1
			KEY_ESCAPE:
				paused = not paused
				commands.clear()
				if paused: combat_audio.stop_all()
			KEY_F5:
				combat.reset()
				feedback.reset()
				commands.clear()
				combat_audio.stop_all()
			KEY_Q:
				if not paused: scan_tick = combat.tick
			KEY_H:
				if not paused and not pose_view:
					for enemy in combat.enemies:
						if enemy.dummy and enemy.hp > 0: enemy.armor_layers = 2 if enemy.armor_layers == 0 else 0
			KEY_1:
				commands.append("shield")
			KEY_2:
				commands.append("rain")
			KEY_SPACE:
				commands.append("dodge")
			KEY_G:
				if not paused and not pose_view:
					combat.set_door_open("test_gate",not combat.doors[0].open)
			KEY_B:
				if not paused and not pose_view:
					combat.spawn_projectile(Vector2(280,90),(combat.player-Vector2(280,90)).normalized()*float(combat.config.hazards.projectile.speed))
			KEY_V:
				if not paused and not pose_view: combat.spawn_zone(Vector2(90,130))
	if event is InputEventMouseButton and event.pressed:
		queued_pointer = event.position
		if event.button_index == MOUSE_BUTTON_LEFT:
			commands.append("melee")
		if event.button_index == MOUSE_BUTTON_RIGHT:
			commands.append("light")

func _process(delta: float) -> void:
	if replay != null and not replay_done: replay.process_intervals.append(delta)

func _physics_process(_delta: float) -> void:
	if replay_done: return
	if practice and not paused:
		combat.focus = 100
		for key in combat.cooldowns: combat.cooldowns[key] = 0
	if demo_driver != null and not paused:
		var previous: Vector2 = combat.player
		demo_driver.advance(self)
		combat_audio.consume(combat.events)
		feedback.consume(combat)
		player_moving = combat.player.distance_squared_to(previous) > 0.001
	elif replay != null:
		var old_tick: int = combat.tick
		if replay.advance(combat):
			replay_done = true
			call_deferred("finish_replay")
		if combat.tick != old_tick: feedback.consume(combat)
	elif pose_view:
		if pose_playing and not paused: pose_tick += 1
	elif not paused:
		var movement := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		var pointer := world.to_local(queued_pointer if queued_pointer.is_finite() else get_global_mouse_position())
		var in_world := Rect2(0,25,320,135).has_point(pointer)
		var valid: Array = commands.filter(func(item): return in_world or item in ["dodge","shield"])
		var previous: Vector2 = combat.player
		combat.step_commands(movement,pointer-combat.player,valid,in_world and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
		combat_audio.consume(combat.events)
		feedback.consume(combat)
		player_moving = combat.player.distance_squared_to(previous) > 0.001
	commands.clear()
	queued_pointer = Vector2.INF
	if not paused: death_age = death_age+1 if combat.hp <= 0 else 0
	if review_mode:
		world.scale = Vector2.ONE*review_zoom
		var focus_point: Vector2 = combat.player if demo_driver == null else Vector2(110,95)
		world.position = (Vector2(get_viewport_rect().size.x/2,get_viewport_rect().size.y/2+36)-focus_point*review_zoom).round()
		floating_ui.position = world.position
		floating_ui.scale = Vector2.ONE*review_zoom/4
	world.queue_redraw()
	floating_ui.queue_redraw()
	hud.text = "菌灯之下   /   G2-007 动作素材原型  ·  F1 设置\n生命 %d / 100     专注 %d / 100     净光 %.1fs     闪避 %.1fs" % [combat.hp,combat.focus,float(combat.cooldowns.light)/60,float(combat.cooldowns.dodge)/60]
	hud.text += "    护灯 %d / %.1fs    灯雨 %.1fs" % [combat.shield_hp,float(combat.cooldowns.shield)/60,float(combat.cooldowns.rain)/60]
	status.text = "WASD 移动 · 左/右键 灯击/净光 · 1 护灯 · 2 灯雨 · 空格 闪避 · Esc 暂停 · F5 重置\n%s" % ("已暂停，按 Esc 继续" if paused else ("已倒地，按 F5 重试" if combat.hp <= 0 else "测试：G 门（%s）· B 发射弹体 · V 生成下方毒区（3秒）" % ("开启" if combat.doors[0].open else "关闭")))
	if pose_view:
		hud.text = "菌灯之下 / G2-007 四向姿态原型  ·  %s  ·  tick %d\n从上至下：下 / 左 / 右 / 上；共享正式渲染组件，尚未完成人工审核" % ["播放" if pose_playing else "逐步",pose_tick]
		status.text = "F2 返回试打 · 逗号 播放/停帧 · 句号 单步 · F3 菌洞/水道 · F4 脚底标记\n列：待机 / 行走 / 灯击 / 净光 / 闪避 / 受击 / 倒地（动作初稿）"
		if grip_review:
			hud.text = "菌灯之下 / G2-007 握持校准\n从上至下：下 / 左 / 右 / 上；保留原角色完整帧；灯杖绑定原图手部像素"
			status.text = "F6 切回动作播放 · F2 返回试打 · F3 背景\n列：待机 / 起手 / 蓄势 / 挥击前段 / 挥击后段 / 收势 / 净光释放"
	else:
		status.text += " · H 护壳 · F2 动作 · F3 背景 · F4 判定 · F6 握持"
	capture_frames += 1
	if capture_frames == 10 and "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var path := OS.get_environment("FUNGUS_CAPTURE")
		if not path.is_empty():
			get_viewport().get_texture().get_image().save_png(path)

func corpse_alpha(enemy: Dictionary) -> float:
	# Dead bodies stay on the ground briefly, then fade out and disappear.
	if enemy.hp > 0:
		dead_since.erase(enemy.id)
		return 1.0
	if not dead_since.has(enemy.id):
		dead_since[enemy.id] = combat.tick
	var age: int = combat.tick-int(dead_since[enemy.id])
	if age > CORPSE_LINGER: return 0.0
	return clampf(float(CORPSE_LINGER-age)/float(CORPSE_FADE),0.0,1.0)

func draw_floor() -> void:
	# Campaign draws flat floor props (e.g. the bed) beneath actors here.
	pass

func draw_world() -> void:
	art.background(world,combat,sewer)
	draw_floor()
	if environment_fx:
		var phase := 0.0 if preferences.reduced_motion else float(combat.tick)/60
		for i in (8 if preferences.low_effects else 32):
			var position := Vector2(20+fmod(i*41.0+phase*2,280),40+fmod(i*23.0+phase*3,110))
			world.draw_rect(Rect2(position.round(),Vector2.ONE),Color(0.7,0.8,0.5,0.35))
		for i in 3:
			var radius := 10.0 if preferences.reduced_motion else 10+sin(phase+i)*2
			world.draw_circle(Vector2(65+i*80,130),radius,Color(0.75,0.65,0.3,0.08))
	if combat.tick-scan_tick < 60 and combat.tick >= scan_tick:
		world.draw_arc(combat.player,minf(100,(combat.tick-scan_tick)*2),0,TAU,32,Color(0.6,0.8,0.7,0.5),0.6)
	if pose_view:
		var actions := ["idle","walk","melee","light","dodge","hurt","dead"]
		var directions := [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]
		var durations := [60,60,22,27,11,10,30]
		for row_index in 4:
			for column in 7:
				var foot := Vector2(27+column*44,60+row_index*30)
				if grip_review:
					var review_action: String = "idle" if column == 0 else ("light" if column == 6 else "melee")
					var review_age: int = [0,0,3,6,9,16,12][column]
					art.actor(world,foot,directions[row_index],review_action,review_age,0,false)
				else:
					art.actor(world,foot,directions[row_index],actions[column],pose_tick % durations[column],pose_tick,actions[column] == "walk")
				if debug_shapes: world.draw_line(foot-Vector2(8,0),foot+Vector2(8,0),Color("a2dacb"),0.5)
		return
	var pointer := world.to_local(get_global_mouse_position())
	if show_rain_aim and Rect2(0,25,320,135).has_point(pointer):
		var target: Vector2 = combat.rain_target if combat.action == "rain" else pointer
		var valid: bool = combat.valid_rain_target(target)
		world.draw_arc(target,float(combat.config.actions.rain.radius),0,TAU,40,Color(0.6,0.9,0.85,0.55) if valid else Color(1,0.4,0.35,0.55),0.5)
	for rain in combat.rains:
		var center: Vector2 = rain.pos
		var radius: float = combat.config.actions.rain.radius
		world.draw_arc(center,radius,0,TAU,40,Color("b1e6d0"),1)
		if rain.hit:
			var fade := clampf(1.0-float(combat.tick-rain.impact_tick)/15,0,1)
			for offset in ([Vector2.ZERO] if preferences.low_effects else [Vector2.ZERO,Vector2(-16,-8),Vector2(14,-10),Vector2(-10,14),Vector2(12,12)]):
				world.draw_line(center+offset-Vector2(0,8 if preferences.reduced_motion else 27)*fade,center+offset,Color(0.9,1,0.8,fade*(0.5 if preferences.reduced_flash else 1.0)),2)
		else:
			var progress := 1.0-float(rain.impact_tick-combat.tick)/30
			world.draw_arc(center,radius*progress,0,TAU,32,Color(0.7,0.9,0.7,0.5),0.5)
	for zone in combat.zones:
		world.draw_circle(zone.pos,zone.radius,Color(0.6,0.65,0.2,0.25))
		world.draw_arc(zone.pos,zone.radius,0,TAU,32,Color("e0d780"),1)
		for offset in [-8,0,8]:
			world.draw_line(zone.pos+Vector2(-8,offset-4),zone.pos+Vector2(8,offset+4),Color("91944a"),0.5)
	# Painter order follows feet, including the player.
	var actors: Array[Dictionary] = [{"pos":combat.player,"is_player":true}]
	for enemy in combat.enemies: actors.append({"pos":enemy.pos,"is_player":false,"enemy":enemy})
	actors.sort_custom(func(a,b): return a.pos.y < b.pos.y)
	for entry in actors:
		if entry.is_player:
			if hide_player: continue
			var direction: Vector2 = combat.locked if combat.action in ["melee","light","shield","rain","dodge"] else combat.facing
			art.actor(world,combat.player,direction,"dead" if combat.hp <= 0 else ("idle" if preferences.reduced_flash and combat.action == "hurt" else combat.action),death_age if combat.hp <= 0 else combat.age,combat.tick,player_moving)
			if debug_shapes: world.draw_arc(combat.player,5,0,TAU,24,Color("9affcf"),0.5)
		else:
			var enemy: Dictionary = entry.enemy
			var corpse := corpse_alpha(enemy)
			if corpse <= 0.0: continue
			if enemy.dummy: art.target(world,enemy.pos,enemy.hp,corpse)
			elif enemy.get("archetype","") == "T5": art.spore_pod(world,enemy.pos,enemy.hp > 0,corpse)
			else: art.actor(world,enemy.pos,enemy.dir,"dead" if enemy.hp <= 0 else ("melee" if enemy.state == "attack" else "idle"),int(enemy.age),combat.tick,enemy.state != "attack" and enemy.alert,false,art.enemy_texture(enemy.get("archetype","T1")),corpse)
			if enemy.hp > 0:
				for layer in int(enemy.get("armor_layers",0)):
					world.draw_arc(enemy.pos-Vector2(0,14),10+layer*3,-PI*0.95,PI*0.15,12,Color("eac36c"),2)
				world.draw_rect(Rect2(enemy.pos+Vector2(-9,-29),Vector2(18,2)),Color("402d36"))
				world.draw_rect(Rect2(enemy.pos+Vector2(-9,-29),Vector2(18*clampf(enemy.hp/float(enemy.get("max_hp",72)),0,1),2)),Color("dfba84"))
			if enemy.get("archetype","T1") == "T1" and enemy.state == "attack" and enemy.age < combat.config.enemy_t1.windup+combat.config.enemy_t1.active:
				var angle: float = enemy.dir.angle()
				var radius: float = combat.config.enemy_t1.range
				var warning := Color("ff9c87") if enemy.age < combat.config.enemy_t1.windup else Color("ff6055")
				world.draw_arc(enemy.pos,radius,angle-PI/4,angle+PI/4,18,warning,1)
				for edge in [-PI/4,PI/4]: world.draw_line(enemy.pos,enemy.pos+Vector2.from_angle(angle+edge)*radius,warning,0.5)
	if combat.shield_hp > 0:
		world.draw_arc(combat.player-Vector2(0,12),17,0,TAU,32,Color("a2e7df"),1)
		world.draw_rect(Rect2(combat.player+Vector2(-10,-34),Vector2(20,2)),Color("23484e"))
		world.draw_rect(Rect2(combat.player+Vector2(-10,-34),Vector2(20*combat.shield_hp/float(combat.config.actions.shield.capacity),2)),Color("a2e7df"))
	if demo_driver != null and demo_driver.charge_preview:
		var radius: float = combat.config.hazards.projectile.radius
		world.draw_line(combat.player,combat.player+Vector2(70,0),Color(0.98,0.6,0.45,0.35),radius*2)
		for side in [-radius,radius]: world.draw_line(combat.player+Vector2(0,side),combat.player+Vector2(70,side),Color("f99a73"),0.5)
	for shot in combat.projectiles:
		world.draw_circle(shot.pos,shot.radius,Color("ea9dac"))
		world.draw_line(shot.pos,shot.pos-shot.velocity.normalized()*6,Color("aa617d"),1)
	if combat.action == "melee":
		var angle: float = combat.locked.angle()
		var active: bool = combat.age >= 6 and combat.age < 11
		if active or debug_shapes:
			world.draw_arc(combat.player,22,angle-PI/4,angle+PI/4,20,Color("ffe1a1") if active else Color("807659"),2 if active else 0.5)
	if combat.action == "light" and combat.age >= 12 and combat.age < 18:
		var lamp_tip: Vector2 = art.light_tip(combat.beam_from,combat.locked,combat.age)
		# Main core follows the authoritative collision ray. A short lamp connector is visual only.
		var join: Vector2 = combat.beam_from+combat.locked*clampf((lamp_tip-combat.beam_from).dot(combat.locked),0,combat.beam_from.distance_to(combat.beam_end))
		var glow := Color(0.55,0.85,0.76,0.55 if preferences.reduced_flash else 1.0)
		var core := Color(1,0.95,0.82,0.55 if preferences.reduced_flash else 1.0)
		world.draw_line(join,combat.beam_end,glow,float(combat.config.actions.light.width))
		world.draw_line(join,combat.beam_end,core,2)
		if combat.clear_line(combat.beam_from,lamp_tip) and combat.clear_line(lamp_tip,join):
			world.draw_line(lamp_tip,join,glow,4)
			world.draw_line(lamp_tip,join,core,2)

	feedback.draw(world,combat.tick,preferences)

func toggle_settings() -> void:
	commands.clear()
	combat_audio.stop_all()
	if settings_panel.visible:
		settings_panel.hide()
		paused = settings_was_paused
	else:
		settings_was_paused = paused
		paused = true
		settings_panel.show()

func finish_replay() -> void:
	var result: Error = replay.save(OS.get_environment("FUNGUS_REPLAY_OUTPUT"))
	print("REPLAY_SAVED ",result," frames=",replay.frame)
	get_tree().quit(0 if result == OK else 1)

