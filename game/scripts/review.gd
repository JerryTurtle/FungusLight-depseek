extends Control
const Store = preload("res://scripts/review_store.gd")
var store = Store.new()
var game
var viewport: SubViewport
var driver
var descriptions := [
	"四向待机、移动、挥杖；\n三法术、闪避、受击、倒地。\n观察握持、脚底与动作方向。",
	"四向挥空、命中、削壳。\n观察破壳时刻，听命中声音。\n是否有力度、方向是否正确？",
	"净光角度与墙体阻挡。\n护灯吸收、破盾；灯雨落点。\n观察延迟及移出范围效果。",
	"追击近击、弹体、毒区。\n冲锋线为测试发射器。\n观察预警、闪避与受击差异。",
	"菌洞 / 水道与战斗叠加。\n呼吸光、孢子、扫描和法术。\n可在设置中比较标准 / 低档。",
	"WASD移动，左键灯击。\n右键净光，1护灯，2灯雨。\n空格闪避，Q扫描。\n点击「返回试打」开始。"
]
var names := ["H01 角色动作","H02 近战反馈","H03 法术表现","H04 危险与闪避","H05 场景与特效","H06 自由试打"]
var labels := ["动作僵硬","方向不对","反馈偏弱","特效遮挡","亮度刺眼","声音不适","操作不顺"]
var info: Label
var readout: Label
var notice: Label
var note: TextEdit
var verdict: OptionButton
var tags: Dictionary = {}
var syncing := false
var tour := false
var tour_index := 0
var selected := 0
var direction := 0
var direction_picker: OptionButton
var zoom_picker: OptionButton
var practice_toggle: CheckButton
var settings
var snapshot_serial := 0
var loop_enabled := true

func button(parent: Node, title: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = title
	result.custom_minimum_size = Vector2(0,36)
	result.focus_mode = Control.FOCUS_NONE
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

func _ready() -> void:
	# The review bench keeps the H2-approved dense tool layout on Noto Sans SC.
	ThemeDB.fallback_font = load("res://assets/fonts/NotoSansSC.ttf")
	ThemeDB.fallback_font_size = 16
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("101e23")
	background.size = Vector2(1280,720)
	add_child(background)
	var title := Label.new()
	title.text = "菌灯之下  /  动作与特效审核台  /  "+Store.BUILD
	title.position = Vector2(20,12)
	title.add_theme_font_size_override("font_size",28)
	add_child(title)
	readout = Label.new()
	readout.position = Vector2(180,54)
	readout.add_theme_font_size_override("font_size",16)
	add_child(readout)
	var left := VBoxContainer.new()
	left.position = Vector2(16,98)
	left.size.x = 150
	left.add_theme_constant_override("separation",10)
	add_child(left)
	for index in 6:
		var current := index
		button(left,names[index],func(): tour = false; select_item(current))
	button(left,"自动巡览 · 约2分钟",start_tour)
	button(left,"画面 / 音量设置",show_settings)
	button(left,"切换菌洞 / 水道",func(): game.sewer = not game.sewer)
	button(left,"退出审核台",func(): game.combat_audio.stop_all(); get_tree().quit())
	var holder := SubViewportContainer.new()
	holder.position = Vector2(180,98)
	holder.size = Vector2(800,480)
	holder.stretch = true
	holder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(holder)
	viewport = SubViewport.new()
	viewport.size = Vector2i(800,480)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = true
	holder.add_child(viewport)
	game = preload("res://scripts/graybox.gd").new()
	game.review_mode = true
	viewport.add_child(game)
	settings = preload("res://scripts/settings_panel.gd").new()
	settings.preferences = game.preferences
	settings.changed.connect(func(): game.combat_audio.set_volume(game.preferences.sfx_volume))
	settings.dismissed.connect(func(): settings.hide(); notice.text = "已保存设置；点击播放或返回试打继续。")
	var controls := HBoxContainer.new()
	controls.position = Vector2(180,592)
	controls.add_theme_constant_override("separation",8)
	add_child(controls)
	button(controls,"播放 / 暂停",toggle_play)
	button(controls,"前进一帧",step_once)
	button(controls,"重播 / 重置",func(): select_item(selected))
	direction_picker = OptionButton.new()
	for text in ["向下","向左","向右","向上"]: direction_picker.add_item(text)
	direction_picker.item_selected.connect(func(value):
		direction = value
		if driver != null:
			driver.direction_index = value
			driver.manual_direction = true
			driver.frame = 0)
	controls.add_child(direction_picker)
	zoom_picker = OptionButton.new()
	for text in ["1倍像素","2倍像素","4倍 · 正式尺度"]: zoom_picker.add_item(text)
	zoom_picker.select(2)
	zoom_picker.item_selected.connect(func(value): game.review_zoom = [1.0,2.0,4.0][value])
	controls.add_child(zoom_picker)
	var extra := HBoxContainer.new()
	extra.position = Vector2(180,638)
	extra.add_theme_constant_override("separation",10)
	add_child(extra)
	var loop := CheckButton.new()
	loop.text = "循环"
	loop.button_pressed = true
	loop.toggled.connect(func(value):
		loop_enabled = value
		if driver != null: driver.loop = value)
	extra.add_child(loop)
	var debug := CheckButton.new()
	debug.text = "判定轮廓"
	debug.toggled.connect(func(value): game.debug_shapes = value)
	extra.add_child(debug)
	practice_toggle = CheckButton.new()
	practice_toggle.text = "练习辅助"
	practice_toggle.toggled.connect(func(value): game.practice = value)
	extra.add_child(practice_toggle)
	button(extra,"返回试打",enter_trial)
	var right := VBoxContainer.new()
	right.position = Vector2(996,98)
	right.size = Vector2(268,570)
	right.clip_contents = true
	right.add_theme_constant_override("separation",6)
	add_child(right)
	info = Label.new()
	info.custom_minimum_size = Vector2(268,108)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_FILL
	info.add_theme_font_size_override("font_size",17)
	right.add_child(info)
	verdict = OptionButton.new()
	for text in ["未审核","通过","需修改"]: verdict.add_item(text)
	verdict.item_selected.connect(func(value):
		if not syncing:
			store.records[key()].status = ["未审核","通过","需修改"][value]
			store.confirmed = false
			suspend(); persist())
	right.add_child(verdict)
	var grid := GridContainer.new()
	grid.columns = 2
	right.add_child(grid)
	for text in labels:
		var tag := CheckBox.new()
		tag.text = text
		tag.add_theme_font_size_override("font_size",14)
		tag.toggled.connect(func(_value):
			if not syncing:
				var chosen: Array = []
				for label in tags:
					if tags[label].button_pressed: chosen.append(label)
				store.records[key()].tags = chosen
				store.confirmed = false
				suspend(); persist())
		grid.add_child(tag)
		tags[text] = tag
	note = TextEdit.new()
	note.placeholder_text = "填写一句问题说明…"
	note.custom_minimum_size = Vector2(268,54)
	note.focus_entered.connect(suspend)
	note.text_changed.connect(func():
		if not syncing:
			store.records[key()].note = note.text
			store.confirmed = false
			persist())
	right.add_child(note)
	button(right,"记录问题 + 当前截图",record_problem)
	button(right,"导出反馈",export_feedback)
	var export_row := HBoxContainer.new()
	right.add_child(export_row)
	button(export_row,"复制反馈",copy_feedback)
	button(export_row,"打开文件夹",func(): OS.shell_open(ProjectSettings.globalize_path(store.directory)))
	button(right,"确认本构建通过",request_confirmation)
	notice = Label.new()
	notice.position = Vector2(20,690)
	notice.size.x = 1240
	notice.add_theme_font_size_override("font_size",16)
	add_child(notice)
	add_child(settings)
	if "--review-test" in OS.get_cmdline_user_args(): store.directory = "user://qa-review/G2-007"
	store.load_review()
	select_item(store.current)
	notice.text = "可先自动巡览，再自由试打。所有项目初始未审核；AI检查不代替你的结论。"
	if "--review-test" in OS.get_cmdline_user_args(): call_deferred("start_test")
	if "--stress" in OS.get_cmdline_user_args(): call_deferred("start_stress")
	print("G2_REVIEW_READY ",Store.BUILD)

func key() -> String: return "H%02d" % (selected+1)

func context() -> Dictionary:
	var actual_direction: Vector2 = game.combat.locked if game.combat.action in ["melee","light","shield","rain","dodge"] else game.combat.facing
	return {"item":key(),"direction":game.art.row(actual_direction),"zoom":game.review_zoom,"low_effects":game.preferences.low_effects,"reduced_motion":game.preferences.reduced_motion,"reduced_flash":game.preferences.reduced_flash,"practice":game.practice,"frame":driver.frame if driver != null else game.combat.tick}

func persist() -> void:
	var result: Error = store.save(context())
	notice.text = "反馈已保存" if result == OK else "保存失败（%d）；仍可复制反馈文字。" % result
	if result == OK and "/用户数据/" in store.directory: notice.text = "反馈已保存到便携目录（系统用户目录不可写）；打开文件夹可查看。"

func suspend() -> void:
	game.paused = true
	game.commands.clear()
	game.combat_audio.stop_all()
	viewport.gui_disable_input = true

func select_item(index: int) -> void:
	selected = index
	store.current = index
	game.combat.reset()
	game.feedback.reset()
	game.combat_audio.stop_all()
	game.death_age = 0
	game.scan_tick = -1000
	game.environment_fx = index == 4 or index == 5
	game.practice = false
	practice_toggle.set_pressed_no_signal(false)
	game.pose_view = false
	if index < 5:
		driver = preload("res://scripts/review_demo.gd").new()
		driver.item = index
		driver.direction_index = direction
		driver.loop = loop_enabled
		game.demo_driver = driver
		game.paused = false
		viewport.gui_disable_input = true
	else:
		driver = null
		game.demo_driver = null
		game.combat.add_enemy(Vector2(240,130),false)
		suspend()
	info.text = names[index]+"\n"+descriptions[index]
	syncing = true
	var record: Dictionary = store.records[key()]
	verdict.select(["未审核","通过","需修改"].find(record.status))
	note.text = record.note
	for label in tags: tags[label].set_pressed_no_signal(label in record.tags)
	syncing = false
	persist()

func toggle_play() -> void:
	if selected == 5:
		if game.paused: enter_trial()
		else: suspend()
		return
	game.paused = not game.paused
	game.commands.clear()
	if game.paused: game.combat_audio.stop_all()

func step_once() -> void:
	if selected == 5: return
	game.paused = false
	game._physics_process(1.0/60)
	suspend()

func enter_trial() -> void:
	tour = false
	if selected != 5: select_item(5)
	get_viewport().gui_release_focus()
	viewport.gui_disable_input = false
	game.commands.clear()
	game.paused = false
	notice.text = "自由试打中：WASD / 左右键 / 1、2 / 空格。点击反馈或设置会暂停。"

func show_settings() -> void:
	suspend()
	settings.show()

func start_tour() -> void:
	tour = true
	tour_index = 0
	select_item(0)
	driver.loop = false

func _process(_delta: float) -> void:
	if game == null: return
	readout.text = "生命 %d   专注 %d   护盾 %d   净光 %.1fs / 护灯 %.1fs / 灯雨 %.1fs  %s" % [game.combat.hp,game.combat.focus,game.combat.shield_hp,float(game.combat.cooldowns.light)/60,float(game.combat.cooldowns.shield)/60,float(game.combat.cooldowns.rain)/60,"【练习辅助】" if game.practice else ""]
	if driver != null: readout.text += "\n"+driver.caption+" · "+["向下","向左","向右","向上"][context().direction]
	if driver != null and driver.finished and tour:
		tour_index += 1
		if tour_index < 5:
			select_item(tour_index)
			driver.loop = false
		else:
			tour = false
			select_item(5)
			notice.text = "巡览结束。点击返回试打，体验正式速度与资源。"

func record_problem() -> void:
	suspend()
	store.records[key()].status = "需修改"
	store.confirmed = false
	verdict.select(2)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(store.directory)
	snapshot_serial += 1
	var path: String = store.directory+"/"+key()+"-"+str(Time.get_unix_time_from_system())+"-"+str(snapshot_serial)+".png"
	var result := get_viewport().get_texture().get_image().save_png(path)
	if result == OK: store.records[key()].captures.append({"path":ProjectSettings.globalize_path(path),"context":context()})
	persist()
	if result != OK: notice.text = "截图保存失败；问题文字已保留，可复制反馈。"

func export_feedback() -> void:
	suspend()
	var result: Error = store.export_files(context())
	notice.text = "已导出 review.json 与 审核反馈.md；可打开文件夹或复制。" if result == OK else "导出失败（%d）；请使用复制反馈。" % result

func copy_feedback() -> void:
	var feedback_text: String = store.markdown()
	for attempt in 5:
		DisplayServer.clipboard_set(feedback_text)
		await get_tree().create_timer(0.05).timeout
		if DisplayServer.clipboard_get().replace("\r\n","\n") == feedback_text:
			notice.text = "反馈已复制。"
			return
	notice.text = "剪贴板暂不可用，请重试或打开已导出的反馈文件。"

func request_confirmation() -> void:
	suspend()
	if not store.all_passed():
		notice.text = "六个项目都明确选为通过后，才能确认本构建。"
		return
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "确认你已审核 G2-007 的六个项目并全部通过？"
	dialog.confirmed.connect(func(): store.confirmed = true; persist(); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F1: show_settings()
		elif event.physical_keycode == KEY_ESCAPE:
			if settings.visible: settings.hide()
			suspend()

func start_test() -> void:
	var test = preload("res://scripts/test_review.gd").new()
	add_child(test)
	test.run(self)

func start_stress() -> void:
	var test = preload("res://scripts/stress_review.gd").new()
	add_child(test)
	test.run(self)

