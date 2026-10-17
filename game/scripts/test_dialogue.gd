extends SceneTree
## Headless 验收测试：底部 RPG 对话框组件（game/scripts/dialogue_box.gd）。
## 运行：godot --headless --path game --script res://scripts/test_dialogue.gd
## 输出：DIALOGUE_TEST checks=N failures=0

const Box = preload("res://scripts/dialogue_box.gd")
const PIXEL_FONT = preload("res://assets/fonts/ArkPixel12px-zh_hans.ttf")

# 约 114 个汉字：1280 宽下应折成 3 行，1920 宽下 2 行，用于验证自动换行不溢出。
const LONG_TEXT := "净光已解锁：右键朝向目标释放。先净化灯座右侧不攻击的教学孢囊；完成后才有主动敌人。灯线沿地面延伸，如果水位继续下降，旧矿通道里的刻痕会先变干，再被新的菌丝覆盖。把灯举高，让光落在每一道刻痕上；记住水退到哪里，也记住是谁先离开。"

var checks := 0
var failures := 0
var advance_count := 0
var skip_count := 0
var chosen: Array = []


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)


func key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func click_event(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	return event


func move_event(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	return event


func is_integer_rect(rect: Rect2) -> bool:
	return is_equal_approx(rect.position.x, roundf(rect.position.x)) \
		and is_equal_approx(rect.position.y, roundf(rect.position.y)) \
		and is_equal_approx(rect.size.x, roundf(rect.size.x)) \
		and is_equal_approx(rect.size.y, roundf(rect.size.y))


## 面板必须固定在屏幕下部、左右 40~48px、底部 24~40px、整数像素、不越界。
func check_viewport_geometry(panel: Rect2, viewport: Vector2, tag: String) -> void:
	var bottom_gap := viewport.y - panel.end.y
	var left_gap := panel.position.x
	var right_gap := viewport.x - panel.end.x
	check(panel.position.y > viewport.y * 0.55,
		tag + ": panel sits in lower screen, y=" + str(panel.position.y))
	check(bottom_gap >= 24.0 and bottom_gap <= 40.0,
		tag + ": bottom margin 24..40, got " + str(bottom_gap))
	check(left_gap >= 40.0 and left_gap <= 48.0,
		tag + ": left margin 40..48, got " + str(left_gap))
	check(right_gap >= 40.0 and right_gap <= 48.0,
		tag + ": right margin 40..48, got " + str(right_gap))
	check(panel.position.x >= 0.0 and panel.position.y >= 0.0,
		tag + ": panel origin inside viewport")
	check(panel.end.x <= viewport.x and panel.end.y <= viewport.y,
		tag + ": panel inside viewport")
	check(is_integer_rect(panel), tag + ": panel uses integer pixel rect")


func check_children_geometry(box, viewport: Vector2, tag: String) -> void:
	var panel: Rect2 = box.get_panel_rect()
	var nameplate: Rect2 = box.get_nameplate_rect()
	var body: Rect2 = box.get_body_rect()
	var hint: Rect2 = box.get_hint_rect()
	check(panel.encloses(body), tag + ": body inside panel")
	check(panel.encloses(hint), tag + ": hint inside panel")
	check(nameplate.position.y < panel.position.y and nameplate.end.y > panel.position.y,
		tag + ": nameplate overlaps panel top edge")
	check(nameplate.position.y >= 0.0 and nameplate.end.y <= viewport.y,
		tag + ": nameplate inside viewport vertically")
	check(nameplate.position.x >= panel.position.x and nameplate.end.x <= panel.end.x,
		tag + ": nameplate inside panel horizontally")
	check(is_integer_rect(nameplate) and is_integer_rect(body) and is_integer_rect(hint),
		tag + ": child rects integer")


func run() -> void:
	ThemeDB.fallback_font = PIXEL_FONT
	ThemeDB.fallback_font_size = 24
	# headless 哑窗口是 64x64，会让全局字体 oversampling 变成 64/1280=0.05；
	# 把根窗口尺寸对齐正式 1280x720 窗口，字体度量才与实机一致（oversampling=1）。
	root.size = Vector2i(1280, 720)
	await process_frame

	var viewport := root.get_visible_rect().size
	var text_server: TextServer = TextServerManager.get_primary_interface()
	check(viewport == Vector2(1280, 720), "root viewport is 1280x720, got " + str(viewport))
	check(is_equal_approx(text_server.font_get_global_oversampling(), 1.0),
		"headless font oversampling matches a real 1280x720 window")
	check(is_equal_approx(PIXEL_FONT.get_height(24), 32.0),
		"pixel font 24px line metrics available, height=" + str(PIXEL_FONT.get_height(24)))
	check(LONG_TEXT.length() >= 100, "long test text long enough, length=" + str(LONG_TEXT.length()))

	# ------------------------------------------------------------------
	# 1. 初始状态 + 1280x720 布局
	# ------------------------------------------------------------------
	var box = Box.new()
	root.add_child(box)
	await process_frame
	box.set_process(false)
	box.advance_requested.connect(func(): advance_count += 1)
	box.skip_requested.connect(func(): skip_count += 1)
	box.choice_selected.connect(func(id: String): chosen.append(id))

	check(not box.is_open(), "starts closed")
	check(not box.visible, "starts hidden")
	check(not box.handle_input(key_event(KEY_E)), "closed box does not consume input")
	check(not box.handle_input(click_event(Vector2(640, 600))), "closed box ignores clicks")
	check(not box.get_nameplate_visible(), "nameplate hidden while closed")
	check(box.get_panel_rect() == Rect2(48, 504, 1184, 176),
		"1280x720 panel rect (48,504,1184,176), got " + str(box.get_panel_rect()))
	check_viewport_geometry(box.get_panel_rect(), viewport, "1280x720")

	# ------------------------------------------------------------------
	# 2. 1920x1080 视口：真实 SubViewport + 显式 layout_for 两条路径
	# ------------------------------------------------------------------
	var sub := SubViewport.new()
	sub.size = Vector2i(1920, 1080)
	sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(sub)
	var wide = Box.new()
	sub.add_child(wide)
	await process_frame
	wide.set_process(false)
	var wide_viewport := Vector2(1920, 1080)
	var expected_wide := Rect2(48, 864, 1824, 176)
	check(wide.get_viewport_rect().size == wide_viewport, "subviewport reports 1920x1080")
	check(wide.get_panel_rect() == expected_wide,
		"1920x1080 panel rect (48,864,1824,176), got " + str(wide.get_panel_rect()))
	check_viewport_geometry(wide.get_panel_rect(), wide_viewport, "1920x1080")
	wide.show_line("岚", "这盏还有余温。")
	check(wide.is_open() and wide.visible, "wide dialogue opens")
	check_children_geometry(wide, wide_viewport, "1920x1080")

	box.layout_for(wide_viewport)
	check(box.get_panel_rect() == expected_wide, "layout_for(1920x1080) matches SubViewport result")
	box.clear_layout_override()
	check(box.get_panel_rect() == Rect2(48, 504, 1184, 176),
		"clear_layout_override restores 1280x720 layout")

	# ------------------------------------------------------------------
	# 3. 名字 / 正文 / 字体
	# ------------------------------------------------------------------
	box.show_line("岚", "这盏还有余温。我去储藏间找备用灯芯。")
	check(box.is_open() and box.visible, "visible after show_line")
	check(box.is_revealing() and not box.is_waiting(), "starts revealing")
	check(box.get_speaker() == "岚" and box.get_name_text() == "岚", "speaker shown on nameplate")
	check(box.get_nameplate_visible(), "nameplate visible for named speaker")
	check(box.get_name_color() == Color("e8c274"), "岚 name color is warm gold e8c274")
	check(box.get_name_color() == Box.speaker_color("岚"), "name color matches speaker palette")
	check(box.get_visible_chars() == 0 and box.get_body_label().text == "",
		"body empty before first tick")
	check(box.get_body_label().autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
		"body label autowraps")
	check(box.get_body_label().get_theme_font_size("font_size") == 24, "body font size 24")
	check(box.get_name_label().get_theme_font_size("font_size") == 24, "name font size 24")
	check(box.get_hint_label().get_theme_font_size("font_size") == 12, "hint font size 12")
	check(box.get_prompt_label().get_theme_font_size("font_size") == 24,
		"choice prompt font size 24")
	var label_font: Font = box.get_body_label().get_theme_font("font")
	check(label_font != null and label_font.get_font_name().to_lower().find("ark pixel") >= 0,
		"label font comes from ThemeDB fallback pixel font: "
			+ (label_font.get_font_name() if label_font != null else "<null>"))
	check(box.get_hint_text().find("Tab") >= 0, "line hint offers Tab skip")
	check(is_integer_rect(box.get_body_rect()) and is_integer_rect(box.get_nameplate_rect()),
		"line rects use integer pixels")
	check_children_geometry(box, viewport, "1280x720")

	# ------------------------------------------------------------------
	# 4. 说话人配色与名字牌宽度
	# ------------------------------------------------------------------
	var color_cases := [
		["岚", Color("e8c274")],
		["绒", Color("a6c47c")],
		["伤员", Color("a9d6d2")],
		["提示", Color("7ed3b2")],
	]
	for entry in color_cases:
		box.show_line(entry[0], "测试")
		check(box.get_name_color() == entry[1], "speaker color " + entry[0])
	box.show_line("陌生旅人", "测试")
	check(box.get_name_color() == Color("f2e8d4"), "unknown speaker uses warm white")
	var narrow_plate: float = 0.0
	box.show_line("岚", "测试")
	narrow_plate = box.get_nameplate_rect().size.x
	box.show_line("年迈的守灯人", "测试")
	check(box.get_nameplate_rect().size.x > narrow_plate, "nameplate width follows name length")
	check(box.get_nameplate_rect().end.x <= box.get_panel_rect().end.x,
		"long nameplate stays inside panel")

	# ------------------------------------------------------------------
	# 5. 逐帧打字机 + 速率 + 补全
	# ------------------------------------------------------------------
	var text10 := "一二三四五六七八九十"
	box.show_line("岚", text10)
	check(box.get_visible_chars() == 0 and box.is_revealing(), "typewriter resets per line")
	var typewriter_ok := true
	for index in 10:
		box.tick(0.02)
		if box.get_visible_chars() != index + 1:
			typewriter_ok = false
	check(typewriter_ok, "typewriter advances exactly 1 char per 0.02s tick (50 chars/s)")
	check(box.get_body_label().text == text10, "body shows full sentence after ticks")
	check(not box.is_revealing() and box.is_waiting(), "line finished revealing")
	check(box.is_arrow_visible(), "blinking arrow visible once sentence complete")

	box.show_line("提示", LONG_TEXT)
	box.tick(0.1)
	check(box.get_visible_chars() == 5, "0.1s reveals 5 chars at 50 chars/s")
	box.tick(1.0)
	check(box.get_visible_chars() == 55, "next 1.0s reveals 50 chars (within 45~55 chars/s)")
	box.reveal_all()
	check(box.get_visible_chars() == LONG_TEXT.length(), "reveal_all shows every char")
	check(box.get_body_label().text == LONG_TEXT, "reveal_all exposes full text")
	check(not box.is_revealing() and box.is_waiting(), "reveal_all ends revealing state")

	box.show_line("岚", "补全测试句")
	box.tick(0.04)
	var reveal_press := key_event(KEY_E)
	check(box.handle_input(reveal_press), "E consumed while revealing")
	check(advance_count == 0, "first E only completes the sentence")
	check(not box.is_revealing() and box.get_body_label().text == "补全测试句",
		"first E reveals the whole sentence")
	check(box.handle_input(reveal_press), "replayed same event object consumed")
	check(advance_count == 0, "replayed same event never advances twice")
	check(box.handle_input(key_event(KEY_E)), "second distinct E consumed")
	check(advance_count == 1, "second E emits advance_requested")
	check(box.is_open(), "advance signal keeps box open until caller reacts")

	# ------------------------------------------------------------------
	# 6. 回车 / 空格 / 左键推进
	# ------------------------------------------------------------------
	box.show_line("岚", "短句")
	box.reveal_all()
	check(box.handle_input(key_event(KEY_ENTER)), "Enter consumed after reveal")
	check(advance_count == 2, "Enter advances")
	box.show_line("岚", "短句")
	box.reveal_all()
	check(box.handle_input(key_event(KEY_SPACE)), "Space consumed after reveal")
	check(advance_count == 3, "Space advances")
	box.show_line("岚", "短句")
	box.reveal_all()
	check(box.handle_input(click_event(Vector2(640, 600))), "left click consumed after reveal")
	check(advance_count == 4, "left click advances")
	box.show_line("岚", "一二三四五六")
	check(box.handle_input(click_event(Vector2(300, 620))), "left click consumed while revealing")
	check(box.get_visible_chars() == 6 and advance_count == 4,
		"left click only completes while revealing")

	# ------------------------------------------------------------------
	# 7. Tab 跳过本段
	# ------------------------------------------------------------------
	box.show_line("岚", "一二三四")
	check(box.handle_input(key_event(KEY_TAB)), "Tab consumed while revealing")
	check(skip_count == 1, "Tab emits skip_requested while revealing")
	check(box.is_open(), "skip signal does not close the box (campaign decides)")
	box.show_line("岚", "短句")
	box.reveal_all()
	check(box.handle_input(key_event(KEY_TAB)), "Tab consumed when waiting")
	check(skip_count == 2, "Tab emits skip_requested when waiting")
	box.show_line("岚", "短句")
	var tab_event := key_event(KEY_TAB)
	check(box.handle_input(tab_event) and skip_count == 3, "Tab emits skip_requested once")
	box.handle_input(tab_event)
	check(skip_count == 3, "replayed Tab does not emit twice")
	check(advance_count == 4, "Tab never emits advance_requested")

	# ------------------------------------------------------------------
	# 8. 选项页（M1 两选一）
	# ------------------------------------------------------------------
	var choice_prompt := "初燃 · 选择一项强化"
	var choice_options := [
		{"id": "melee", "label": "灯击伤害 +15%", "desc": "18 → 21"},
		{"id": "light", "label": "净光伤害 +15%", "desc": "24 → 28"},
	]
	box.show_choices(choice_prompt, choice_options)
	check(box.is_choices() and box.is_open() and box.visible, "choices page opens")
	check(box.get_prompt_text() == choice_prompt, "choices prompt shown")
	check(box.get_prompt_label().get_theme_font_size("font_size") == 24, "prompt font size 24")
	check(box.get_options().size() == 2, "two options stored")
	check(box.get_option_labels().size() == 2, "two option rows built")
	for option_label in box.get_option_labels():
		check(option_label.get_theme_font_size("font_size") == 24,
			"option label font size 24")
	check(not box.get_nameplate_visible(), "nameplate hidden on choices page")
	check(box.get_hint_text().find("W / S") >= 0, "choices hint lists W/S")
	check(box.get_selected_index() == 0 and box.get_selected_id() == "melee",
		"first option selected by default")
	check(box.get_panel_rect() == Rect2(48, 504, 1184, 176),
		"choices share the same bottom box")
	var choice_panel := box.get_panel_rect()
	check(choice_panel.encloses(box.get_prompt_rect()), "prompt inside panel")
	check(is_integer_rect(box.get_prompt_rect()), "prompt rect integer pixels")
	for option_rect in box.get_option_rects():
		check(choice_panel.encloses(option_rect), "option row inside panel")
		check(is_integer_rect(option_rect), "option hit rect integer pixels")

	# 键盘切换
	check(box.handle_input(key_event(KEY_S)), "S consumed on choices page")
	check(box.get_selected_index() == 1 and box.get_selected_id() == "light",
		"S selects second option")
	check(box.handle_input(key_event(KEY_W)), "W consumed on choices page")
	check(box.get_selected_index() == 0, "W selects first option")
	check(box.handle_input(key_event(KEY_UP)), "Up consumed on choices page")
	check(box.get_selected_index() == 1, "Up wraps to last option")
	check(box.handle_input(key_event(KEY_DOWN)), "Down consumed on choices page")
	check(box.get_selected_index() == 0, "Down wraps to first option")

	# 鼠标悬停切换（不确认）
	var rows: Array[Rect2] = box.get_option_rects()
	check(box.handle_input(move_event(rows[1].get_center())), "hover consumed over option row")
	check(box.get_selected_index() == 1, "mouse hover switches selection")
	check(chosen.is_empty(), "hover alone never confirms")

	# 选项页不可被 Tab 跳过
	var skip_before := skip_count
	check(box.handle_input(key_event(KEY_TAB)), "Tab consumed on choices page")
	check(skip_count == skip_before, "choices page never emits skip_requested")
	check(box.is_choices(), "Tab cannot leave the choices page")

	# E 确认（当前悬停第二项）
	var confirm_event := key_event(KEY_E)
	check(box.handle_input(confirm_event), "E consumed to confirm choice")
	check(chosen.size() == 1 and chosen[0] == "light",
		"E emits choice_selected with hovered id")
	check(box.handle_input(confirm_event), "replayed confirm consumed")
	check(chosen.size() == 1, "replayed confirm does not emit twice")

	# 回车确认第一项
	chosen.clear()
	box.show_choices(choice_prompt, choice_options)
	check(box.handle_input(key_event(KEY_ENTER)), "Enter consumed to confirm choice")
	check(chosen.size() == 1 and chosen[0] == "melee", "Enter confirms first option")

	# 左键点击第二项确认
	chosen.clear()
	box.show_choices(choice_prompt, choice_options)
	rows = box.get_option_rects()
	check(box.handle_input(click_event(rows[1].get_center())), "left click consumed on option row")
	check(chosen.size() == 1 and chosen[0] == "light", "left click confirms clicked option")

	# 点空白 / 空格都不确认
	chosen.clear()
	box.show_choices(choice_prompt, choice_options)
	check(box.handle_input(click_event(Vector2(12, 12))), "click outside options consumed")
	check(chosen.is_empty(), "click outside options never confirms")
	check(box.handle_input(key_event(KEY_SPACE)), "Space consumed on choices page")
	check(chosen.is_empty(), "Space never confirms a choice")
	check(box.is_choices(), "choices stay open until caller reacts")

	# ------------------------------------------------------------------
	# 9. 超长文本自动换行，不溢出面板
	# ------------------------------------------------------------------
	box.show_line("提示", LONG_TEXT)
	box.reveal_all()
	var line_count: int = box.get_body_line_count()
	check(line_count >= 2, "long text wraps into multiple lines, lines=" + str(line_count))
	check(line_count <= 3, "long text fits 3-line budget, lines=" + str(line_count))
	var line_height: float = box.get_body_label().get_line_height()
	var line_spacing: int = box.get_body_label().get_theme_constant("line_spacing")
	check(line_height > 0.0, "label line height measured")
	check(is_equal_approx(line_height + float(line_spacing), 34.0),
		"body line pitch is ~34px, got " + str(line_height + float(line_spacing)))
	var needed_height := line_height * float(line_count) + float(line_spacing) * float(line_count - 1)
	check(needed_height <= box.get_body_rect().size.y,
		"wrapped text height fits body rect, needed=" + str(needed_height))
	check(box.get_body_label().size.x == box.get_body_rect().size.x,
		"body label width matches body rect")
	check(box.get_body_label().text.find("\n") == -1, "no manual newline inserted for CJK wrap")
	check(box.get_body_label().text == LONG_TEXT, "wrap keeps the original text untouched")
	check(box.get_body_label().get_line_count() == line_count, "line count stable after layout")

	wide.show_line("提示", LONG_TEXT)
	wide.reveal_all()
	var wide_line_count: int = wide.get_body_line_count()
	check(wide_line_count < line_count,
		"wider viewport wraps into fewer lines: " + str(wide_line_count) + " < " + str(line_count))
	check(is_equal_approx(wide.get_body_label().get_line_height()
		+ float(wide.get_body_label().get_theme_constant("line_spacing")), 34.0),
		"wide viewport keeps the 34px line pitch")

	# ------------------------------------------------------------------
	# 10. ▼ 闪烁节奏
	# ------------------------------------------------------------------
	box.show_line("岚", "短句")
	box.reveal_all()
	check(box.is_arrow_visible(), "arrow on immediately after reveal")
	box.tick(0.7)
	check(not box.is_arrow_visible(), "arrow blinks off at 0.7s")
	box.tick(0.4)
	check(box.is_arrow_visible(), "arrow blinks back on at 1.1s")

	# ------------------------------------------------------------------
	# 11. 绘制冒烟：headless 也会执行 _draw，确认对白/选项两条绘制分支跑通
	# ------------------------------------------------------------------
	box.show_line("岚", "绘制冒烟：名字牌、正文、操作提示与 ▼。")
	box.reveal_all()
	box.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame
	var line_draws: int = box.get_draw_count()
	check(line_draws > 0, "line-mode panel executes _draw in headless")
	box.show_choices(choice_prompt, choice_options)
	box.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame
	check(box.get_draw_count() > line_draws, "choices-mode panel executes _draw in headless")

	# ------------------------------------------------------------------
	# 12. close 后隐藏且不再消费输入 / 不发信号
	# ------------------------------------------------------------------
	box.close()
	check(not box.is_open() and not box.visible, "close hides the dialogue")
	check(not box.get_nameplate_visible(), "close hides the nameplate")
	check(not box.handle_input(key_event(KEY_E)), "closed box ignores advance keys")
	check(not box.handle_input(click_event(Vector2(640, 600))), "closed box ignores left clicks")
	check(not box.handle_input(key_event(KEY_TAB)), "closed box ignores Tab")
	check(box.get_panel_rect() == Rect2(48, 504, 1184, 176), "geometry kept after close")
	check(advance_count == 4 and skip_count == 3 and chosen.is_empty(),
		"closed box emitted no extra signals")
	check(not paused, "component never changes tree pause (caller owns pause)")

	# ------------------------------------------------------------------
	# 13. 挂到 Node2D（campaign 实际集成路径）也能自动布局
	# ------------------------------------------------------------------
	var host := Node2D.new()
	root.add_child(host)
	var hosted = Box.new()
	host.add_child(hosted)
	await process_frame
	hosted.set_process(false)
	check(hosted.get_panel_rect() == Rect2(48, 504, 1184, 176),
		"auto-layouts under a Node2D parent")
	hosted.show_line("岚", "测试挂载")
	check(hosted.is_open() and hosted.visible, "opens under a Node2D parent")
	host.queue_free()
	await process_frame

	# ------------------------------------------------------------------
	# 清理并输出
	# ------------------------------------------------------------------
	sub.queue_free()
	box.queue_free()
	await process_frame
	await process_frame
	print("DIALOGUE_ENV viewport=", viewport, " font=", PIXEL_FONT.get_font_name(),
		" oversampling=", text_server.font_get_global_oversampling(),
		" panel=", Rect2(48, 504, 1184, 176))
	print("DIALOGUE_TEST checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
