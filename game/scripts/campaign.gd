extends "res://scripts/graybox.gd"
## G3 gameplay adapter reuses the accepted combat/rendering components.
const Progress = preload("res://scripts/campaign_state.gd")
const SaveStore = preload("res://scripts/save_store.gd")
var progress = Progress.new()
var saves = SaveStore.new()
var overlay: PanelContainer
var menu: VBoxContainer
var notice := ""
var running := false
var scanned := false
var dialogue_index := 0
var pending_encounter := ""
var checkpoint: Dictionary = {}
var dirty := false
var tutorial_target := -1
var objects_layer: Node2D
var ui_layer: Node2D

func _ready() -> void:
	get_tree().auto_accept_quit = false
	combat = preload("res://scripts/campaign_combat.gd").new()
	show_rain_aim = false
	super._ready()
	if not OS.get_environment("FUNGUS_SAVE_DIR").is_empty(): saves.directory = OS.get_environment("FUNGUS_SAVE_DIR")
	objects_layer = Node2D.new()
	world.add_child(objects_layer)
	objects_layer.draw.connect(draw_objects)
	ui_layer = Node2D.new()
	add_child(ui_layer)
	ui_layer.draw.connect(draw_object_labels)
	overlay = PanelContainer.new()
	overlay.position = Vector2(270,140)
	overlay.size = Vector2(740,430)
	add_child(overlay)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation",10)
	overlay.add_child(menu)
	show_title()
	if "--campaign-capture" in OS.get_cmdline_user_args(): call_deferred("capture_preview")
	get_window().focus_exited.connect(func():
		if running and not overlay.visible: show_pause())

func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST or not is_instance_valid(overlay): return
	if not running:
		get_tree().quit()
		return
	clear_menu("退出游戏？")
	paragraph("未保存的移动、战斗与对话进度会回退到最近安全存档。当前演出不会提交半完成奖励。")
	button("确认退出",func(): get_tree().quit())
	button("返回当前进度",func():
		if progress.active_event.is_empty(): resume()
		else: show_dialogue())

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
	paused = true
	commands.clear()
	combat.clear_input_buffer()
	combat_audio.stop_all()
	for child in menu.get_children():
		menu.remove_child(child)
		child.queue_free()
	overlay.show()
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size",30)
	menu.add_child(heading)

func paragraph(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(700,65)
	label.add_theme_font_size_override("font_size",22)
	menu.add_child(label)

func button(text: String, action: Callable) -> void:
	var control := Button.new()
	control.text = text
	control.add_theme_font_size_override("font_size",22)
	control.pressed.connect(action)
	menu.add_child(control)

func resume() -> void:
	overlay.hide()
	paused = false
	commands.clear()
	queued_pointer = Vector2.INF

func show_title() -> void:
	running = false
	clear_menu("菌灯之下 · 序章")
	paragraph("守住最后一盏灯，沿水管寻找熄灭的原因。\nG3 开发切片：营地与旧矿通道，完整主线尚未完成。")
	button("新游戏",func():
		if FileAccess.file_exists(saves.directory+"/auto.json"):
			clear_menu("开始新旅程？")
			paragraph("新游戏会在安全点覆盖自动槽，三个手动槽不变。")
			button("确认新游戏",new_game)
			button("返回",show_title)
		else: new_game())
	button("继续（自动槽）",func(): load_game("auto"))
	button("读取存档",show_load_menu)
	button("退出",func(): get_tree().quit())

func new_game() -> void:
	progress = Progress.new()
	checkpoint = {}
	running = true
	load_room(Vector2.INF,100,100)
	resume()
	save_game("auto",true)

func load_room(position: Vector2 = Vector2.INF, health: float = -1, focus_value: float = -1) -> void:
	var prior_hp: float = combat.hp
	var prior_focus: float = combat.focus
	combat.reset()
	combat.healing_enabled = true
	combat.potions = progress.potions
	combat.enemies.clear()
	combat.walls = combat.DEFAULT_WALLS.slice(0,4)
	for wall in progress.node().walls: combat.walls.append(Rect2(wall[0],wall[1],wall[2],wall[3]))
	combat.doors.clear()
	combat.doors.append({"id":"unused","rect":Rect2(0,0,1,1),"open":true})
	var spawn: Array = progress.node().spawn
	combat.player = Vector2(spawn[0],spawn[1]) if not position.is_finite() else position
	combat.hp = clampf(prior_hp if health < 0 else health,1,progress.max_hp())
	combat.focus = clampf(prior_focus if focus_value < 0 else focus_value,0,100)
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
	start_encounters()

func apply_growth() -> void:
	combat.config.player.hp = progress.max_hp()
	combat.config.actions.melee.damage = 21 if progress.choice == "melee" else 18
	combat.config.actions.light.damage = 28 if progress.choice == "light" else 24
	combat.hp = minf(combat.hp,progress.max_hp())

func start_encounters() -> void:
	if not pending_encounter.is_empty(): return
	if progress.node_id == "N0-02" and progress.has("S02"):
		if not progress.has("tutorial"):
			var target: Dictionary = combat.add_enemy(Vector2(230,70),true)
			target.hp = 24
			tutorial_target = int(target.id)
			pending_encounter = "tutorial"
		elif not progress.has("E01"):
			combat.add_enemy(Vector2(245,96))
			pending_encounter = "E01"
	if progress.node_id == "N0-04":
		if not progress.has("E02"):
			combat.add_enemy(Vector2(155,90))
			combat.add_enemy(Vector2(162,130))
			pending_encounter = "E02"
		elif not progress.has("E03"):
			combat.add_enemy(Vector2(255,90))
			combat.add_archetype("T5",Vector2(250,132))
			pending_encounter = "E03"

func safety() -> Dictionary:
	var alerted := false
	for enemy in combat.enemies:
		if enemy.hp > 0 and not enemy.dummy: alerted = true
	return {"no_alert_enemies":not alerted,"no_hazards":combat.projectiles.is_empty() and combat.zones.is_empty() and combat.rains.is_empty() and combat.poison_until <= combat.tick,"player_idle":combat.action == "idle" and combat.hp > 0,
		"no_blocking_event":progress.active_event.is_empty(),"walkable_position":not combat.blocked(combat.player),"no_elite_battle":true}

func save_game(slot: String, confirmed: bool = false) -> void:
	var snapshot: Dictionary = progress.snapshot(combat.player,combat.hp,combat.focus)
	var error: String = progress.validate(snapshot)
	if not error.is_empty():
		notice = error
		return
	var result: Dictionary = saves.save_slot(slot,snapshot,safety(),confirmed)
	notice = result.message
	if result.ok:
		checkpoint = snapshot.duplicate(true)
		dirty = false
	elif result.code == "confirmation_required":
		clear_menu("覆盖存档？")
		paragraph("将当前安全进度写入 "+slot+"。原有效存档会保留为备份。")
		button("确认覆盖",func(): save_game(slot,true); show_pause())
		button("取消",show_pause)

func load_game(slot: String, backup: bool = false) -> void:
	var result: Dictionary = saves.load_slot(slot,backup)
	if not result.ok:
		clear_menu("无法读取存档")
		paragraph(result.message)
		if result.get("backup_available",false): button("恢复上一次有效备份",func(): load_game(slot,true))
		button("返回",show_load_menu)
		return
	var reason: String = progress.validate(result.snapshot)
	if not reason.is_empty():
		clear_menu("存档内容无法恢复")
		paragraph(reason)
		if not backup and saves.load_slot(slot,true).ok: button("恢复备份",func(): load_game(slot,true))
		button("返回",show_load_menu)
		return
	progress.restore(result.snapshot)
	checkpoint = result.snapshot.duplicate(true)
	running = true
	dirty = false
	load_room(Vector2(result.snapshot.safe_position[0],result.snapshot.safe_position[1]),result.snapshot.health,result.snapshot.focus)
	resume()
	notice = "已读取"+("备份，部分进度可能回退。" if backup else "存档。")

func show_load_menu() -> void:
	clear_menu("读取安全进度")
	for slot in SaveStore.SLOTS:
		button(str(slot),func(): load_game(slot))
	button("返回",func():
		if running: show_pause()
		else: show_title())

func show_pause() -> void:
	clear_menu("暂停 · "+progress.node().name)
	paragraph(("有未保存进度。\n" if dirty else "")+notice+"\nWASD移动 · 左键灯击 · 右键净光 · 空格闪避 · Q观察 · E交互")
	button("继续",resume)
	for slot in ["manual_1","manual_2","manual_3"]:
		button("保存到 "+slot,func():
			save_game(slot)
			if menu.get_child(0).text != "覆盖存档？": show_pause())
	button("读取存档",show_load_menu)
	button("返回标题",func():
		clear_menu("离开当前进度？")
		paragraph("未保存进度将回退到最近存档。")
		button("确认返回标题",show_title)
		button("取消",show_pause))

func begin_dialogue(id: String) -> void:
	if not progress.start_event(id): return
	dialogue_index = 0
	show_dialogue()

func show_dialogue() -> void:
	var id: String = progress.active_event
	var lines: Array = progress.content.dialogues[id]
	dialogue_index = clampi(dialogue_index,0,lines.size()-1)
	clear_menu(str(lines[dialogue_index][0]))
	paragraph(str(lines[dialogue_index][1]))
	button("下一句" if dialogue_index < lines.size()-1 else "继续",advance_dialogue)
	button("跳过本段对白",finish_dialogue)

func advance_dialogue() -> void:
	dialogue_index += 1
	if dialogue_index >= progress.content.dialogues[progress.active_event].size(): finish_dialogue()
	else: show_dialogue()

func finish_dialogue() -> void:
	if progress.active_event == "M1":
		clear_menu("初燃 · 选择一项强化")
		paragraph("基础生命提升与守灯结共同提交。伤害按统一四舍五入：灯击18→21，或净光24→28。")
		button("灯击伤害 +15%",func(): choose_growth("melee"))
		button("净光伤害 +15%",func(): choose_growth("light"))
		return
	progress.finish_event()
	dirty = true
	start_encounters()
	resume()
	if SaveStore.is_safe(safety()): save_game("auto",true)

func choose_growth(option: String) -> void:
	if not progress.finish_event(option): return
	apply_growth()
	dirty = true
	resume()
	save_game("auto",true)

func nearest_object() -> Dictionary:
	var nearest: Dictionary = {}
	var distance := 24.01
	for object in progress.node().objects:
		var pos := Vector2(object.pos[0],object.pos[1])
		var d: float = combat.player.distance_to(pos)
		if d <= 24 and d < distance and combat.clear_line(combat.player,pos):
			distance = d
			nearest = object
	return nearest

func interact() -> void:
	if not SaveStore.is_safe(safety()):
		notice = "先避开威胁并结束动作，再交互或存档。"
		return
	var object := nearest_object()
	if object.is_empty():
		notice = "靠近有标记的物件（24像素内），按 E。"
		return
	if object.has("requires") and not progress.has(object.requires):
		notice = "通路未开：先完成当前目标。"
		return
	match object.kind:
		"lamp": begin_dialogue("S01")
		"chest","socket","pipe":
			notice = progress.apply_interaction(object.kind,scanned)
			dirty = true
			if object.kind == "socket" and progress.has("P01") and not progress.has("S02"): begin_dialogue("S02")
		"rong":
			if progress.has("pipe"): begin_dialogue("S03")
			else: notice = "绒望着水管：先看看那些刻痕。按 Q 观察，再靠近调查。"
		"reward": begin_dialogue("M1")
		"rest":
			combat.hp = progress.max_hp()
			combat.focus = 100
			progress.potions = 3
			combat.potions = 3
			save_game("auto",true)
			notice = "已休息。"+notice
		"exit":
			progress.node_id = object.target
			load_room()
			dirty = true
			if SaveStore.is_safe(safety()): save_game("auto",true)
		"end":
			clear_menu("旧矿门重新见光")
			paragraph("你已抵达当前开发切片边界。绒的线索指向更深处的菌根。\n后续矿道、完整敌人及十至十五分钟切片仍在制作，本页不是游戏结局。")
			button("返回探索",resume)
			button("保存当前进度",func(): save_game("auto",true))

func _unhandled_input(event: InputEvent) -> void:
	if not running: return
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
				notice = "回声：水管上的刻痕从高处逐格下降。" if progress.node_id == "N0-03" else "灯光沿着地面延伸；寻找带名字的物件。"
			KEY_SPACE: commands.append("dodge")
			KEY_R:
				if combat.potions == 0: notice = "药剂已用完，回安全灯座休息补满。"
				elif combat.hp >= progress.max_hp(): notice = "生命已满。"
				else: commands.append("heal")
	if event is InputEventMouseButton and event.pressed:
		queued_pointer = event.position
		if event.button_index == MOUSE_BUTTON_LEFT and pending_encounter != "tutorial": commands.append("melee")
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if progress.has("S02"): commands.append("light")
			else: notice = "净光尚未解锁。先找备用灯芯。"

func _physics_process(delta: float) -> void:
	if not is_instance_valid(overlay): return
	if running and not paused:
		var movement := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		var pointer := world.to_local(queued_pointer if queued_pointer.is_finite() else get_global_mouse_position())
		var inside := Rect2(0,25,320,135).has_point(pointer)
		var valid: Array = commands.filter(func(c): return inside or c in ["dodge","heal"])
		var before: Vector2 = combat.player
		combat.step_commands(movement,pointer-combat.player,valid,inside and pending_encounter != "tutorial" and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
		combat_audio.consume(combat.events)
		feedback.consume(combat)
		progress.potions = combat.potions
		for event in combat.events:
			if event.kind == "heal": notice = "治疗完成，恢复%d生命。" % event.amount
		player_moving = combat.player.distance_squared_to(before)>0.001
		progress.seconds += delta
		if player_moving or not combat.events.is_empty(): dirty = true
		if not pending_encounter.is_empty() and combat.enemies.all(func(e): return e.hp <= 0):
			progress.flags[pending_encounter] = true
			notice = "教学完成，通道里有菌人靠近。" if pending_encounter == "tutorial" else "威胁解除。靠近灯环或继续探索。"
			pending_encounter = ""
			start_encounters()
		if combat.hp <= 0:
			clear_menu("灯光暂熄")
			paragraph("恢复最近已提交的安全进度，未保存的奖励、敌人和资源一起回退。")
			button("从安全点重试",func():
				if checkpoint.is_empty(): new_game()
				else:
					progress.restore(checkpoint)
					load_room(Vector2(checkpoint.safe_position[0],checkpoint.safe_position[1]),checkpoint.health,checkpoint.focus)
					resume())
	commands.clear()
	queued_pointer = Vector2.INF
	world.queue_redraw()
	floating_ui.queue_redraw()
	objects_layer.queue_redraw()
	ui_layer.queue_redraw()
	hud.text = "%s   生命 %d / %d   专注 %d / 100   药剂 %d/3   净光 %s\n%s" % [progress.node().name,combat.hp,progress.max_hp(),combat.focus,combat.potions,"已解锁" if progress.has("S02") else "未解锁",current_goal()]
	var nearest := nearest_object()
	status.text = ("E："+nearest.name if not nearest.is_empty() else "WASD移动 · 空格闪避 · E交互 · Q观察 · R治疗 · Esc暂停")+"\n"+notice
	if combat.action == "heal": status.text = "正在治疗 %d / 36 · 移动、闪避或受击会取消\n%s" % [combat.age,notice]

func current_goal() -> String:
	match progress.node_id:
		"N0-01": return "沿灯线前往右侧储藏间。" if progress.has("S01") else progress.node().goal
		"N0-02":
			if not progress.has("core"): return "靠近左上备用灯芯箱，按 E 取出灯芯。"
			if not progress.has("S02"): return "靠近出口灯座，按 E 装入灯芯。"
			if not progress.has("tutorial"): return "右键净光，净化右上教学靶；它不会攻击。"
			if not progress.has("E01"): return "击退靠近灯座的菌人；R治疗，移动可取消。"
			if not progress.has("M1"): return "靠近下方初燃灯环，按 E 选择强化。"
			return "已取得初燃与守灯结，右侧门通往绒的隔间。"
		"N0-03":
			if not progress.has("pipe"): return progress.node().goal
			if not progress.has("S03"): return "已记录水位刻痕，靠近绒按 E 交谈。"
			return "绒留在灯旁。沿右门独自进入旧矿通道。"
		"N0-04": return "旧矿门前威胁已清除，靠近门按 E。" if progress.has("E03") else progress.node().goal
	return progress.node().goal

func draw_objects() -> void:
	preload("res://scripts/enemy_warnings.gd").draw(objects_layer,combat)
	for object in progress.node().objects:
		var pos := Vector2(object.pos[0],object.pos[1])
		var color := Color("e4c675")
		if object.has("requires") and not progress.has(object.requires): color = Color("8c7c77")
		match object.kind:
			"rong": art.actor(objects_layer,pos,Vector2.LEFT,"idle",0,combat.tick,false,false)
			"chest":
				objects_layer.draw_rect(Rect2(pos-Vector2(8,9),Vector2(16,12)),Color("6a452b"))
				objects_layer.draw_rect(Rect2(pos-Vector2(8,9),Vector2(16,12)),color,false,1)
				objects_layer.draw_line(pos-Vector2(8,4),pos+Vector2(8,-4),color,1)
				objects_layer.draw_rect(Rect2(pos-Vector2(1,5),Vector2(2,4)),Color("ffe4a2"))
			"pipe":
				objects_layer.draw_rect(Rect2(pos-Vector2(16,6),Vector2(32,9)),Color("5d7071"))
				for i in 4: objects_layer.draw_line(pos+Vector2(-10+i*6,-6),pos+Vector2(-10+i*6,-2),color,1)
			"exit","end":
				objects_layer.draw_rect(Rect2(pos-Vector2(7,23),Vector2(14,26)),Color("242a25"))
				objects_layer.draw_rect(Rect2(pos-Vector2(7,23),Vector2(14,26)),color,false,2)
				if color == Color("8c7c77"):
					for i in 3: objects_layer.draw_line(pos+Vector2(-6,-18+i*7),pos+Vector2(6,-18+i*7),color,1)
			_:
				objects_layer.draw_rect(Rect2(pos-Vector2(6,3),Vector2(12,5)),Color("6d6250"))
				objects_layer.draw_line(pos,pos-Vector2(0,17),Color("998066"),3)
				objects_layer.draw_rect(Rect2(pos-Vector2(5,22),Vector2(10,9)),Color("473b30"))
				objects_layer.draw_rect(Rect2(pos-Vector2(3,20),Vector2(6,5)),color)
				if object.kind != "lamp" or progress.has("S01"):
					objects_layer.draw_circle(pos-Vector2(0,17),10,Color(0.9,0.7,0.4,0.08))
		if nearest_object().get("id","") == object.id: objects_layer.draw_arc(pos,10,0,TAU,16,Color("e4c675"),0.6)

func draw_object_labels() -> void:
	var font := ThemeDB.fallback_font
	for object in progress.node().objects:
		var pos := Vector2(object.pos[0],object.pos[1])*4
		var label: String = object.name
		var width: float = font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
		pos.x = clampf(pos.x-width/2,8,1272-width)
		ui_layer.draw_rect(Rect2(pos+Vector2(-4,32),Vector2(width+8,24)),Color(0.035,0.045,0.04,0.85))
		ui_layer.draw_string(font,pos+Vector2(0,50),label,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("f4dfab"))
