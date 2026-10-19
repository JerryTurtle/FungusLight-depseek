extends "res://scripts/graybox.gd"
## G3 gameplay adapter reuses the accepted combat/rendering components.
const Progress = preload("res://scripts/campaign_state.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const HUD = preload("res://scripts/campaign_hud.gd")
const Intro = preload("res://scripts/intro_cinematic.gd")
const TITLE_BG = preload("res://assets/title/title_bg.png")
const UI_FONT = preload("res://assets/fonts/FusionPixel12px-zh_hans.ttf")
const DIR_NAMES := ["上","右","下","左"]
const DIR_VECTORS := [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]
var progress = Progress.new()
var saves = SaveStore.new()
var title_bg: TextureRect
var title_scrim: ColorRect
var overlay: PanelContainer
var menu_style: StyleBoxFlat
var title_style: StyleBoxEmpty
var menu: VBoxContainer
var notice := ""
var running := false
var scanned := false
var dialogue_index := 0
var dialogue_mode := ""
var dialogue_lines: Array = []
var choice_pending := false
var choice_mode := "growth"
var puzzle_choice_object: Dictionary = {}
var run_started_ms := 0
var chapter_start_ms := 0
var chapter_times: Dictionary = {}
var last_chapter := ""
var pending_encounter := ""
var checkpoint: Dictionary = {}
var room_checkpoint: Dictionary = {}
var dirty := false
var rest_ready := false
var tutorial_target := -1
var guide_dirs: Dictionary = {}
var wake_left := 0
var wake_total := 0
var wake_from := Vector2(38,108)
var wake_to := Vector2(66,124)
var objects_layer: Node2D
var ui_layer: Node2D
var dialogue
var props = preload("res://scripts/prop_art.gd").new()
var settings_return := "title"
var hud_panel
var intro
var intro_callback: Callable = Callable()
var render_prev_player := Vector2.ZERO
var render_curr_player := Vector2.ZERO
var render_prev_enemies: Dictionary = {}
var render_curr_enemies: Dictionary = {}
var render_ready := false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	combat = preload("res://scripts/campaign_combat.gd").new()
	show_rain_aim = false
	super._ready()
	# Quarter-pixel rendering removes the 4-pixel stepping that made horizontal
	# walking (especially to the right) read as a stutter. Review bench keeps
	# the accepted integer snapping.
	art.subpixel_actors = true
	if OS.is_debug_build() and not OS.get_environment("FUNGUS_SAVE_DIR").is_empty():
		saves.directory = OS.get_environment("FUNGUS_SAVE_DIR")
	objects_layer = Node2D.new()
	world.add_child(objects_layer)
	objects_layer.draw.connect(draw_objects)
	ui_layer = Node2D.new()
	add_child(ui_layer)
	ui_layer.draw.connect(draw_object_labels)
	ui_layer.draw.connect(draw_minimap)
	hud_panel = HUD.new()
	hud_panel.bind(self)
	hud_panel.visible = false
	add_child(hud_panel)
	hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.position = Vector2(436,18)
	hud.custom_minimum_size = Vector2(660,0)
	hud.size = Vector2(660,76)
	hud.max_lines_visible = 3
	hud.add_theme_font_override("font",UI_FONT)
	hud.add_theme_font_size_override("font_size",20)
	status.add_theme_font_override("font",UI_FONT)
	status.add_theme_font_size_override("font_size",20)
	status.position = Vector2(28,650)
	status.custom_minimum_size = Vector2(820,0)
	status.size = Vector2(820,54)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.max_lines_visible = 2
	title_bg = TextureRect.new()
	title_bg.texture = TITLE_BG
	title_bg.position = Vector2.ZERO
	title_bg.size = Vector2(1280,720)
	title_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	title_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_bg.modulate = Color(0.82,0.86,0.84,1.0)
	title_bg.visible = false
	add_child(title_bg)
	title_scrim = ColorRect.new()
	title_scrim.position = Vector2.ZERO
	title_scrim.size = Vector2(1280,720)
	title_scrim.color = Color(0.01,0.02,0.02,0.36)
	title_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_scrim.visible = false
	add_child(title_scrim)
	overlay = PanelContainer.new()
	overlay.position = Vector2(270,140)
	overlay.size = Vector2(740,430)
	menu_style = StyleBoxFlat.new()
	menu_style.bg_color = Color(0.015,0.035,0.040,0.97)
	menu_style.border_color = Color(0.46,0.38,0.23,0.9)
	menu_style.set_border_width_all(2)
	title_style = StyleBoxEmpty.new()
	overlay.add_theme_stylebox_override("panel", menu_style)
	add_child(overlay)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation",10)
	overlay.add_child(menu)
	dialogue = preload("res://scripts/dialogue_box.gd").new()
	add_child(dialogue)
	dialogue.advance_requested.connect(advance_dialogue)
	dialogue.skip_requested.connect(finish_dialogue)
	dialogue.choice_selected.connect(choose_choice)
	intro = Intro.new()
	add_child(intro)
	intro.finished.connect(on_intro_finished)
	settings_panel.z_index = 100
	settings_panel.dismissed.connect(on_settings_closed)
	show_title()
	if OS.is_debug_build() and "--campaign-capture" in OS.get_cmdline_user_args(): call_deferred("capture_preview")
	get_window().focus_exited.connect(func():
		if running and not overlay.visible and not dialogue.is_open(): show_pause())

func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST or not is_instance_valid(overlay): return
	if not running:
		get_tree().quit()
		return
	clear_menu("退出游戏？")
	paragraph("未保存的移动、战斗和对话会退回到最近一次安全存档；进行中的演出和奖励不会保存。")
	button("确认退出",func(): get_tree().quit())
	button("返回当前进度",func():
		if choice_pending: show_growth_choice()
		elif not dialogue_mode.is_empty(): show_dialogue()
		else: resume())

func capture_preview() -> void:
	for i in 10: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var base := OS.get_environment("FUNGUS_CAMPAIGN_CAPTURE")
	get_viewport().get_texture().get_image().save_png(base+"-title.png")
	new_game()
	for i in 10: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(base+"-camp.png")
	show_pause()
	for i in 5: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(base+"-pause.png")
	combat_audio.stop_all()
	get_tree().quit()

func clear_menu(title: String) -> void:
	if dialogue != null and dialogue.is_open(): dialogue.close()
	reset_screen_shake()
	overlay.position = Vector2(270,140)
	overlay.size = Vector2(740,430)
	if menu_style != null: overlay.add_theme_stylebox_override("panel", menu_style)
	menu.alignment = BoxContainer.ALIGNMENT_BEGIN
	menu.add_theme_constant_override("separation",10)
	paused = true
	if hud != null: hud.visible = false
	if status != null: status.visible = false
	if hud_panel != null: hud_panel.visible = false
	commands.clear()
	combat.clear_input_buffer()
	combat_audio.stop_all()
	for child in menu.get_children():
		menu.remove_child(child)
		child.queue_free()
	overlay.show()
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_override("font",UI_FONT)
	heading.add_theme_font_size_override("font_size",36)
	menu.add_child(heading)

func paragraph(text: String, min_height: float = 65.0) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(700,min_height)
	label.add_theme_font_override("font",UI_FONT)
	label.add_theme_font_size_override("font_size",24)
	menu.add_child(label)

func button(text: String, action: Callable) -> void:
	var control := Button.new()
	control.text = text
	control.add_theme_font_override("font",UI_FONT)
	control.add_theme_font_size_override("font_size",24)
	control.pressed.connect(action)
	menu.add_child(control)

func resume() -> void:
	overlay.hide()
	if title_bg != null: title_bg.visible = false
	if title_scrim != null: title_scrim.visible = false
	if dialogue != null and dialogue.is_open(): dialogue.close()
	world.visible = true
	objects_layer.visible = true
	ui_layer.visible = true
	floating_ui.visible = true
	if hud != null: hud.visible = true
	if status != null: status.visible = true
	if hud_panel != null: hud_panel.visible = true
	paused = false
	commands.clear()
	queued_pointer = Vector2.INF

func title_button(text: String, action: Callable) -> Button:
	var control := Button.new()
	control.text = text
	control.add_theme_font_override("font",UI_FONT)
	control.add_theme_font_size_override("font_size",24)
	control.add_theme_color_override("font_color",Color(0.93,0.88,0.74))
	control.add_theme_color_override("font_hover_color",Color(1.0,0.86,0.58))
	control.add_theme_color_override("font_pressed_color",Color(1.0,0.78,0.42))
	control.add_theme_color_override("font_disabled_color",Color(0.48,0.49,0.43,0.80))
	control.add_theme_constant_override("outline_size",4)
	control.add_theme_color_override("font_outline_color",Color(0.01,0.02,0.02,0.95))
	for state in ["normal","hover","pressed","focus","disabled"]:
		control.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	control.custom_minimum_size = Vector2(320,42)
	control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	control.pressed.connect(action)
	menu.add_child(control)
	return control

func show_title() -> void:
	running = false
	if title_bg != null: title_bg.visible = true
	if title_scrim != null: title_scrim.visible = true
	# A clean title screen: no test-room actors, minimap or HUD behind the menu.
	world.visible = false
	objects_layer.visible = false
	ui_layer.visible = false
	floating_ui.visible = false
	if hud != null: hud.visible = false
	if status != null: status.visible = false
	if hud_panel != null: hud_panel.visible = false
	clear_menu("菌灯之下")
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(1280,720)
	overlay.add_theme_stylebox_override("panel",title_style)
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation",8)
	var heading: Label = menu.get_child(0)
	heading.add_theme_font_override("font",UI_FONT)
	heading.add_theme_font_size_override("font_size",56)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	heading.custom_minimum_size = Vector2(440,0)
	var subtitle := Label.new()
	subtitle.text = "灯与根"
	subtitle.add_theme_font_override("font",UI_FONT)
	subtitle.add_theme_font_size_override("font_size",18)
	subtitle.add_theme_color_override("font_color",Color(0.86,0.70,0.41,0.95))
	subtitle.add_theme_constant_override("outline_size",4)
	subtitle.add_theme_color_override("font_outline_color",Color(0.01,0.02,0.02,0.95))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	subtitle.custom_minimum_size = Vector2(320,26)
	menu.add_child(subtitle)
	var auto_available := FileAccess.file_exists(saves.directory+"/auto.json")
	title_button("新游戏",func():
		if FileAccess.file_exists(saves.directory+"/auto.json"):
			clear_menu("开始新旅程？")
			paragraph("新游戏会从序章开始，并覆盖自动存档；三个手动存档不会变。")
			button("确认新游戏",new_game)
			button("返回",show_title)
		else: new_game())
	var continue_button := title_button("继续游戏（自动存档）" if auto_available else "继续游戏（无自动存档）",func(): load_game("auto"))
	continue_button.disabled = not auto_available
	title_button("读取存档",show_load_menu)
	title_button("设置",func(): open_settings("title"))
	title_button("退出",func(): get_tree().quit())

func new_game() -> void:
	if title_bg != null: title_bg.visible = false
	if title_scrim != null: title_scrim.visible = false
	run_started_ms = Time.get_ticks_msec()
	chapter_start_ms = run_started_ms
	chapter_times = {}
	last_chapter = ""
	progress = Progress.new()
	checkpoint = {}
	running = true
	load_room(Vector2.INF,100,100)
	if intro_enabled():
		play_intro(start_game_after_intro)
	else:
		start_game_after_intro()

func intro_enabled() -> bool:
	if DisplayServer.get_name() == "headless": return false
	if OS.get_environment("FUNGUS_SKIP_INTRO") == "1": return false
	if "--skip-intro" in OS.get_cmdline_user_args(): return false
	if "--campaign-capture" in OS.get_cmdline_user_args(): return false
	return true

func play_intro(callback: Callable, final_hint: String = "进入营地") -> void:
	intro_callback = callback
	intro.final_hint = final_hint
	overlay.hide()
	if dialogue != null and dialogue.is_open(): dialogue.close()
	if hud != null: hud.visible = false
	if status != null: status.visible = false
	if hud_panel != null: hud_panel.visible = false
	paused = true
	commands.clear()
	combat_audio.stop_all()
	intro.play()

func on_intro_finished() -> void:
	var callback := intro_callback
	intro_callback = Callable()
	if callback.is_valid(): callback.call()

func start_game_after_intro() -> void:
	resume()
	save_game("auto",true)
	if DisplayServer.get_name() != "headless":
		start_wake()

func start_wake() -> void:
	var bed := {}
	for object in progress.node().objects:
		if str(object.get("visual",object.kind)) == "bed": bed = object
	if bed.is_empty(): return
	wake_total = 108
	wake_left = wake_total
	hide_player = true
	notice = "……"
	wake_from = Vector2(bed.pos[0],bed.pos[1])+Vector2(-10,-20)
	wake_to = Vector2(bed.pos[0],bed.pos[1])+Vector2(24,8)
	combat.player = wake_to
	combat.facing = Vector2.DOWN

func chapter_name(id: String) -> String:
	if id.begins_with("N0-"): return "序章 · 灯与根"
	if id.begins_with("N1-"): return "第一章 · 断根"
	if id.begins_with("N2-"): return "第二章 · 排水"
	if id.begins_with("N3-"): return "第三章 · 王庭"
	return "终章 · 灯根"

func mark_chapter() -> void:
	var current := chapter_name(progress.node_id)
	if last_chapter.is_empty():
		last_chapter = current
		chapter_start_ms = Time.get_ticks_msec()
		return
	if current != last_chapter:
		chapter_times[last_chapter] = float(chapter_times.get(last_chapter,0.0)) + (Time.get_ticks_msec()-chapter_start_ms)/1000.0
		chapter_start_ms = Time.get_ticks_msec()
		last_chapter = current

func draw_player_position() -> Vector2:
	if not render_ready or paused or overlay.visible or (dialogue != null and dialogue.is_open()):
		return combat.player
	var fraction: float = clampf(Engine.get_physics_interpolation_fraction(),0.0,1.0)
	return render_prev_player.lerp(render_curr_player,fraction)

func draw_enemy_position(enemy: Dictionary) -> Vector2:
	if not render_ready or paused or overlay.visible or (dialogue != null and dialogue.is_open()):
		return enemy.pos
	var previous = render_prev_enemies.get(enemy.id,null)
	if previous == null:
		return enemy.pos
	var fraction: float = clampf(Engine.get_physics_interpolation_fraction(),0.0,1.0)
	return (previous as Vector2).lerp(enemy.pos,fraction)

func reset_render_tracking() -> void:
	render_prev_player = combat.player
	render_curr_player = combat.player
	render_prev_enemies.clear()
	render_curr_enemies.clear()
	for enemy in combat.enemies:
		render_prev_enemies[enemy.id] = enemy.pos
		render_curr_enemies[enemy.id] = enemy.pos
	render_ready = true

func load_room(position: Vector2 = Vector2.INF, health: float = -1, focus_value: float = -1) -> void:
	mark_chapter()
	reset_screen_shake()
	var prior_hp: float = combat.hp
	var prior_focus: float = combat.focus
	combat.reset()
	combat.healing_enabled = true
	combat.potions = progress.potions
	combat.enemies.clear()
	combat.walls = combat.DEFAULT_WALLS.slice(0,4)
	# G4-006 campaign-only trim: keep the G2 baseline intact while matching the
	# visible top/bottom wall pixels more closely in the story rooms.
	combat.walls[0] = Rect2(0,0,320,24)
	combat.walls[1] = Rect2(0,162,320,18)
	for wall in progress.node().walls: combat.walls.append(Rect2(wall[0],wall[1],wall[2],wall[3]))
	combat.doors.clear()
	combat.doors.append({"id":"unused","rect":Rect2(0,0,1,1),"open":true})
	setup_collision()
	var spawn: Array = progress.node().spawn
	combat.player = Vector2(spawn[0],spawn[1]) if not position.is_finite() else position
	combat.hp = clampf(prior_hp if health < 0 else health,1,progress.max_hp())
	combat.focus = clampf(prior_focus if focus_value < 0 else focus_value,0,progress.max_focus())
	sewer = progress.node().get("style","cave") == "mine"
	apply_growth()
	feedback.reset()
	combat_audio.stop_all()
	commands.clear()
	combat.clear_input_buffer()
	queued_pointer = Vector2.INF
	death_age = 0
	scanned = false
	scan_tick = -1000
	pending_encounter = ""
	tutorial_target = -1
	dialogue_mode = ""
	dialogue_lines = []
	wake_left = 0
	hide_player = false
	rest_ready = false
	reset_guides()
	start_encounters()
	reset_render_tracking()
	var room_snapshot: Dictionary = progress.snapshot(combat.player,combat.hp,combat.focus)
	if progress.validate(room_snapshot).is_empty():
		room_checkpoint = room_snapshot

func reset_guides() -> void:
	guide_dirs.clear()
	for object in progress.guides():
		guide_dirs[object.id] = int(object.solution) if progress.has("P02") else int(object.dir)

func solid_rect(kind: String, pos: Vector2) -> Rect2:
	match kind:
		"chest": return Rect2(pos+Vector2(-7,-8),Vector2(14,9))
		"crates": return Rect2(pos+Vector2(-20,-16),Vector2(40,16))
		"cabinet": return Rect2(pos+Vector2(-7,-8),Vector2(14,10))
		"barrel": return Rect2(pos+Vector2(-5,-5),Vector2(10,8))
		"shelf": return Rect2(pos+Vector2(-7,-8),Vector2(14,10))
		"torch": return Rect2(pos+Vector2(-3,-5),Vector2(6,6))
		"bed": return Rect2(pos+Vector2(-15,-44),Vector2(31,44))
		"lamp": return Rect2(pos+Vector2(-5,-5),Vector2(10,10))
		"door": return Rect2(pos+Vector2(-9,-28),Vector2(18,28))
		"portal": return Rect2(pos+Vector2(-13,-34),Vector2(26,34))
	return Rect2()

func setup_collision() -> void:
	combat.blockers.clear()
	combat.npcs.clear()
	for entry in progress.node().get("decor",[]):
		var rect: Rect2 = solid_rect(str(entry.kind),Vector2(entry.pos[0],entry.pos[1]))
		if rect.size.x > 0: combat.blockers.append(rect)
	for object in progress.node().objects:
		var pos := Vector2(object.pos[0],object.pos[1])
		var visual := str(object.get("visual",object.kind))
		if visual == "rest": visual = "bed" if str(object.get("visual","")) == "bed" else "lamp"
		if str(object.kind) == "end": visual = "portal"
		if str(object.kind) == "exit": visual = "portal"
		var rect: Rect2 = solid_rect(visual,pos)
		if str(object.kind) in ["switch"]: rect = Rect2()
		# The ending choice stands in the middle of the core room. It is a
		# choice marker, not cover: keeping its portal collision would block
		# the boss line of sight and split the arena during the final fight.
		if str(object.kind) == "ending": rect = Rect2()
		# Rest lamps are now placed beside exits. Keep the seat walkable so it
		# never blocks the narrow exit approach; the bed keeps its collision.
		if str(object.kind) == "rest" and visual == "lamp": rect = Rect2()
		if rect.size.x > 0: combat.blockers.append(rect)
		if str(object.kind) in ["rong","npc"] or bool(object.get("npc",false)):
			combat.npcs.append({"id":str(object.id),"pos":pos+Vector2(0,-12),"radius":7.0})

func guide_aligned(object: Dictionary) -> bool:
	return int(guide_dirs.get(object.id,int(object.dir))) == int(object.solution)

func guides_aligned() -> bool:
	var found: Array = progress.guides()
	if found.is_empty(): return false
	for guide in found:
		if not guide_aligned(guide): return false
	return true

func guides_correct() -> int:
	var count := 0
	for guide in progress.guides():
		if guide_aligned(guide): count += 1
	return count

func apply_growth() -> void:
	combat.config.player.hp = progress.max_hp()
	combat.config.player.focus = progress.max_focus()
	combat.config.player.hit_focus = progress.hit_focus_gain()
	combat.config.actions.melee.damage = progress.melee_damage()
	combat.config.actions.light.damage = progress.light_damage()
	combat.config.actions.light.cost = progress.light_cost()
	combat.config.actions.rain.damage = progress.rain_damage()
	combat.config.actions.rain.cost = progress.rain_cost()
	combat.config.actions.shield.capacity = progress.shield_capacity()
	combat.config.actions.shield.cost = progress.shield_cost()
	combat.config.actions.shield.cooldown = progress.shield_cooldown()
	combat.config.actions.heal.healing = progress.heal_amount()
	combat.config.actions.heal.windup = progress.heal_windup()
	combat.hp = minf(combat.hp,progress.max_hp())
	combat.focus = minf(combat.focus,progress.max_focus())
	combat.shield_hp = minf(combat.shield_hp,float(progress.shield_capacity()))

func start_encounters() -> void:
	if not pending_encounter.is_empty(): return
	for id in progress.content.encounters:
		var spec: Dictionary = progress.content.encounters[id]
		if str(spec.get("node","")) != progress.node_id or progress.has(id): continue
		var requires: String = spec.get("requires","")
		if not requires.is_empty() and not progress.has(requires): continue
		spawn_encounter(id,spec)
		pending_encounter = id
		return

func adjust_spawn(at: Vector2) -> Vector2:
	if combat.player.distance_to(at) >= 20 and not combat.blocked(at,6): return at
	for radius in [16,24,32,40,48,56]:
		for i in 12:
			var candidate: Vector2 = at + Vector2.from_angle(TAU*float(i)/12.0)*float(radius)
			if not combat.blocked(candidate,6) and combat.player.distance_to(candidate) >= 20: return candidate
	return at

func spawn_encounter(id: String, spec: Dictionary) -> void:
	var archetype: String = spec.get("archetype","T1")
	for point in spec.get("positions",[]):
		var at := adjust_spawn(Vector2(point[0],point[1]))
		if bool(spec.get("dummy",false)):
			var target: Dictionary = combat.add_enemy(at,true)
			target.hp = float(spec.get("hp",24))
			tutorial_target = int(target.id)
		elif archetype == "T1": combat.add_enemy(at)
		else: combat.add_archetype(archetype,at)
	for member in spec.get("members",[]):
		var spawned: Dictionary = combat.add_archetype(str(member[0]),adjust_spawn(Vector2(member[1],member[2])))
		if spec.has("hp_mult"):
			spawned.max_hp = float(spawned.get("max_hp",spawned.hp))*float(spec.hp_mult)
			spawned.hp = spawned.max_hp

func safety() -> Dictionary:
	var alerted := false
	var elite := false
	for enemy in combat.enemies:
		if enemy.hp > 0 and not enemy.dummy:
			alerted = true
			if str(enemy.get("archetype","T1")) in ["EL1","EL2","BOSS"]: elite = true
	return {"no_alert_enemies":not alerted,"no_hazards":combat.projectiles.is_empty() and combat.zones.is_empty() and combat.rains.is_empty() and combat.field_hazards.is_empty() and combat.poison_until <= combat.tick,"player_idle":combat.action == "idle" and combat.hp > 0,
		"no_blocking_event":progress.active_event.is_empty(),"walkable_position":not combat.blocked(combat.player),"no_elite_battle":not elite}

func save_game(slot: String, confirmed: bool = false) -> void:
	var snapshot: Dictionary = progress.snapshot(combat.player,combat.hp,combat.focus)
	var error: String = progress.validate(snapshot)
	if not error.is_empty():
		notice = error
		return
	var result: Dictionary = saves.save_slot(slot,snapshot,safety(),confirmed)
	notice = result.message
	if result.ok:
		notice = "已自动保存。" if slot == "auto" else "已保存到 "+slot_name(slot)+"。"
		checkpoint = snapshot.duplicate(true)
		dirty = false
	elif result.code == "confirmation_required":
		clear_menu("覆盖存档？")
		paragraph("把当前进度写入 "+slot_name(slot)+"。原有存档会保留为备份。")
		button("确认覆盖",func(): save_game(slot,true); show_pause())
		button("取消",show_pause)

func load_game(slot: String, backup: bool = false) -> void:
	var result: Dictionary = saves.load_slot(slot,backup)
	if not result.ok:
		clear_menu("无法读取存档")
		paragraph(result.message)
		if result.get("backup_available",false): button("恢复上一次备份",func(): load_game(slot,true))
		button("返回",show_load_menu)
		return
	var reason: String = progress.validate(result.snapshot)
	if not reason.is_empty():
		clear_menu("存档无法恢复")
		paragraph(reason)
		if not backup and saves.load_slot(slot,true).ok: button("恢复备份",func(): load_game(slot,true))
		button("返回",show_load_menu)
		return
	progress.restore(result.snapshot)
	run_started_ms = Time.get_ticks_msec()
	chapter_start_ms = run_started_ms
	chapter_times = {}
	last_chapter = ""
	checkpoint = result.snapshot.duplicate(true)
	running = true
	dirty = false
	load_room(Vector2(result.snapshot.safe_position[0],result.snapshot.safe_position[1]),result.snapshot.health,result.snapshot.focus)
	resume()
	notice = "已读取"+slot_name(slot)+("（备份，进度可能回退到更早的安全点）。" if backup else "。")

func open_settings(return_to: String) -> void:
	settings_return = return_to
	settings_was_paused = paused
	if overlay != null: overlay.hide()
	paused = true
	if hud != null: hud.visible = false
	if status != null: status.visible = false
	if ui_layer != null: ui_layer.visible = false
	if floating_ui != null: floating_ui.visible = false
	if hud_panel != null: hud_panel.visible = false
	settings_panel.show()

func on_settings_closed() -> void:
	settings_panel.hide()
	if running: show_pause()
	else: show_title()

func slot_name(slot: String) -> String:
	return {"auto":"自动存档","manual_1":"手动存档 1","manual_2":"手动存档 2","manual_3":"手动存档 3"}.get(slot,slot)

func slot_label(slot: String) -> String:
	var title: String = slot_name(slot)
	var result: Dictionary = saves.load_slot(slot)
	if not result.ok:
		if bool(result.get("backup_available",false)): return title+"（仅备份可恢复）"
		if FileAccess.file_exists(saves.directory+"/"+slot+".json"): return title+"（存档损坏）"
		return title+"（无存档）"
	var snap: Dictionary = result.snapshot
	var node_def: Dictionary = progress.node(str(snap.get("node_id","")))
	var place: String = str(node_def.get("name","未知区域"))
	var seconds := int(float(snap.get("effective_seconds",0)))
	return "%s · %s · %02d:%02d" % [title,place,int(seconds/60),seconds%60]

func show_load_menu() -> void:
	clear_menu("读取存档")
	paragraph("自动存档只会在安全时写入；覆盖手动存档前会再确认一次。")
	for slot in SaveStore.SLOTS:
		var has_slot := FileAccess.file_exists(saves.directory+"/"+slot+".json") or FileAccess.file_exists(saves.directory+"/"+slot+".json.bak")
		var load_button := Button.new()
		load_button.text = slot_label(slot)
		load_button.disabled = not has_slot
		load_button.add_theme_font_size_override("font_size",24)
		load_button.pressed.connect(func(): load_game(slot))
		menu.add_child(load_button)
	button("返回",func():
		if running: show_pause()
		else: show_title())

func show_pause() -> void:
	if wake_left > 0: return
	clear_menu("暂停 · "+progress.node().name)
	overlay.position = Vector2(270,40)
	overlay.size = Vector2(740,640)
	paragraph(("有未保存的进度。\n" if dirty else "")+notice+"\nWASD移动 · E交互 · Q观察 · R药剂 · 空格闪避 · Esc暂停")
	button("继续",resume)
	for slot in ["manual_1","manual_2","manual_3"]:
		button("保存到 "+slot_name(slot),func():
			save_game(slot)
			if menu.get_child(0).text != "覆盖存档？": show_pause())
	button("任务与证据",show_journal)
	if rest_ready: button("装备配置（休息点）",show_equipment)
	else: paragraph("装备只能在休息点配置。",36)
	button("读取存档",show_load_menu)
	button("设置",func(): open_settings("pause"))
	button("返回标题",func():
		clear_menu("返回标题？")
		paragraph("未保存的进度会丢失，回到最近一次存档。")
		button("确认返回标题",show_title)
		button("取消",show_pause))

func quest_status(id: String) -> String:
	if progress.has(id): return "已完成"
	var count := 0
	for part in ["a","b","c"]:
		if progress.has(id+part): count += 1
	return "未开始" if count == 0 else "进行中 %d/3" % count

func show_journal() -> void:
	clear_menu("任务与证据")
	overlay.position = Vector2(270,28)
	overlay.size = Vector2(740,664)
	paragraph("当前目标：\n"+current_goal(),88)
	var ev: Dictionary = progress.evidence()
	var evidence_lines := PackedStringArray()
	evidence_lines.append("证据 %d / 3" % progress.evidence_count())
	if bool(ev.root_cut): evidence_lines.append("· 断根切口：根桥的斧痕，斧柄带避难所钢印。\n  是人先砍根断水。")
	if bool(ev.pump_record): evidence_lines.append("· 抽水记录：控制室，泵压超过泵站安全红线。\n  禾在末尾签名，承认抬压和砍根。")
	if bool(ev.covenant): evidence_lines.append("· 旧约残片：王庭外环的留声，证明灯与根同源。\n  全文在旧约墙，可补全缺句。")
	if evidence_lines.size() == 1: evidence_lines.append("尚未取得关键证据。先看水，再查根。")
	paragraph("\n".join(evidence_lines),170)
	var branch := PackedStringArray()
	branch.append("支路：排水 %s · 救援 %s · 合流 %s" % ["已完成" if progress.has("P04") else "未完成","已完成" if progress.has("P05") else "未完成","已开启" if progress.has("S06") else "未开启"])
	branch.append("共生结局：三份证据 %d/3 · 泵站稳压 %s" % [progress.evidence_count(),"已完成" if progress.has("P09") else "未完成"])
	branch.append("封存结局：备用储水 %s · 旧约校准 %s" % ["已完成" if progress.has("P06") else "未完成","已完成" if progress.has("P08") else "未完成"])
	branch.append("支线：旧灯 %s · 补给 %s" % [quest_status("Q1"),quest_status("Q2")])
	paragraph("\n".join(branch),100)
	button("返回",show_pause)

func show_equipment() -> void:
	clear_menu("装备配置 · 灯镜 / 护符")
	overlay.position = Vector2(270,70)
	overlay.size = Vector2(740,580)
	var lens_names := {"focus_lens":"聚束镜（净光伤害 +20%，精力消耗 +5）","throttle_lens":"节流镜（所有技能精力消耗 -3）","clear_mirror":"澄明镜（护灯可清除孢毒，精力消耗 +5）"}
	var charm_names := {"guardian_knot":"守灯结（生命上限 +10）","artisan_clasp":"工匠扣（护灯护盾 +10，冷却延长 1 秒）","ember_talisman":"余温符（药剂恢复 +10，饮用时间 +0.1 秒）"}
	paragraph("当前灯镜："+(lens_names.get(progress.lens_id,"未装备"))+"\n当前护符："+(charm_names.get(progress.charm_id,"未装备"))+"\n● 已装备　　○ 可装备",130)
	for item in ["focus_lens","throttle_lens","clear_mirror"]:
		if not progress.owns(item): continue
		var captured: String = str(item)
		button(("● " if progress.lens_id == item else "○ ")+lens_names[item],func():
			progress.equip("lens",captured); apply_growth(); show_equipment())
	for item in ["guardian_knot","artisan_clasp","ember_talisman"]:
		if not progress.owns(item): continue
		var captured_charm: String = str(item)
		button(("● " if progress.charm_id == item else "○ ")+charm_names[item],func():
			progress.equip("charm",captured_charm); apply_growth(); show_equipment())
	button("返回",show_pause)

func begin_dialogue(id: String) -> void:
	if not progress.start_event(id): return
	dialogue_mode = "event"
	dialogue_lines = progress.content.dialogues[id]
	dialogue_index = 0
	show_dialogue()

func begin_lore(id: String) -> void:
	if dialogue_mode != "" or not progress.content.dialogues.has(id): return
	dialogue_mode = "lore"
	dialogue_lines = progress.content.dialogues[id]
	dialogue_index = 0
	show_dialogue()

func show_dialogue() -> void:
	if dialogue_lines.is_empty(): return
	choice_pending = false
	dialogue_index = clampi(dialogue_index,0,dialogue_lines.size()-1)
	paused = true
	overlay.hide()
	if status != null: status.visible = false
	if hud_panel != null: hud_panel.visible = false
	dialogue.show_line(str(dialogue_lines[dialogue_index][0]),str(dialogue_lines[dialogue_index][1]))

func advance_dialogue() -> void:
	if dialogue_mode.is_empty(): return
	dialogue_index += 1
	if dialogue_index >= dialogue_lines.size(): finish_dialogue()
	else: show_dialogue()

func finish_dialogue() -> void:
	if dialogue_mode == "event" and progress.active_event in ["M1","M2","M3","M4"]:
		show_growth_choice(progress.active_event)
		return
	if dialogue_mode == "event":
		progress.finish_event()
		dirty = true
		dialogue_mode = ""
		dialogue_lines = []
		dialogue.close()
		start_encounters()
		resume()
		if SaveStore.is_safe(safety()): save_game("auto",true)
		return
	dialogue_mode = ""
	dialogue_lines = []
	dialogue.close()
	resume()

func show_growth_choice(event_id: String = "M1") -> void:
	if not progress.active_event.is_empty() and progress.active_event != event_id: return
	if progress.active_event.is_empty() and not progress.start_event(event_id):
		notice = "这里还不能强化。"
		return
	choice_mode = "growth"
	choice_pending = true
	paused = true
	overlay.hide()
	if status != null: status.visible = false
	if hud_panel != null: hud_panel.visible = false
	var def := progress.event_def(event_id)
	dialogue.show_choices(str(def.get("title", "选择一项强化"))+"（选择后不可更改）", def.get("options", []))

func choose_choice(option: String) -> void:
	if choice_mode == "ending":
		choose_ending(option)
	elif choice_mode == "puzzle":
		choose_puzzle_choice(option)
	else:
		choose_growth(option)

func show_puzzle_choice(object: Dictionary) -> void:
	var puzzle := str(object.get("puzzle",""))
	if puzzle.is_empty() or progress.has(puzzle):
		notice = "这个机关已经完成。"
		return
	puzzle_choice_object = object
	choice_mode = "puzzle"
	choice_pending = true
	paused = true
	overlay.hide()
	if status != null: status.visible = false
	if hud_panel != null: hud_panel.visible = false
	dialogue.show_choices(str(object.get("name","证据对照")), object.get("options", []))

func choose_puzzle_choice(option: String) -> void:
	if choice_mode != "puzzle" or puzzle_choice_object.is_empty(): return
	var correct := false
	for item in puzzle_choice_object.get("options", []):
		if str(item.get("id","")) == option and bool(item.get("correct",false)): correct = true
	var puzzle := str(puzzle_choice_object.get("puzzle",""))
	if correct:
		if not puzzle.is_empty(): progress.flags[puzzle] = true
		notice = "结论：" + str(puzzle_choice_object.get("success","机关接通。"))
	else:
		notice = "判断和现场对不上。再看一遍线索和顺序。"
	choice_pending = false
	choice_mode = "growth"
	puzzle_choice_object = {}
	dialogue.close()
	resume()
	dirty = true

func choose_growth(option: String) -> void:
	if choice_mode != "growth" or not progress.finish_event(option): return
	dialogue_mode = ""
	dialogue_lines = []
	choice_pending = false
	choice_mode = "growth"
	dialogue.close()
	apply_growth()
	# Fixed growth only raises the capacity; it must not act as a free full heal.
	dirty = true
	resume()
	save_game("auto",true)

func show_ending_choice() -> void:
	if not progress.has("E30"):
		notice = "母体还没被压制。"
		return
	if not progress.ending_id().is_empty():
		notice = "灯根的选择已经写下了。"
		return
	var req: Dictionary = progress.ending_requirements()
	var options: Array = []
	if bool(req.restore):
		options.append({"id":"restore","label":"恢复共生循环","desc":"三份证据已齐，泵站已校准。确认限流：灯根和营地各用一半水。"})
	if bool(req.seal):
		options.append({"id":"seal","label":"封存并撤离","desc":"备用储水与撤离路已备好。确认封门：带水撤离，放弃旧居。"})
	if options.is_empty():
		notice = "还缺证据或关键机关。补齐后再来。"
		return
	choice_mode = "ending"
	choice_pending = true
	paused = true
	overlay.hide()
	if status != null: status.visible = false
	if hud_panel != null: hud_panel.visible = false
	dialogue.show_choices("灯根核心 · 最后的选择（确认后不可更改）", options)

func choose_ending(option: String) -> void:
	if choice_mode != "ending" or option not in ["restore","seal"]: return
	if not bool(progress.ending_requirements().get(option,false)):
		notice = "这个结局的条件还没满足。"
		return
	# Preserve a separate pre-ending snapshot before END_* flags are written.
	var pre: Dictionary = progress.snapshot(combat.player,combat.hp,combat.focus)
	var backup: Dictionary = saves.save_ending_backup(pre)
	if not backup.ok: notice = backup.message
	progress.set_ending(option)
	choice_pending = false
	choice_mode = "growth"
	dialogue.close()
	notice = "你选择了" + ("恢复共生循环。" if option == "restore" else "封存并撤离。")
	dirty = true
	apply_growth()
	resume()
	save_game("auto",true)

func elapsed_text() -> String:
	var seconds := int((Time.get_ticks_msec()-run_started_ms)/1000) if run_started_ms > 0 else int(progress.seconds)
	return "%02d:%02d" % [int(seconds/60), seconds%60]

func chapter_report_text() -> String:
	if chapter_times.is_empty(): return "章节记录：本次未记录章节用时。"
	var parts := PackedStringArray()
	for key in chapter_times.keys():
		var value := int(round(float(chapter_times[key])))
		parts.append("%s %02d:%02d" % [str(key),int(value/60),value%60])
	return "章节记录：" + " · ".join(parts)

func write_run_report() -> void:
	if not last_chapter.is_empty():
		chapter_times[last_chapter] = float(chapter_times.get(last_chapter,0.0)) + (Time.get_ticks_msec()-chapter_start_ms)/1000.0
		chapter_start_ms = Time.get_ticks_msec()
		last_chapter = ""
	var total := (Time.get_ticks_msec()-run_started_ms)/1000.0
	var report := {
		"build":str(ProjectSettings.get_setting("application/config/version","G6-008")),
		"total_seconds":snappedf(total,0.1),
		"effective_seconds":snappedf(float(progress.seconds),0.1),
		"ending":progress.ending_id(),
		"node":progress.node_id,
		"chapters":chapter_times,
		"equipment":progress.equipment(),
		"recorded_at":Time.get_datetime_string_from_system()
	}
	var path := preload("res://scripts/user_storage.gd").directory()+"run_report.json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
		notice = "本局记录已保存。"
	else:
		notice = "本局记录保存失败。"

func show_credits() -> void:
	if not progress.has("S12"): progress.flags.S12 = true
	dirty = true
	write_run_report()
	var restored := progress.ending_id() == "restore"
	clear_menu("菌灯之下 · 尾声（恢复共生）" if restored else "菌灯之下 · 尾声（封存撤离）")
	overlay.position = Vector2(270,8)
	overlay.size = Vector2(740,704)
	var epilogue := ""
	if restored:
		epilogue = "三份证据嵌在旧约刻槽里。岚把手按在灯根核心上。\n泵站按新约限流，水只够灯根和营地各用一半。\n从今天起，灯不再整夜亮；每三天，岚来调一次水。\n绒留在营地最后一盏灯旁，教新来的人认水位。\n砾在旁室清点人数，确认没有人被落下。\n岚把禾的残页压在刻槽下。禾没有回来，但灯根记得他的名字。\n菌根重新发光。光很暗，但不再攻击。\n避难所保住了。代价是所有人都要学会少用水。\n岚：这不是胜利，这是新约。"
	else:
		epilogue = "三份证据收进袋子。备用储水已经启动，撤离路已经打开。\n岚最后看了一眼灯根，根门在身后合拢。母体留在里面。\n灯根被封在湿土里，会睡下去；水我们带走，够走到地面。\n砾拄着腿，带旁室的两个伤员先走，名单末尾画了一个钩。\n灯一盏盏熄灭。绒没有跟来，留在营地最后一盏灯旁。\n灯灭后，它回到水脉里沉睡。\n地下旧居留在黑暗里。菌根会沉睡，不再为人点灯。\n岚把禾的残页带走。地下只剩他的名字，和半页纸。\n岚：我们活下来了。有些东西，被留在了下面。"
	paragraph(epilogue,322)
	paragraph("本次游玩用时 " + elapsed_text() + "。\n" + chapter_report_text() + "\n结局：%s。" % ("恢复共生循环" if restored else "封存并撤离"),100)
	paragraph("制作：AI 辅助开发 · 体验审核：玩家",40)
	button("返回标题", show_title)
	if saves.load_ending_backup().ok:
		button("读取结局前存档（独立备份）", load_ending_backup_game)

func load_ending_backup_game() -> void:
	var result: Dictionary = saves.load_ending_backup()
	if not result.ok:
		clear_menu("无法读取结局前存档")
		paragraph(result.message)
		button("返回", show_credits)
		return
	var reason: String = progress.validate(result.snapshot)
	if not reason.is_empty():
		clear_menu("结局前存档无法恢复")
		paragraph(reason)
		button("返回", show_credits)
		return
	progress.restore(result.snapshot)
	run_started_ms = Time.get_ticks_msec()
	chapter_start_ms = run_started_ms
	chapter_times = {}
	last_chapter = ""
	checkpoint = result.snapshot.duplicate(true)
	running = true
	dirty = false
	load_room(Vector2(result.snapshot.safe_position[0],result.snapshot.safe_position[1]),result.snapshot.health,result.snapshot.focus)
	resume()
	notice = "已读取结局前的独立存档。"

func nearest_object() -> Dictionary:
	var candidates: Array = []
	for object in progress.node().objects:
		if object.kind == "guide_target": continue
		var pos := Vector2(object.pos[0],object.pos[1])
		var d: float = combat.player.distance_to(pos)
		if d > 30.0 or not combat.clear_wall_line(combat.player,pos): continue
		# A rest lamp must never steal E from an exit, chest, valve or story
		# object. It is the fallback interaction, not the closest-distance one.
		var priority := 1 if str(object.kind) == "rest" else 0
		candidates.append({"priority":priority,"distance":d,"object":object})
	if candidates.is_empty(): return {}
	candidates.sort_custom(func(a,b):
		if int(a.priority) != int(b.priority): return int(a.priority) < int(b.priority)
		return float(a.distance) < float(b.distance))
	return candidates[0].object

func rotate_guide(object: Dictionary) -> void:
	if progress.has("P02"):
		notice = "导光装置已经对齐，灯路保持连通。"
		return
	var current := int(guide_dirs.get(object.id,int(object.dir)))
	guide_dirs[object.id] = (current+1)%4
	dirty = true
	if guides_aligned():
		progress.flags.P02 = true
		notice = "三束光落在刻痕上，门内的灯线亮了。"
		if SaveStore.is_safe(safety()): save_game("auto",true)
	else:
		notice = "导光装置转向%s。已对准 %d / 3。" % [DIR_NAMES[(current+1)%4],guides_correct()]

func interact() -> void:
	if wake_left > 0: return
	if not SaveStore.is_safe(safety()):
		notice = "战斗中不能交互或存档。先清掉敌人、停下动作。"
		return
	var object := nearest_object()
	if object.is_empty():
		notice = "靠近发光的物件，按 E 交互。"
		return
	if str(object.kind) in ["exit","end"] and not bool(object_state(object,"").get("available",true)):
		if str(object.kind) == "end":
			notice = "门还没开：先击破前厅的守门者。" if str(object.get("requires","")) == "E08" else "门还没开：先把三座导光装置对准刻痕。"
		else:
			notice = "这条路还没打开。"
		return
	if object.has("requires") and not progress.requirement_met(str(object.requires),progress.flags):
		notice = "路还没开：先完成当前目标。"
		return
	match object.kind:
		"lamp":
			if progress.node_id == "N0-01" and not progress.has("S01"):
				notice = "灯座还有余温。先和床铺旁的伤员说话。"
			else:
				notice = "这盏灯已经点亮，不用再管。"
		"npc": begin_dialogue(str(object.get("dialogue","")))
		"chest","socket","pipe":
			notice = progress.apply_interaction(object.kind,scanned)
			dirty = true
			if object.kind == "socket" and progress.has("P01") and not progress.has("S02"): begin_dialogue("S02")
		"rong":
			if progress.has("pipe"): begin_dialogue("S03")
			else: notice = "绒指着水管：先按 Q 观察刻痕，再按 E 调查。"
		"reward": begin_dialogue("M1")
		"lore": begin_lore(str(object.get("dialogue","")))
		"guide": rotate_guide(object)
		"switch":
			notice = progress.set_switch(object)
			dirty = true
			start_encounters()
		"story":
			var event := str(object.get("event",""))
			if progress.has(event):
				notice = "这段已经记下了。"
			elif progress.start_event(event):
				progress.finish_event()
				dirty = true
				if not str(object.get("dialogue","")).is_empty(): begin_lore(str(object.get("dialogue","")))
				else: notice = "记下了。"
				start_encounters()
				if SaveStore.is_safe(safety()): save_game("auto",true)
			else:
				notice = "现在还记不了。先完成前面的调查。"
		"growth":
			show_growth_choice(str(object.get("event","M1")))
		"puzzle_choice":
			show_puzzle_choice(object)
		"evidence_slots":
			if progress.has("P08"):
				notice = "刻槽里已经嵌过这三份证据。"
			elif progress.evidence_count() < 3:
				notice = "还缺证据：断根切口、抽水记录、旧约残片。"
			else:
				progress.flags.P08 = true
				notice = "三份证据嵌入刻槽，旧约校准完成。"
				dirty = true
		"equipment":
			var eq_flag := str(object.get("flag",""))
			if progress.has(eq_flag):
				notice = "这里已经拿空了。"
			elif eq_flag.is_empty():
				notice = "箱子里没有装备。"
			else:
				progress.flags[eq_flag] = true
				progress.auto_equip()
				notice = "取得 "+str(object.get("name","装备"))+"。"
				dirty = true
				apply_growth()
		"sidequest":
			notice = progress.sidequest(str(object.get("quest","")),str(object.get("part","")))
			dirty = true
		"ending":
			show_ending_choice()
		"credits":
			show_credits()
		"rest":
			combat.hp = progress.max_hp()
			combat.focus = progress.max_focus()
			progress.potions = 3
			combat.potions = 3
			rest_ready = true
			var rest_bed: bool = str(object.get("visual","")) == "bed"
			save_game("auto",true)
			notice = "已休息：生命、精力和药剂补满，进度已保存。"
			if rest_bed and DisplayServer.get_name() != "headless": start_wake()
		"exit":
			progress.node_id = object.target
			load_room()
			dirty = true
			if SaveStore.is_safe(safety()): save_game("auto",true)
		"end":
			clear_menu("路线终点")
			paragraph("你已到达当前可玩路线的终点。\n可以返回探索，或保存当前进度。")
			button("返回探索",resume)
			button("保存当前进度",func(): save_game("auto",true))

func _unhandled_input(event: InputEvent) -> void:
	if intro != null and intro.visible:
		if intro.handle_input(event): get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F1:
			if settings_panel.visible:
				on_settings_closed()
			elif not dialogue.is_open():
				open_settings("pause" if running else "title")
			get_viewport().set_input_as_handled()
			return
		if settings_panel.visible and event.physical_keycode == KEY_ESCAPE:
			on_settings_closed()
			get_viewport().set_input_as_handled()
			return
	if settings_panel.visible: return
	if not running: return
	if dialogue.is_open() and dialogue.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if dialogue.is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if overlay.visible and progress.active_event.is_empty(): resume()
			elif not overlay.visible: show_pause()
			get_viewport().set_input_as_handled()
			return
	if paused or overlay.visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E: interact()
			KEY_Q:
				scanned = true
				scan_tick = combat.tick
				notice = "Q 观察：水位刻痕从高处一格格下降。" if progress.node_id == "N0-03" else "Q 观察：灯线沿地面延伸。靠近发光的调查点按 E。"
			KEY_SPACE: commands.append("dodge")
			KEY_1:
				if progress.skills().shield: commands.append("shield")
				else: notice = "护灯尚未解锁：先接通导光间的灯路。"
			KEY_2:
				if progress.skills().rain:
					queued_pointer = get_global_mouse_position()
					commands.append("rain")
				else: notice = "灯雨尚未解锁：先在控制台完成第三项强化。"
			KEY_R:
				if combat.potions == 0: notice = "药剂已用完，回安全灯座休息补满。"
				elif combat.hp >= progress.max_hp(): notice = "生命已满，不需要饮用药剂。"
				else: commands.append("heal")
	if event is InputEventMouseButton and event.pressed:
		queued_pointer = event.position
		if event.button_index == MOUSE_BUTTON_LEFT and pending_encounter != "tutorial": commands.append("melee")
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if progress.has("S02"): commands.append("light")
			else: notice = "净光尚未解锁。先去储藏间找备用灯芯。"

func free_overlapping_player() -> void:
	var radius := float(combat.config.player.body_radius)+float(combat.config.enemy_t1.body_radius)
	for enemy in combat.enemies:
		if enemy.hp <= 0: continue
		var offset: Vector2 = combat.player-enemy.pos
		if offset.length() >= radius-0.001: continue
		var direction := offset.normalized() if offset.length() > 0.001 else Vector2.RIGHT
		var candidate: Vector2 = enemy.pos+direction*radius
		if not combat.blocked(candidate,float(combat.config.player.body_radius)):
			combat.player = candidate

func retry_from_room() -> void:
	# Prefer the most recent submitted checkpoint when it is in the same room;
	# fall back to the room-entry snapshot so branch rooms never restart at the hub.
	var source: Dictionary = room_checkpoint
	if not checkpoint.is_empty():
		var same_room: bool = str(checkpoint.get("node_id","")) == progress.node_id
		var newer: bool = source.is_empty() or float(checkpoint.get("effective_seconds",0.0)) >= float(source.get("effective_seconds",0.0))
		if same_room and newer: source = checkpoint
	if not source.is_empty() and progress.restore(source):
		load_room(Vector2(source.safe_position[0],source.safe_position[1]),source.health,source.focus)
		resume()
		return
	if checkpoint.is_empty(): new_game()
	else:
		progress.restore(checkpoint)
		load_room(Vector2(checkpoint.safe_position[0],checkpoint.safe_position[1]),checkpoint.health,checkpoint.focus)
		resume()

func _process(_delta: float) -> void:
	# The simulation is fixed at 60 Hz; draw interpolated actor positions at the
	# display refresh rate. Without this, a 120/144 Hz monitor repeats or skips
	# 60 Hz movement steps and horizontal walking reads as a stutter.
	if not is_instance_valid(world) or not render_ready: return
	if running and not paused and not overlay.visible and (dialogue == null or not dialogue.is_open()):
		world.queue_redraw()
		floating_ui.queue_redraw()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(overlay): return
	if running and not paused:
		free_overlapping_player()
		render_prev_player = combat.player
		render_prev_enemies.clear()
		for enemy in combat.enemies:
			render_prev_enemies[enemy.id] = enemy.pos
		var movement := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		var pointer := world.to_local(queued_pointer if queued_pointer.is_finite() else get_global_mouse_position())
		var inside := Rect2(0,25,320,135).has_point(pointer)
		var valid: Array = commands.filter(func(c): return inside or c in ["dodge","heal","shield"])
		if wake_left > 0:
			wake_left -= 1
			movement = Vector2.ZERO
			valid = []
			pointer = combat.player
			if wake_left == 0:
				hide_player = false
				notice = "你从床铺上醒来。"
		var before: Vector2 = combat.player
		combat.step_commands(movement,pointer-combat.player,valid,inside and pending_encounter != "tutorial" and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
		if progress.lens_id == "clear_mirror" and combat.action == "shield" and combat.age == int(combat.config.actions.shield.windup):
			combat.poison_until = 0
		render_curr_player = combat.player
		render_curr_enemies.clear()
		for enemy in combat.enemies:
			render_curr_enemies[enemy.id] = enemy.pos
		combat_audio.consume(combat.events)
		feedback.consume(combat)
		handle_visual_events()
		update_screen_shake()
		progress.potions = combat.potions
		for event in combat.events:
			if event.kind == "heal": notice = "药剂生效，恢复 %d 点生命。" % event.amount
		player_moving = combat.player.distance_squared_to(before)>0.001
		progress.seconds += delta
		if player_moving or not combat.events.is_empty(): dirty = true
		if not pending_encounter.is_empty() and combat.enemies.all(func(e): return e.hp <= 0):
			var cleared := pending_encounter
			progress.flags[cleared] = true
			combat.clear_hazards()
			notice = str(progress.content.encounters[cleared].get("clear_notice","威胁已解除。继续前进，或回灯座休息存档。"))
			pending_encounter = ""
			start_encounters()
			# Clearing an encounter (including the elite/Boss) is a safe checkpoint;
			# if the room starts another encounter, safety() blocks the save.
			if SaveStore.is_safe(safety()): save_game("auto",true)
			# The mother gets one last line before the ending choice; this is
			# narrative only and does not gate damage or the choice itself.
			if cleared == "E30" and not progress.has("S10"):
				begin_dialogue("S10")
		if combat.hp <= 0:
			clear_menu("灯光暂熄")
			paragraph("回到最近一次安全存档。未保存的移动、战斗和奖励都会回退。\n也可以读取其他存档，或回到标题。")
			button("回到最近安全点",retry_from_room)
			button("读取存档",show_load_menu)
			button("返回标题",show_title)
	commands.clear()
	queued_pointer = Vector2.INF
	world.queue_redraw()
	floating_ui.queue_redraw()
	objects_layer.queue_redraw()
	ui_layer.queue_redraw()
	if hud_panel != null: hud_panel.queue_redraw()
	hud.text = "%s  /  %s\n%s" % [chapter_name(progress.node_id),progress.node().name,current_goal()]
	var nearest := nearest_object()
	var boss := boss_target()
	if not boss.is_empty():
		var core_text := ""
		if str(boss.get("archetype","")) == "BOSS":
			core_text = "  核心 " + ("暴露" if bool(boss.get("core_open",false)) else "收起")
		status.text = "目标：%s  生命 %d/%d  护壳 %d%s\n%s" % [boss_label(boss),int(boss.hp),int(boss.max_hp),int(boss.armor_layers),core_text,notice]
	else:
		status.text = ("E："+nearest.name if not nearest.is_empty() else "WASD移动  E交互  Q观察  R药剂  空格闪避")+"    "+notice
	if combat.action == "heal": status.text = "正在饮用药剂 %d / 36 · 移动、闪避或受击会取消\n%s" % [combat.age,notice]
	if wake_left > 0: status.text = "……\n睁开眼，从床铺上起身。"

func handle_visual_events() -> void:
	super.handle_visual_events()
	for event in combat.events:
		match str(event.get("kind","")):
			"boss_phase":
				start_screen_shake(6.0,12)
				notice = "母体外壳重组：第 %d 阶段。" % (int(event.get("phase",0))+1)
			"boss_core":
				if bool(event.get("open",false)):
					start_screen_shake(2.0,6)
					notice = "核心暴露：趁现在攻击。"
			"boss_death":
				start_screen_shake(8.0,18)
				notice = "母体被压制，核心仍在微弱搏动。"

func boss_target() -> Dictionary:
	for enemy in combat.enemies:
		if enemy.hp > 0 and str(enemy.get("archetype","")) in ["EL1","EL2","T6","BOSS"]:
			return enemy
	return {}

func boss_label(enemy: Dictionary) -> String:
	var names := {"EL1":"守门者","EL2":"泵站守卫","T6":"甲片守卫","BOSS":"母体"}
	return names.get(str(enemy.get("archetype","")),"精英")

func current_goal() -> String:
	match progress.node_id:
		"N0-01":
			if not progress.has("S01"): return "先和床铺旁的伤员说话。"
			return "沿灯线去右侧储藏间，取备用灯芯。"
		"N0-02":
			if not progress.has("core"): return "打开左上方的备用灯芯箱，按 E 取出灯芯。"
			if not progress.has("S02"): return "把备用灯芯装进出口灯座。"
			if not progress.has("tutorial"): return "右键施放净光，净化右上的教学孢囊。"
			if not progress.has("E01"): return "击退靠近灯座的菌人。按 R 饮用药剂，移动会取消。"
			if not progress.has("M1"): return "靠近下方的初燃灯环，按 E 选择第一项强化。"
			return "前往绒所在的水管隔间。"
		"N0-03":
			if not progress.has("pipe"): return "按 Q 观察水位刻痕，再按 E 调查水管。"
			if not progress.has("S03"): return "和绒说话，问清水为什么先退。"
			return "沿右门进入旧矿通道。"
		"N0-04":
			if progress.has("E02") and not progress.has("E03"): return "清掉旧矿门前的菌人和孢囊。"
			if not progress.has("E03"): return "沿两道灯线前进，清掉旧矿门前的威胁。"
			return "矿门已开，沿东门进入菌洞入口。"
		"N1-01":
			if not progress.has("E04"): return "借岩柱挡住投孢，清掉紫菌人和孢囊。"
			return "入口已清空，沿右门进入导光间。"
		"N1-02":
			if not progress.has("E05"): return "清掉导光间的菌人。"
			if not progress.has("E06"): return "击破两枚膨胀的孢囊，别让它们炸开。"
			if not progress.has("P02"): return "按 E 转动三座导光装置，对准刻痕（%d / 3）。" % guides_correct()
			return "灯路已接通，沿右门进入菌根前厅。"
		"N1-03":
			if not progress.has("E07"): return "先清掉冲锋菌人，守门者在门后。"
			if not progress.has("E08"): return "击破守门者的护壳，打开深处的门。"
			return "前厅已清空，沿东门进入菌根裂口。"
		"N1-04":
			if not progress.has("E09"): return "清掉裂口的菌人和投孢者。"
			if not progress.has("E10"): return "击破裂口深处的孢囊，别让它封住灯线。"
			return "裂口已安静，沿东侧灯线进入菌灯井。"
		"N1-05":
			if not progress.has("E11"): return "清掉祭坛的守坛者。"
			if not progress.has("M2"): return "在祭坛旁按 E 完成第二次强化。"
			return "沿东门前往根桥。"
		"N1-06":
			if not progress.has("S04"): return "先按 E 检查根桥上的斧痕，记下断根切口。"
			if not progress.has("P03"): return "按灯线顺序打开两个桥压阀。"
			return "根桥已接通，沿东门下到根桥下层。"
		"N1-07":
			if not progress.has("E31"): return "穿过旧支撑，清掉菌群。"
			return "旧支撑已清，沿北侧门进入分流室。"
		"N1-08":
			if not progress.has("E35"): return "绕过空井架，清掉裂口残余的菌群。"
			return "菌灯井已安静，沿北侧灯道去灯根祭坛。"
		"N2-01":
			if not progress.has("S05"): return "读分流图。两条支路都通向泵站。"
			return "先走排水支路或救援支路，另一条不会消失；两条都完成后才能合流。"
		"N2-02":
			if not progress.has("P04"): return "按顺序关闭两道排水阀。"
			return "排水完成，沿东门去排水出口。"
		"N2-03":
			if not progress.has("E15"): return "清掉旧灯旁的菌群。"
			if not progress.has("Q1b"): return "检查旧灯。修好三处旧灯可换澄明镜。"
			return "检查完毕，回分流室走另一条支路。"
		"N2-04":
			if not progress.has("P05"): return "从安全侧关闭两道污染根阀。"
			return "门已打开，沿东门进入安全旁室。"
		"N2-05":
			if not progress.has("E17"): return "先清掉旁室的菌群。"
			return "读砾的留条，再从东门回合流通道。"
		"N2-06":
			if not progress.has("S06"): return "按 E 记下合流标记。"
			return "沿东门前往泵站守卫。先清场，别让守卫毁了记录。"
		"N2-07":
			if not progress.has("E19"): return "击破泵站守卫。"
			return "守卫已倒下，沿东门去泵站回廊。"
		"N2-08":
			if not progress.has("S07"): return "读抽水记录，再看压力记录。"
			if not progress.has("P06"): return "按压力顺序校准两个稳压阀。"
			if not progress.has("M3") or not progress.has("E20"): return "清掉控制室菌群，在控制台完成第三项强化（解锁灯雨）。"
			return "控制室已稳定，沿东门去试验段外廊。"
		"N2-09":
			if not progress.has("E32"): return "沿回廊清掉守卫。"
			return "回廊已通，沿东门下到控制室。"
		"N2-10":
			if not progress.has("E34"): return "清掉试验段外廊的菌群。"
			return "外廊已清，沿北侧根门进入王庭外环。"
		"N3-01":
			if not progress.has("S08"): return "听菌王留声，取得旧约残片。"
			return "残片已够作证。沿东门去供给回廊；旧约墙上有全文。"
		"N3-02":
			if not progress.has("P07"): return "按顺序打开三段供给阀。"
			return "供给回廊已开，沿东门去旧约墙。"
		"N3-03":
			if not progress.has("E23"): return "清掉旧约墙旁的菌群。"
			return "旧约墙上有全文。读完可从墙后去王庭侧廊。"
		"N3-04":
			if not progress.has("E24") or not progress.has("E25"): return "清掉前厅的两段守卫。"
			return "前厅已清，沿东门进入王庭安全区。"
		"N3-05":
			if not progress.has("P08"): return "先听菌王留声，再用两个旧约阀完成校准。"
			if not progress.has("M4"): return "在安全区完成最后一次强化。"
			return "王庭已稳定，沿东门前往回流桥。"
		"N3-06":
			if not progress.has("E26"): return "清开回流桥上的菌群。"
			return "回流桥已通，沿北门前往调压前厅。"
		"N3-07":
			if not progress.has("E33"): return "从侧廊绕行，清掉根刺旁的守卫。"
			return "侧廊已通，沿北侧门进入王庭前厅。"
		"N3-08":
			if not progress.has("E36"): return "穿过王庭最后的根门，清掉调压前厅的守卫。"
			return "调压前厅已通，沿东门进入调压入口。"
		"N4-01":
			if not progress.has("E27"): return "清掉入口守卫。"
			return "打开第一道调压阀，进入调压中段。"
		"N4-02":
			if not progress.has("E28"): return "清掉中段菌群。"
			return "打开第二道调压阀，前往稳压台。"
		"N4-03":
			if not progress.has("P09"): return "打开第三道调压阀，接通核心外廊。"
			return "稳压完成，穿过核心外廊去最后灯座。"
		"N4-04":
			return "外廊空着，守卫都被母体召回了核心。前往最后灯座。"
		"N4-05":
			if not progress.has("S09"): return "检查装备、存档，再进核心室。"
			return "三份证据都在身上。进入核心室，面对母体。"
		"N4-06":
			if not progress.has("E30"): return "压制母体。"
			if progress.ending_id().is_empty(): return "母体已被压制。听完它最后的话，再靠近灯根核心做选择。"
			return "选择已写下，沿东门前往尾声。"
		"N4-07":
			return "按 E 查看结局统计与制作名单，或返回标题。"
	return progress.node().goal

func guide_color(object: Dictionary) -> Color:
	match str(object.get("color","amber")):
		"moss": return Color("9cbb87")
		"teal": return Color("7fc9c4")
	return Color("e4c675")

func object_state(object: Dictionary, nearest_id: String) -> Dictionary:
	var near: bool = nearest_id == str(object.id)
	var state := {"near":near, "available":true}
	match str(object.kind):
		"lamp": state.lit = progress.has("S01")
		"chest":
			state.open = progress.has("core")
			state.available = not progress.has("core")
		"socket":
			state.lit = progress.has("P01")
			state.available = progress.has("core")
		"pipe": state.scanned = scanned or progress.has("pipe")
		"reward":
			state.complete = progress.has("M1")
			state.available = progress.has("E01")
		"exit":
			state.available = progress.requirement_met(str(object.get("requires","")),progress.flags)
			state.open = state.available
		"end":
			state.available = progress.requirement_met(str(object.get("requires","")),progress.flags)
			state.open = state.available
		"guide":
			state.dir = int(guide_dirs.get(object.id,int(object.dir)))
			state.correct = guide_aligned(object)
			state.beam = false
		"guide_target": state.available = true
		"rest":
			if str(object.get("visual","bed")) == "lamp": state.lit = true
		"switch":
			state.lit = progress.has(str(object.get("flag","")))
			state.available = true
		"story":
			state.complete = progress.has(str(object.get("event","")))
			state.available = true
		"growth":
			state.complete = progress.has(str(object.get("event","")))
			state.available = true
			state.lit = state.complete
		"sidequest":
			state.complete = progress.has(str(object.get("quest","")) + str(object.get("part","")))
			state.available = true
			# Sidequest chests are drawn with the chest atlas. Without this
			# open flag they stayed closed forever even after being claimed.
			state.open = state.complete
		"equipment":
			state.complete = progress.has(str(object.get("flag","")))
			state.available = not state.complete
			state.open = state.complete
		"ending":
			state.available = progress.has("E30") and progress.ending_id().is_empty()
			state.complete = not progress.ending_id().is_empty()
			state.open = state.available
		"credits":
			state.available = true
			state.complete = progress.has("S11")
	return state

func draw_floor() -> void:
	var tick: int = combat.tick
	for object in progress.node().objects:
		if str(object.get("visual",object.kind)) != "bed": continue
		var pos := Vector2(object.pos[0],object.pos[1])
		props.draw_prop(world,"bed",pos,object_state(object,""),tick,preferences)
		props.draw_ambient(world,"dust",pos,tick,preferences)
	if wake_left <= 0: return
	var t := 1.0-float(wake_left)/float(wake_total)
	var foot := wake_from.lerp(wake_to,smoothstep(0.2,0.9,t))
	var angle := lerpf(PI/2,0.0,clampf((t-0.2)/0.45,0.0,1.0))
	art.sleep_pose(world,foot,angle,clampf(t/0.06,0.65,1.0))
	var phase := float(tick)/40.0
	for i in 3:
		var rise := fmod(phase+float(i)*0.33,1.0)
		var p := wake_from+Vector2(-6+i*6,-6-rise*14)
		world.draw_rect(Rect2(p.round(),Vector2.ONE),Color(1.0,0.9,0.6,(1.0-rise)*0.45))

func draw_objects() -> void:
	preload("res://scripts/enemy_warnings.gd").draw(objects_layer,combat)
	var tick: int = combat.tick
	var nearest: Dictionary = nearest_object()
	var nearest_id: String = str(nearest.get("id",""))
	for entry in progress.node().get("decor",[]):
		props.draw_furniture(objects_layer,str(entry.kind),Vector2(entry.pos[0],entry.pos[1]),tick,preferences)
	for object in progress.node().objects:
		var pos := Vector2(object.pos[0],object.pos[1])
		var state := object_state(object,nearest_id)
		var draw_kind: String = str(object.get("visual",object.kind))
		if draw_kind == "bed": continue
		if draw_kind == "rong":
			art.actor(objects_layer,pos,Vector2.LEFT,"idle",0,tick,false,false)
			props.draw_ambient(objects_layer,"spores",pos,tick,preferences)
			continue
		if draw_kind == "wounded":
			art.wounded_npc(objects_layer,pos,tick)
			props.draw_ambient(objects_layer,"light_pool",pos+Vector2(0,10),tick,preferences)
			continue
		var prop_tick: int = int(tick/3) if draw_kind in ["door","mine_door","exit","end"] else tick
		props.draw_prop(objects_layer,draw_kind,pos,state,prop_tick,preferences)
		match draw_kind:
			"lamp","socket":
				props.draw_ambient(objects_layer,"light_pool",pos+Vector2(0,12),tick,preferences)
				props.draw_ambient(objects_layer,"ember",pos,tick,preferences)
			"pipe":
				props.draw_ambient(objects_layer,"drip",pos+Vector2(15,9),tick,preferences)
			"chest","bed":
				props.draw_ambient(objects_layer,"dust",pos,tick,preferences)
			"reward":
				props.draw_ambient(objects_layer,"light_pool",pos,tick,preferences)
				props.draw_ambient(objects_layer,"ember",pos,tick,preferences)
			"exit":
				if bool(state.get("open",false)):
					props.draw_ambient(objects_layer,"light_pool",pos+Vector2(0,16),tick,preferences)
				else:
					draw_portal(pos,state,tick)
			"end":
				draw_portal(pos,state,tick)
				if bool(state.get("open",false)):
					props.draw_ambient(objects_layer,"light_pool",pos+Vector2(0,16),tick,preferences)
	for entry in progress.node().get("ambient",[]):
		props.draw_ambient(objects_layer,str(entry.kind),Vector2(entry.pos[0],entry.pos[1]),tick,preferences)
	draw_scan_highlights(tick)
	draw_guide_beams()

func draw_scan_highlights(tick: int) -> void:
	if not scanned or tick-scan_tick >= 60: return
	var fade := clampf(1.0-float(tick-scan_tick)/60.0,0.0,1.0)
	for object in progress.node().objects:
		if str(object.kind) not in ["story","sidequest","lore","equipment","puzzle_choice","evidence_slots","switch"]: continue
		var pos := Vector2(object.pos[0],object.pos[1])
		var color := Color(0.62,0.92,0.74,0.55*fade)
		objects_layer.draw_rect(Rect2(pos-Vector2(10,16),Vector2(20,20)),color,false,1.0)
		objects_layer.draw_line(pos-Vector2(10,16),pos-Vector2(4,16),Color(0.85,1.0,0.86,0.8*fade),1.5)

func draw_portal(pos: Vector2, state: Dictionary, tick: int) -> void:
	# Slow, readable threshold: sealed doors stay cold/dark, open doors breathe
	# warm light and slowly release motes. No fast flicker.
	var breath: float = 0.5+0.5*sin(TAU*float(tick)/180.0)
	if bool(state.get("open",false)):
		# The portal art itself carries the slow glow; only a soft threshold line
		# is added so the passable edge reads at a glance.
		objects_layer.draw_rect(Rect2(pos+Vector2(-7,-1),Vector2(14,2)),Color(1.0,0.9,0.55,0.25+0.15*breath))
	else:
		# Sealed: faint cold seam + small lock, so "not yet passable" is obvious.
		objects_layer.draw_rect(Rect2(pos+Vector2(-7,-1),Vector2(14,1)),Color(0.55,0.5,0.42,0.4))
		var lock: Vector2 = pos+Vector2(0,-30)
		objects_layer.draw_rect(Rect2(lock+Vector2(-2,-3),Vector2(5,7)),Color(0.12,0.11,0.09,0.95))
		objects_layer.draw_rect(Rect2(lock+Vector2(-1,-2),Vector2(3,4)),Color(0.82,0.66,0.32,0.95))

func draw_guide_beams() -> void:
	var tick: int = combat.tick
	for guide in progress.guides():
		var pos := Vector2(guide.pos[0],guide.pos[1])
		var dir := int(guide_dirs.get(guide.id,int(guide.dir)))
		var target := Vector2(guide.target[0],guide.target[1])
		var tint := guide_color(guide)
		var origin: Vector2 = pos+Vector2(0,-17)
		var axis: Vector2 = DIR_VECTORS[dir]
		var perpendicular := Vector2(axis.y,axis.x)
		if guide_aligned(guide):
			# Each aligned lamp now casts a slightly stronger, softly breathing
			# beam: a low alpha halo, a wider body, then a bright core and bead.
			var pulse: float = 0.0 if preferences.reduced_motion else 0.06*sin(float(tick)/28.0)
			objects_layer.draw_line(origin,target,Color(tint.r,tint.g,tint.b,0.11+pulse),9)
			objects_layer.draw_line(origin,target,Color(tint.r,tint.g,tint.b,0.38+pulse),4.5)
			objects_layer.draw_line(origin,target,Color(tint.r,tint.g,tint.b,0.92),2.5)
			objects_layer.draw_line(origin,target,tint.lightened(0.55),1.4)
			for i in 3:
				var phase := fmod(float(tick)/38.0+float(i)/3.0,1.0)
				var dot: Vector2 = origin.lerp(target,phase)
				objects_layer.draw_rect(Rect2(dot.round(),Vector2.ONE*(2 if i==1 else 1)),Color(1,0.98,0.86,0.9))
			if target.distance_to(origin) > 1:
				objects_layer.draw_circle(target,4.0,Color(tint.r,tint.g,tint.b,0.18))
				objects_layer.draw_rect(Rect2(target-Vector2(2,2),Vector2(5,5)),tint.lightened(0.4))
		else:
			# Always show the current facing so turning the device is readable.
			var tip: Vector2 = origin+axis*18
			var dim := Color(tint.r*0.85,tint.g*0.85,tint.b*0.85,0.9)
			# Directional hint without arrowheads; the guide device remains readable.
			objects_layer.draw_line(origin,tip,dim,1)
			objects_layer.draw_rect(Rect2(origin-Vector2(1,1),Vector2(3,3)),Color(dim.r,dim.g,dim.b,0.9))

func draw_object_labels() -> void:
	if not running or paused or overlay.visible or (dialogue != null and dialogue.is_open()): return
	var nearest := nearest_object()
	if nearest.is_empty(): return
	var label: String = str(nearest.name)
	if label.is_empty(): return
	var kind := str(nearest.kind)
	if kind == "guide":
		label += "（"+DIR_NAMES[int(guide_dirs.get(nearest.id,int(nearest.dir)))]+"）"
	elif kind == "end":
		label += "（可通过）" if bool(object_state(nearest,"").get("available",true)) else "（未开启）"
	elif kind == "exit" and not bool(object_state(nearest,"").get("available",true)):
		label += "（未开启）"
	elif kind == "switch":
		label += "（已开）" if progress.has(str(nearest.get("flag",""))) else "（未开）"
	elif kind == "story":
		label += "（已记录）" if progress.has(str(nearest.get("event",""))) else ""
	elif kind == "growth":
		label += "（已强化）" if progress.has(str(nearest.get("event",""))) else "（可强化）"
	elif kind == "sidequest":
		label += "（已记录）" if progress.has(str(nearest.get("quest","")) + str(nearest.get("part",""))) else ""
	elif kind == "ending":
		label += "（已选择）" if not progress.ending_id().is_empty() else ("" if progress.has("E30") else "（先压制母体）")
	var anchor: Vector2 = props.label_anchor(str(nearest.get("visual",kind)))
	if kind == "rong": anchor = Vector2(0,-22)
	if kind == "npc": anchor = Vector2(0,-24)
	var world_point := Vector2(nearest.pos[0],nearest.pos[1]) + anchor
	var at := world_point * 4.0
	var font := ThemeDB.fallback_font
	var width: float = font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x
	at.x = clampf(at.x-width/2,8,1272-width)
	# Keep names above the two-line bottom status bar and below the top HUD.
	at.y = clampf(at.y,136,640)
	ui_layer.draw_string_outline(font,at,label,HORIZONTAL_ALIGNMENT_LEFT,-1,24,4,Color(0.02,0.03,0.035,0.95))
	ui_layer.draw_string(font,at,label,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("f4dfab"))

func draw_minimap() -> void:
	if not running or overlay.visible: return
	var panel := Rect2(1118,16,142,92)
	ui_layer.draw_rect(panel,Color(0.025,0.04,0.04,0.88))
	ui_layer.draw_rect(panel,Color(0.55,0.48,0.28,0.9),false,1.5)
	var origin := Vector2(1124,34)
	var scale := 0.34
	var room := Rect2(origin,Vector2(320,180)*scale)
	ui_layer.draw_rect(room,Color(0.11,0.13,0.12,0.9))
	for wall in combat.walls:
		ui_layer.draw_rect(Rect2(origin+wall.position*scale,wall.size*scale),Color(0.40,0.32,0.22,0.95))
	for object in progress.node().objects:
		var kind := str(object.kind)
		if not [ "exit","end","npc","rong" ].has(kind): continue
		var p := origin+Vector2(object.pos[0],object.pos[1])*scale
		var color := Color("e3c878")
		if kind in ["exit","end"]:
			color = Color("7fc9c4") if bool(object_state(object,"").get("available",true)) else Color("665d4e")
		elif kind in ["npc","rong"]:
			color = Color("e8b7a0")
		ui_layer.draw_circle(p,2.2,color)
	for enemy in combat.enemies:
		if enemy.hp <= 0: continue
		ui_layer.draw_circle(origin+enemy.pos*scale,1.8,Color("d86a5a"))
	ui_layer.draw_circle(origin+combat.player*scale,2.6,Color("f5e4a8"))
	var font := ThemeDB.fallback_font
	ui_layer.draw_string(font,Vector2(1124,30),"当前区域",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("e3d2a2"))
