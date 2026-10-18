extends "res://scripts/graybox.gd"
## G3 gameplay adapter reuses the accepted combat/rendering components.
const Progress = preload("res://scripts/campaign_state.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const DIR_NAMES := ["上","右","下","左"]
const DIR_VECTORS := [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]
var progress = Progress.new()
var saves = SaveStore.new()
var overlay: PanelContainer
var menu: VBoxContainer
var notice := ""
var running := false
var scanned := false
var dialogue_index := 0
var dialogue_mode := ""
var dialogue_lines: Array = []
var choice_pending := false
var choice_mode := "growth"
var run_started_ms := 0
var pending_encounter := ""
var checkpoint: Dictionary = {}
var dirty := false
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
	dialogue = preload("res://scripts/dialogue_box.gd").new()
	add_child(dialogue)
	dialogue.advance_requested.connect(advance_dialogue)
	dialogue.skip_requested.connect(finish_dialogue)
	dialogue.choice_selected.connect(choose_choice)
	show_title()
	if "--campaign-capture" in OS.get_cmdline_user_args(): call_deferred("capture_preview")
	get_window().focus_exited.connect(func():
		if running and not overlay.visible and not dialogue.is_open(): show_pause())

func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST or not is_instance_valid(overlay): return
	if not running:
		get_tree().quit()
		return
	clear_menu("退出游戏？")
	paragraph("未保存的移动、战斗与对话进度会回退到最近安全存档。当前演出不会提交半完成奖励。")
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
	heading.add_theme_font_size_override("font_size",36)
	menu.add_child(heading)

func paragraph(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(700,65)
	label.add_theme_font_size_override("font_size",24)
	menu.add_child(label)

func button(text: String, action: Callable) -> void:
	var control := Button.new()
	control.text = text
	control.add_theme_font_size_override("font_size",24)
	control.pressed.connect(action)
	menu.add_child(control)

func resume() -> void:
	overlay.hide()
	if dialogue != null and dialogue.is_open(): dialogue.close()
	if status != null: status.visible = true
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
	run_started_ms = Time.get_ticks_msec()
	progress = Progress.new()
	checkpoint = {}
	running = true
	load_room(Vector2.INF,100,100)
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
	setup_collision()
	var spawn: Array = progress.node().spawn
	combat.player = Vector2(spawn[0],spawn[1]) if not position.is_finite() else position
	combat.hp = clampf(prior_hp if health < 0 else health,1,progress.max_hp())
	combat.focus = clampf(prior_focus if focus_value < 0 else focus_value,0,100)
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
	reset_guides()
	start_encounters()

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
		if rect.size.x > 0: combat.blockers.append(rect)
		if str(object.kind) == "rong" or bool(object.get("npc",false)):
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
	combat.config.actions.melee.damage = progress.melee_damage()
	combat.config.actions.light.damage = progress.light_damage()
	combat.hp = minf(combat.hp,progress.max_hp())
	combat.focus = minf(combat.focus,progress.max_focus())

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
	run_started_ms = Time.get_ticks_msec()
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
	if wake_left > 0: return
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
		notice = "这里还不能进行强化。"
		return
	choice_mode = "growth"
	choice_pending = true
	paused = true
	overlay.hide()
	if status != null: status.visible = false
	var def := progress.event_def(event_id)
	dialogue.show_choices(str(def.get("title", "选择一项强化")), def.get("options", []))

func choose_choice(option: String) -> void:
	if choice_mode == "ending":
		choose_ending(option)
	else:
		choose_growth(option)

func choose_growth(option: String) -> void:
	if choice_mode != "growth" or not progress.finish_event(option): return
	dialogue_mode = ""
	dialogue_lines = []
	choice_pending = false
	choice_mode = "growth"
	dialogue.close()
	apply_growth()
	combat.hp = progress.max_hp()
	combat.focus = progress.max_focus()
	dirty = true
	resume()
	save_game("auto",true)

func show_ending_choice() -> void:
	if not progress.has("E30"):
		notice = "母体还没有被压制。"
		return
	if not progress.ending_id().is_empty():
		notice = "灯根的选择已经写下了。"
		return
	choice_mode = "ending"
	choice_pending = true
	paused = true
	overlay.hide()
	if status != null: status.visible = false
	dialogue.show_choices("灯根核心 · 最后的选择", [
		{"id": "restore", "label": "恢复共生循环", "desc": "让灯与水重新流动"},
		{"id": "seal", "label": "封存并撤离", "desc": "把灯根留在黑暗里"}])

func choose_ending(option: String) -> void:
	if choice_mode != "ending" or option not in ["restore","seal"]: return
	progress.set_ending(option)
	choice_pending = false
	choice_mode = "growth"
	dialogue.close()
	notice = "灯根选择了" + ("共生。" if option == "restore" else "封存。")
	dirty = true
	apply_growth()
	resume()
	save_game("auto",true)

func elapsed_text() -> String:
	var seconds := int((Time.get_ticks_msec()-run_started_ms)/1000) if run_started_ms > 0 else int(progress.seconds)
	return "%02d:%02d" % [int(seconds/60), seconds%60]

func show_credits() -> void:
	if not progress.has("S12"): progress.flags.S12 = true
	dirty = true
	var restored := progress.ending_id() == "restore"
	clear_menu("菌灯之下 · 尾声")
	paragraph(("灯与水重新流动，菌根在暖光里安静下来。\n" if restored else "你把灯根封存，带着最后一点光撤离。\n") + "本次用时 " + elapsed_text() + "。\n按 Esc 返回标题，或继续探索。")
	button("返回标题", show_title)
	button("继续探索", resume)

func nearest_object() -> Dictionary:
	var nearest: Dictionary = {}
	var distance := 30.01
	for object in progress.node().objects:
		if object.kind == "guide_target": continue
		var pos := Vector2(object.pos[0],object.pos[1])
		var d: float = combat.player.distance_to(pos)
		if d <= 30 and d < distance and combat.clear_wall_line(combat.player,pos):
			distance = d
			nearest = object
	return nearest

func rotate_guide(object: Dictionary) -> void:
	if progress.has("P02"):
		notice = "导光装置已对齐，灯路保持连通。"
		return
	var current := int(guide_dirs.get(object.id,int(object.dir)))
	guide_dirs[object.id] = (current+1)%4
	dirty = true
	if guides_aligned():
		progress.flags.P02 = true
		notice = "三束光同时落在刻痕上，门内灯线复亮。"
		if SaveStore.is_safe(safety()): save_game("auto",true)
	else:
		notice = "导光装置转向%s。已对准 %d / 3。" % [DIR_NAMES[(current+1)%4],guides_correct()]

func interact() -> void:
	if wake_left > 0: return
	if not SaveStore.is_safe(safety()):
		notice = "先避开威胁并结束动作，再交互或存档。"
		return
	var object := nearest_object()
	if object.is_empty():
		notice = "靠近有标记的物件（30像素内），按 E。"
		return
	if str(object.kind) in ["exit","end"] and not bool(object_state(object,"").get("available",true)):
		if str(object.kind) == "end":
			notice = "门内灯影未定：先击破前厅的守门者。" if str(object.get("requires","")) == "E08" else "门内灯线尚未接通：先把三座导光装置对准刻痕。"
		else:
			notice = "这条通路还没有打开。"
		return
	if object.has("requires") and not progress.requirement_met(str(object.requires),progress.flags):
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
		"lore": begin_lore(str(object.get("dialogue","")))
		"guide": rotate_guide(object)
		"switch":
			notice = progress.set_switch(object)
			dirty = true
			start_encounters()
		"story":
			var event := str(object.get("event",""))
			if progress.has(event):
				notice = "这里已经记录过了。"
			elif progress.start_event(event):
				progress.finish_event()
				dirty = true
				if not str(object.get("dialogue","")).is_empty(): begin_lore(str(object.get("dialogue","")))
				else: notice = "记录完成。"
				start_encounters()
				if SaveStore.is_safe(safety()): save_game("auto",true)
			else:
				notice = "现在还不能记录。"
		"growth":
			show_growth_choice(str(object.get("event","M1")))
		"sidequest":
			notice = progress.sidequest(str(object.get("quest","")),str(object.get("part","")))
			dirty = true
		"ending":
			show_ending_choice()
		"credits":
			show_credits()
		"rest":
			combat.hp = progress.max_hp()
			combat.focus = 100
			progress.potions = 3
			combat.potions = 3
			var rest_bed: bool = str(object.get("visual","")) == "bed"
			save_game("auto",true)
			notice = "已休息并保存。"
			if rest_bed and DisplayServer.get_name() != "headless": start_wake()
		"exit":
			progress.node_id = object.target
			load_room()
			dirty = true
			if SaveStore.is_safe(safety()): save_game("auto",true)
		"end":
			clear_menu("菌根深处")
			paragraph("你已抵达当前开发切片边界：营地—旧矿通道—菌洞入口—导光间。\n更深的菌根、完整章节和十至十五分钟路线仍在制作，本页不是游戏结局。")
			button("返回探索",resume)
			button("保存当前进度",func(): save_game("auto",true))

func _unhandled_input(event: InputEvent) -> void:
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
				notice = "回声：水管上的刻痕从高处逐格下降。" if progress.node_id == "N0-03" else "灯光沿着地面延伸；寻找带名字的物件。"
			KEY_SPACE: commands.append("dodge")
			KEY_1:
				if progress.skills().shield: commands.append("shield")
				else: notice = "护灯尚未解锁。"
			KEY_2:
				if progress.skills().rain:
					queued_pointer = get_global_mouse_position()
					commands.append("rain")
				else: notice = "灯雨尚未解锁。"
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

func _physics_process(delta: float) -> void:
	if not is_instance_valid(overlay): return
	if running and not paused:
		free_overlapping_player()
		var movement := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		var pointer := world.to_local(queued_pointer if queued_pointer.is_finite() else get_global_mouse_position())
		var inside := Rect2(0,25,320,135).has_point(pointer)
		var valid: Array = commands.filter(func(c): return inside or c in ["dodge","heal"])
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
		combat_audio.consume(combat.events)
		feedback.consume(combat)
		progress.potions = combat.potions
		for event in combat.events:
			if event.kind == "heal": notice = "治疗完成，恢复%d生命。" % event.amount
		player_moving = combat.player.distance_squared_to(before)>0.001
		progress.seconds += delta
		if player_moving or not combat.events.is_empty(): dirty = true
		if not pending_encounter.is_empty() and combat.enemies.all(func(e): return e.hp <= 0):
			var cleared := pending_encounter
			progress.flags[cleared] = true
			combat.clear_hazards()
			notice = str(progress.content.encounters[cleared].get("clear_notice","威胁解除。靠近灯环或继续探索。"))
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
	hud.text = "%s   生命 %d / %d   专注 %d / 100   药剂 %d/3   净光 %s   时间 %s\n%s" % [progress.node().name,combat.hp,progress.max_hp(),combat.focus,combat.potions,"已解锁" if progress.has("S02") else "未解锁",elapsed_text(),current_goal()]
	var nearest := nearest_object()
	status.text = ("E："+nearest.name if not nearest.is_empty() else "WASD移动 · 空格闪避 · E交互 · Q观察 · R治疗 · Esc暂停")+"\n"+notice
	if combat.action == "heal": status.text = "正在治疗 %d / 36 · 移动、闪避或受击会取消\n%s" % [combat.age,notice]
	if wake_left > 0: status.text = "……\n睁开眼，从床铺上起身。"

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
		"N0-04":
			if progress.has("E02") and not progress.has("E03"): return "旧矿门前的双灯试炼：清理最后的菌人与孢囊。"
			if not progress.has("E03"): return progress.node().goal
			return "旧矿门已开，向东进入菌洞入口。"
		"N1-01":
			if not progress.has("E04"): return progress.node().goal
			return "菌洞入口已清空，沿右门进入导光间。"
		"N1-02":
			if not progress.has("E05"): return "清理盘踞在导光间的菌人。"
			if not progress.has("E06"): return "击破两枚膨胀的孢囊，别等它们炸开。"
			if not progress.has("P02"): return "转动三座导光装置（E 转向），已对准 %d / 3。" % guides_correct()
			return "灯路已连通。进入菌根前厅。"
		"N1-03":
			if not progress.has("E07"): return "清理前厅的菌人与冲锋菌人。"
			if not progress.has("E08"): return "守门者已现身；击破它的护壳后再开门。"
			return "前厅已清空。进入菌根裂口。"
		"N1-04":
			if not progress.has("E09"): return "清理裂口的菌人与投孢者。"
			if not progress.has("E10"): return "击破裂口深处的孢囊，别让它封住灯线。"
			return "裂口已安静。沿东侧灯线进入灯根祭坛。"
		"N1-05":
			if not progress.has("E11"): return "清理祭坛的守坛者，别让灯根再次熄灭。"
			if not progress.has("M2"): return "灯根已清。在祭坛旁选择一次强化。"
			return "灯根已清。前往根桥。"
		"N4-06":
			if not progress.has("E30"): return "压制母体。"
			if progress.ending_id().is_empty(): return "母体已被压制。靠近灯根核心做出选择。"
			return "灯根的选择已经写下。前往尾声。"
		"N4-07":
			return "回看这段路，或返回标题。"
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
	draw_guide_beams()

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
			objects_layer.draw_line(origin,target,tint,3)
			objects_layer.draw_line(origin,target,tint.lightened(0.45),1)
			for i in 2:
				var phase := fmod(float(tick)/40.0+float(i)*0.5,1.0)
				var dot: Vector2 = origin.lerp(target,phase)
				objects_layer.draw_rect(Rect2(dot.round(),Vector2.ONE),Color(1,0.96,0.8,0.85))
			if target.distance_to(origin) > 1:
				objects_layer.draw_rect(Rect2(target-Vector2(2,2),Vector2(5,5)),tint.lightened(0.3))
		else:
			# Always show the current facing so turning the device is readable.
			var tip: Vector2 = origin+axis*22
			var dim := Color(tint.r*0.85,tint.g*0.85,tint.b*0.85,0.9)
			objects_layer.draw_line(origin,tip,dim,2)
			objects_layer.draw_line(tip,tip-axis*5+perpendicular*3,dim,2)
			objects_layer.draw_line(tip,tip-axis*5-perpendicular*3,dim,2)
			objects_layer.draw_rect(Rect2(tip-Vector2(1,1),Vector2(3,3)),Color(1,0.94,0.8,0.9))

func draw_object_labels() -> void:
	var font := ThemeDB.fallback_font
	for object in progress.node().objects:
		if not bool(object.get("label",true)): continue
		var label: String = object.name
		if label.is_empty(): continue
		var draw_kind: String = str(object.get("visual",object.kind))
		if str(object.kind) == "guide":
			label += "（"+DIR_NAMES[int(guide_dirs.get(object.id,int(object.dir)))]+"）"
		elif str(object.kind) == "end":
			label += "（可通过）" if bool(object_state(object,"").get("available",true)) else "（未开启）"
		elif str(object.kind) == "exit" and not bool(object_state(object,"").get("available",true)):
			label += "（不可通行）"
		elif str(object.kind) == "switch":
			label += "（已开）" if progress.has(str(object.get("flag",""))) else "（未开）"
		elif str(object.kind) == "story":
			label += "（已记录）" if progress.has(str(object.get("event",""))) else ""
		elif str(object.kind) == "growth":
			label += "（已强化）" if progress.has(str(object.get("event",""))) else "（可强化）"
		elif str(object.kind) == "sidequest":
			label += "（已记录）" if progress.has(str(object.get("quest","")) + str(object.get("part",""))) else ""
		elif str(object.kind) == "ending":
			label += "（已选择）" if not progress.ending_id().is_empty() else ("" if progress.has("E30") else "（先压制母体）")
		var anchor: Vector2 = props.label_anchor(draw_kind)
		if str(object.kind) == "rong": anchor = Vector2(0,-22)
		var world_point := Vector2(object.pos[0],object.pos[1]) + anchor
		var at := world_point * 4.0
		var width: float = font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x
		at.x = clampf(at.x-width/2,8,1272-width)
		at.y = clampf(at.y,116,684)
		var baseline := at+Vector2(0,-7)
		ui_layer.draw_string_outline(font,baseline,label,HORIZONTAL_ALIGNMENT_LEFT,-1,24,4,Color(0.02,0.03,0.035,0.95))
		ui_layer.draw_string(font,baseline,label,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("f4dfab"))
