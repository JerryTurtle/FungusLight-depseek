class_name DialogueBox
extends Control
## 《菌灯之下》底部 RPG 对话框（像素风、自包含、可 headless 测试）。
##
## 调用约定：
## - 组件从不修改战斗状态或 `paused`；调用方在打开对话时自行暂停游戏。
## - 组件自身在 `_process` 中推进打字机；需要确定性时调用方 `set_process(false)`，
##   然后手动调用 `tick(delta)`。
## - 输入由调用方在 `_unhandled_input` 中最先交给 `handle_input(event)`；
##   返回 true 表示对话框已消费该事件，调用方应 `set_input_as_handled()` 并跳过战斗输入。
## - 字体只从 theme / `ThemeDB.fallback_font` 读取（Lead 会把它设为缝合像素字体 Fusion Pixel），
##   组件不 preload 任何字体文件，也不把某个字体路径当作唯一来源。
##
## 状态机：
##   CLOSED --show_line--> REVEALING --tick 播完--> WAITING
##   REVEALING --E/回车/空格/左键--> WAITING（补全当前句）
##   WAITING --E/回车/空格/左键--> 发射 advance_requested（由调用方 show_line/close）
##   REVEALING/WAITING --Tab--> 发射 skip_requested（语义由调用方决定）
##   CLOSED --show_choices--> CHOICES --E/回车/左键--> 发射 choice_selected(id)
##   CHOICES 中 Tab 会被吞掉，永远不发射 skip_requested（跳过不能替玩家做选择）。

signal advance_requested
signal skip_requested
signal choice_selected(id: String)

enum State { CLOSED, REVEALING, WAITING, CHOICES }

## 打字机速度（字/秒），需求 45~55 字/秒，取中值便于 60Hz 与测试换算。
const CHARS_PER_SECOND := 50.0

# 像素字体是 12px 网格：字号只能是 12 的整数倍（24 正文/名字/选项，12 提示）。
const BODY_FONT_SIZE := 24
const NAME_FONT_SIZE := 24
const HINT_FONT_SIZE := 12
const PROMPT_FONT_SIZE := 24
const OPTION_FONT_SIZE := 24
const OPTION_DESC_FONT_SIZE := 12
const BODY_LINE_HEIGHT := 34
const HINT_LINE_HEIGHT := 18
const BODY_MAX_LINES := 3
const PROMPT_MAX_LINES := 2

# 1280×720 设计值：面板 (48,504) 尺寸 (1184,176)，左右 48px、底部 40px。
const PANEL_HEIGHT := 176
const SIDE_MARGIN := 48
const BOTTOM_MARGIN := 40
const NAME_PLATE_HEIGHT := 44
const OPTION_ROW_HEIGHT := 34
const OPTION_TOP_PAD := 80

# 像素调色：深青黑底 + 暖金细边，禁止圆角/渐变/抗锯齿。
const COLOR_PANEL_BLACK := Color(0.020, 0.043, 0.050, 0.980)
const COLOR_PANEL_BG := Color(0.050, 0.095, 0.105, 0.930)
const COLOR_EDGE_WARM := Color(0.847, 0.694, 0.416, 0.850)
const COLOR_CORNER := Color(0.914, 0.804, 0.553, 0.750)
const COLOR_NAME_BG := Color(0.063, 0.110, 0.115, 0.970)
const COLOR_BODY_TEXT := Color(0.945, 0.906, 0.816, 1.0)
const COLOR_HINT := Color(0.560, 0.682, 0.624, 1.0)
const COLOR_PROMPT := Color(0.941, 0.843, 0.604, 1.0)
const COLOR_OPTION_IDLE := Color(0.840, 0.810, 0.710, 1.0)
const COLOR_OPTION_ACTIVE := Color(1.000, 0.878, 0.600, 1.0)
const COLOR_DESC_IDLE := Color(0.500, 0.600, 0.560, 1.0)
const COLOR_DESC_ACTIVE := Color(0.720, 0.650, 0.500, 1.0)
const COLOR_ARROW := Color(0.949, 0.812, 0.541, 1.0)

## 当前状态（只读；集成方不要直接改，统一走 show_line/show_choices/close）。
var state: int = State.CLOSED

# --- 文本与选项数据 ---
var _speaker := ""
var _full_text := ""
var _visible_chars := 0
var _options: Array = []
var _selected_index := 0
var _choice_committed := false

# --- 计时 ---
var _reveal_accum := 0.0
var _blink_accum := 0.0
var _arrow_on := true

# --- 输入去重：同一次事件对象只处理一次，避免重复推进/重复确认 ---
var _recent_events: Array[int] = []

# 诊断：headless 测试用它确认 _draw 各分支确实执行过。
var _draw_count := 0

# --- 布局（本地坐标；组件固定在视口原点）---
var _layout_override := Vector2.ZERO
var _panel_rect := Rect2()
var _nameplate_rect := Rect2()
var _body_rect := Rect2()
var _hint_rect := Rect2()
var _prompt_rect := Rect2()
var _option_rects: Array[Rect2] = []

# --- 字体与节点 ---
var _font: Font
var _font_source: Font
var _name_label: Label
var _body_label: Label
var _hint_label: Label
var _prompt_label: Label
var _option_labels: Array[Label] = []
var _option_descs: Array[Label] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 调用方用脚本级 paused 冻结战斗；树级 paused 也保持对话框可动。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_font()
	_build_labels()
	close()
	if is_inside_tree() and not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	_layout()


func _process(delta: float) -> void:
	tick(delta)


# =============================================================================
# 公共 API
# =============================================================================

## 显示一句对白：名字牌 + 逐字显示正文。重复调用会重置为新的 REVEALING。
func show_line(speaker: String, text: String) -> void:
	_ensure_font()
	_speaker = speaker
	_full_text = text
	_visible_chars = 0
	_reveal_accum = 0.0
	_blink_accum = 0.0
	_arrow_on = true
	_choice_committed = false
	_options.clear()
	state = State.WAITING if text.is_empty() else State.REVEALING
	_name_label.text = speaker
	_name_label.add_theme_color_override("font_color", speaker_color(speaker))
	_body_label.text = ""
	_prompt_label.text = ""
	_apply_mode_visibility()
	_update_hint()
	_layout()
	visible = true
	queue_redraw()


## 显示选项页（M1 两选一）。options: [{id,label,desc}, ...]，也接受纯字符串。
func show_choices(prompt: String, options: Array) -> void:
	_ensure_font()
	_speaker = ""
	_full_text = ""
	_visible_chars = 0
	_reveal_accum = 0.0
	_blink_accum = 0.0
	_options = _normalize_options(options)
	_selected_index = 0
	_choice_committed = false
	state = State.CHOICES
	_name_label.text = ""
	_body_label.text = ""
	_prompt_label.text = prompt
	_rebuild_option_nodes()
	_apply_mode_visibility()
	_update_hint()
	_layout()
	visible = true
	_refresh_choices()
	queue_redraw()


## 立即补全当前句（仅 REVEALING 有效）；完成后不再自动推进。
func reveal_all() -> void:
	if state != State.REVEALING:
		return
	_visible_chars = _full_text.length()
	_reveal_accum = float(_visible_chars)
	_body_label.text = _full_text
	state = State.WAITING
	_blink_accum = 0.0
	_arrow_on = true
	_update_hint()
	queue_redraw()


## 是否仍在逐字显示。
func is_revealing() -> bool:
	return state == State.REVEALING


## 是否已全部显示、等待推进。
func is_waiting() -> bool:
	return state == State.WAITING


## 是否处于选项页。
func is_choices() -> bool:
	return state == State.CHOICES


## 对话组件是否逻辑上打开（与 visible 同步，由 show_*/close 维护）。
func is_open() -> bool:
	return state != State.CLOSED


## 关闭并隐藏；不发信号、不动调用方的 paused。
func close() -> void:
	state = State.CLOSED
	_speaker = ""
	_full_text = ""
	_visible_chars = 0
	_options.clear()
	_selected_index = 0
	_choice_committed = false
	_recent_events.clear()
	if _name_label != null:
		_name_label.text = ""
		_body_label.text = ""
		_hint_label.text = ""
		_prompt_label.text = ""
	_clear_option_nodes()
	_apply_mode_visibility()
	visible = false
	queue_redraw()


## 确定性计时入口：打字机与 ▼ 闪烁都只在这里推进（_process 只是转调本函数）。
func tick(delta: float) -> void:
	if state == State.REVEALING:
		_reveal_accum += maxf(delta, 0.0) * CHARS_PER_SECOND
		# 加极小 epsilon 抵消 1/60 等浮点累计误差，避免少显示最后一字。
		var count := mini(floori(_reveal_accum + 0.0001), _full_text.length())
		if count != _visible_chars:
			_visible_chars = count
			_body_label.text = _full_text.substr(0, _visible_chars)
		if _visible_chars >= _full_text.length():
			state = State.WAITING
			_reveal_accum = float(_visible_chars)
			_blink_accum = 0.0
			_arrow_on = true
			_update_hint()
			queue_redraw()
	elif state == State.WAITING:
		_blink_accum += maxf(delta, 0.0)
		var on := fmod(_blink_accum, 1.0) < 0.6
		if on != _arrow_on:
			_arrow_on = on
			queue_redraw()


## 输入入口。返回 true = 对话框已消费该事件（调用方不要再交给战斗/移动）。
## 同一次 InputEvent 对象重复传入只生效一次；选项页吞掉 Tab，绝不跳过。
func handle_input(event: InputEvent) -> bool:
	if state == State.CLOSED or event == null:
		return false
	if _recent_events.has(event.get_instance_id()):
		return true
	if event is InputEventKey:
		if not event.pressed or event.echo:
			return false
		var key_code: int = int(event.physical_keycode)
		if key_code == 0:
			key_code = int(event.keycode)
		return _handle_key(key_code, event)
	if event is InputEventMouseButton:
		if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
			return false
		return _handle_pointer(event)
	if event is InputEventMouseMotion:
		if state == State.CHOICES:
			return _handle_hover(event)
	return false


# =============================================================================
# 只读查询（测试 / 集成诊断）
# =============================================================================

func get_panel_rect() -> Rect2:
	return _panel_rect


func get_nameplate_rect() -> Rect2:
	return _nameplate_rect


func get_body_rect() -> Rect2:
	return _body_rect


func get_hint_rect() -> Rect2:
	return _hint_rect


func get_prompt_rect() -> Rect2:
	return _prompt_rect


func get_option_rects() -> Array[Rect2]:
	return _option_rects.duplicate()


func get_nameplate_visible() -> bool:
	return _name_label != null and _name_label.visible


func get_speaker() -> String:
	return _speaker


func get_full_text() -> String:
	return _full_text


func get_visible_chars() -> int:
	return _visible_chars


func get_body_label() -> Label:
	return _body_label


func get_name_label() -> Label:
	return _name_label


func get_hint_label() -> Label:
	return _hint_label


func get_prompt_label() -> Label:
	return _prompt_label


func get_option_labels() -> Array[Label]:
	return _option_labels.duplicate()


func get_body_line_count() -> int:
	return _body_label.get_line_count() if _body_label != null else 0


func get_hint_text() -> String:
	return _hint_label.text if _hint_label != null else ""


func get_prompt_text() -> String:
	return _prompt_label.text if _prompt_label != null else ""


func get_name_text() -> String:
	return _name_label.text if _name_label != null else ""


func get_name_color() -> Color:
	return _name_label.get_theme_color("font_color") if _name_label != null else Color.WHITE


func is_arrow_visible() -> bool:
	return state == State.WAITING and _arrow_on


func get_draw_count() -> int:
	return _draw_count


func get_options() -> Array:
	return _options.duplicate(true)


func get_selected_index() -> int:
	return _selected_index


func get_selected_id() -> String:
	if _options.is_empty():
		return ""
	var index := clampi(_selected_index, 0, _options.size() - 1)
	return str(_options[index].get("id", ""))


## 说话人配色：岚=暖金、绒=苔绿、伤员=浅青、提示=青绿、未知=暖白。
static func speaker_color(speaker: String) -> Color:
	match speaker:
		"岚":
			return Color("e8c274")
		"绒":
			return Color("a6c47c")
		"伤员":
			return Color("a9d6d2")
		"提示":
			return Color("7ed3b2")
	return Color("f2e8d4")


## 测试/特殊视口入口：用显式视口尺寸重排（1920×1080 等），不依赖真实窗口。
func layout_for(viewport_size: Vector2) -> void:
	_layout_override = viewport_size
	_layout()


func clear_layout_override() -> void:
	_layout_override = Vector2.ZERO
	_layout()


# =============================================================================
# 输入处理
# =============================================================================

func _handle_key(key_code: int, event: InputEvent) -> bool:
	match state:
		State.CHOICES:
			match key_code:
				KEY_TAB:
					# 选项页不可跳过：吞掉 Tab，不发射 skip_requested。
					return _consume(event)
				KEY_W, KEY_UP:
					_move_selection(-1)
					return _consume(event)
				KEY_S, KEY_DOWN:
					_move_selection(1)
					return _consume(event)
				KEY_E, KEY_ENTER, KEY_KP_ENTER:
					_confirm_choice()
					return _consume(event)
				KEY_SPACE:
					# 空格不是确认键；吞掉以免误触闪避。
					return _consume(event)
		State.REVEALING, State.WAITING:
			match key_code:
				KEY_TAB:
					skip_requested.emit()
					return _consume(event)
				KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					_accept_advance()
					return _consume(event)
	return false


func _handle_pointer(event: InputEventMouseButton) -> bool:
	var size := _options.size()
	if state == State.CHOICES and size > 0:
		var point := _local_pointer(event.position)
		for index in _option_rects.size():
			if _option_rects[index].has_point(point):
				_selected_index = index
				_refresh_choices()
				_confirm_choice()
				return _consume(event)
		# 选项页任意左键都不外泄给战斗，但点在空白处不确认。
		return _consume(event)
	_accept_advance()
	return _consume(event)


func _handle_hover(event: InputEventMouseMotion) -> bool:
	if _options.is_empty():
		return false
	var point := _local_pointer(event.position)
	for index in _option_rects.size():
		if _option_rects[index].has_point(point):
			if _selected_index != index:
				_selected_index = index
				_refresh_choices()
			return _consume(event)
	return false


func _accept_advance() -> void:
	if state == State.REVEALING:
		reveal_all()
	elif state == State.WAITING:
		advance_requested.emit()


func _move_selection(direction: int) -> void:
	if _options.is_empty():
		return
	_selected_index = wrapi(_selected_index + direction, 0, _options.size())
	_refresh_choices()


func _confirm_choice() -> void:
	if _choice_committed or _options.is_empty():
		return
	_choice_committed = true
	choice_selected.emit(get_selected_id())


func _consume(event: InputEvent) -> bool:
	var instance_id := event.get_instance_id()
	if not _recent_events.has(instance_id):
		_recent_events.append(instance_id)
		if _recent_events.size() > 32:
			_recent_events.pop_front()
	return true


func _local_pointer(viewport_position: Vector2) -> Vector2:
	if is_inside_tree():
		return get_global_transform_with_canvas().affine_inverse() * viewport_position
	return viewport_position


# =============================================================================
# 字体与子节点
# =============================================================================

func _ensure_font() -> void:
	var source := _resolve_font_source()
	if source == null:
		return
	if source == _font_source and _font != null:
		return
	_font_source = source
	var crisp: Font = source.duplicate()
	var font_file := crisp as FontFile
	if font_file != null:
		# 像素字体：关闭抗锯齿/字形微调/亚像素定位，保证整数像素硬边。
		font_file.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font_file.hinting = TextServer.HINTING_NONE
		font_file.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		if font_file.has_method("clear_cache"):
			font_file.clear_cache()
	_font = crisp
	_apply_font_to_labels()


## 字体来源：优先使用项目自定义 theme 的字体；若 theme 只提供引擎默认字体，
## 则改用 Lead 设置的 ThemeDB.fallback_font（缝合像素字体 Fusion Pixel）。组件本身不加载字体文件。
func _resolve_font_source() -> Font:
	var theme_font: Font = get_theme_font("font", "Label")
	var default_theme := ThemeDB.get_default_theme()
	var engine_default: Font = null
	if default_theme != null:
		engine_default = default_theme.get_font("font", "Label")
	var fallback: Font = ThemeDB.fallback_font
	if theme_font != null and theme_font != engine_default:
		return theme_font
	if fallback != null:
		return fallback
	return theme_font


func _build_labels() -> void:
	_name_label = _make_label(NAME_FONT_SIZE, speaker_color(""))
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_body_label = _make_label(BODY_FONT_SIZE, COLOR_BODY_TEXT)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.max_lines_visible = BODY_MAX_LINES
	_body_label.clip_text = true
	_body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	_hint_label = _make_label(HINT_FONT_SIZE, COLOR_HINT)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_prompt_label = _make_label(PROMPT_FONT_SIZE, COLOR_PROMPT)
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_label.max_lines_visible = PROMPT_MAX_LINES
	_prompt_label.clip_text = true


func _make_label(font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_constant_override("outline_size", 0)
	label.visible = false
	if _font != null:
		label.add_theme_font_override("font", _font)
	_apply_line_spacing(label)
	add_child(label)
	return label


func _apply_font_to_labels() -> void:
	for label in [_name_label, _body_label, _hint_label, _prompt_label]:
		if label != null:
			label.add_theme_font_override("font", _font)
			_apply_line_spacing(label)
	for label in _option_labels:
		label.add_theme_font_override("font", _font)
		_apply_line_spacing(label)
	for label in _option_descs:
		label.add_theme_font_override("font", _font)
		_apply_line_spacing(label)


func _apply_line_spacing(label: Label) -> void:
	if _font == null or label == null:
		return
	var font_size: int = int(label.get_theme_font_size("font_size"))
	var target := HINT_LINE_HEIGHT if font_size <= HINT_FONT_SIZE else BODY_LINE_HEIGHT
	var spacing := maxi(0, target - roundi(_font.get_height(font_size)))
	label.add_theme_constant_override("line_spacing", spacing)


func _rebuild_option_nodes() -> void:
	_clear_option_nodes()
	for index in _options.size():
		var label := _make_label(OPTION_FONT_SIZE, COLOR_OPTION_IDLE)
		label.text = str(_options[index].get("label", ""))
		label.clip_text = true
		_option_labels.append(label)
		var desc := _make_label(OPTION_DESC_FONT_SIZE, COLOR_DESC_IDLE)
		desc.text = str(_options[index].get("desc", ""))
		desc.clip_text = true
		_option_descs.append(desc)


func _clear_option_nodes() -> void:
	for label in _option_labels:
		label.visible = false
		label.queue_free()
	for label in _option_descs:
		label.visible = false
		label.queue_free()
	_option_labels.clear()
	_option_descs.clear()


func _normalize_options(raw_options: Array) -> Array:
	var normalized: Array = []
	for entry in raw_options:
		if entry is Dictionary:
			normalized.append({
				"id": str(entry.get("id", "")),
				"label": str(entry.get("label", "")),
				"desc": str(entry.get("desc", "")),
			})
		else:
			normalized.append({"id": str(entry), "label": str(entry), "desc": ""})
	return normalized


# =============================================================================
# 布局（所有坐标取整，像素硬边）
# =============================================================================

func _viewport_size() -> Vector2:
	if _layout_override != Vector2.ZERO:
		return _layout_override
	if is_inside_tree():
		return get_viewport_rect().size
	return Vector2(1280, 720)


func _layout() -> void:
	var viewport := _viewport_size()
	if is_inside_tree():
		# 同时兼容 Node2D / CanvasLayer / 视口直接挂载：组件固定在视口原点。
		position = Vector2.ZERO
		size = get_viewport_rect().size
	var panel_height := PANEL_HEIGHT
	if state == State.CHOICES:
		panel_height = maxi(PANEL_HEIGHT, 108 + OPTION_ROW_HEIGHT * _options.size())
	var panel_width := maxf(320.0, floorf(viewport.x) - 2.0 * SIDE_MARGIN)
	var panel_x := float(SIDE_MARGIN)
	var panel_y := floorf(viewport.y) - float(BOTTOM_MARGIN) - float(panel_height)
	_panel_rect = Rect2(panel_x, panel_y, panel_width, float(panel_height))

	# 名字牌：叠在面板左上，宽度随名字。
	var plate_width := 96.0
	if _font != null and not _speaker.is_empty():
		plate_width = maxf(96.0, ceilf(_font.get_string_size(
			_speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE).x) + 40.0)
	_nameplate_rect = Rect2(panel_x + 28.0, panel_y - 22.0, plate_width, float(NAME_PLATE_HEIGHT))
	_name_label.position = Vector2(panel_x + 44.0, panel_y - 17.0)
	_name_label.size = Vector2(plate_width - 28.0, 34.0)

	# 正文：名字牌下方，右下留出 ▼ 的位置。
	_body_rect = Rect2(panel_x + 32.0, panel_y + 34.0, panel_width - 96.0, float(panel_height - 64))
	_body_label.position = _body_rect.position
	_body_label.size = _body_rect.size

	# 右下 12px 操作提示（宽度取整，保证像素对齐）。
	var hint_width := floorf(maxf(240.0, panel_width * 0.55))
	_hint_rect = Rect2(panel_x + panel_width - 28.0 - hint_width, panel_y + float(panel_height) - 26.0,
		hint_width, float(HINT_LINE_HEIGHT))
	_hint_label.position = _hint_rect.position
	_hint_label.size = _hint_rect.size

	# 选项页：提示语（最多两行）+ 两行选项。
	_prompt_rect = Rect2(panel_x + 32.0, panel_y + 10.0, panel_width - 64.0, 68.0)
	_prompt_label.position = _prompt_rect.position
	_prompt_label.size = _prompt_rect.size

	_option_rects.clear()
	for index in _options.size():
		var row_y := panel_y + float(OPTION_TOP_PAD) + float(index * OPTION_ROW_HEIGHT)
		_option_rects.append(Rect2(panel_x + 24.0, row_y - 2.0, panel_width - 48.0, 38.0))
		if index >= _option_labels.size():
			continue
		var label := _option_labels[index]
		label.position = Vector2(panel_x + 72.0, row_y)
		label.size = Vector2(panel_width - 104.0, float(OPTION_ROW_HEIGHT))
		var measured := 0.0
		if _font != null:
			measured = ceilf(_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				OPTION_FONT_SIZE).x)
		if index < _option_descs.size():
			var desc := _option_descs[index]
			var desc_x := panel_x + 72.0 + measured + 20.0
			desc.position = Vector2(desc_x, row_y + 16.0)
			desc.size = Vector2(maxf(80.0, panel_x + panel_width - 28.0 - desc_x), float(HINT_LINE_HEIGHT))
	queue_redraw()


func _apply_mode_visibility() -> void:
	var line_mode := state == State.REVEALING or state == State.WAITING
	if _name_label != null:
		_name_label.visible = line_mode and not _speaker.is_empty()
	if _body_label != null:
		_body_label.visible = line_mode
	if _hint_label != null:
		_hint_label.visible = state != State.CLOSED
	if _prompt_label != null:
		_prompt_label.visible = state == State.CHOICES
	for index in _option_labels.size():
		var shown := state == State.CHOICES and index < _options.size()
		_option_labels[index].visible = shown
		if index < _option_descs.size():
			_option_descs[index].visible = shown


func _update_hint() -> void:
	if _hint_label == null:
		return
	match state:
		State.REVEALING:
			_hint_label.text = "E / 回车 / 空格 / 左键 显示全部　　Tab 跳过本段"
		State.WAITING:
			_hint_label.text = "E / 回车 / 空格 / 左键 继续　　Tab 跳过本段"
		State.CHOICES:
			_hint_label.text = "W / S 选择　　E / 回车 / 左键 确认"
		_:
			_hint_label.text = ""


func _refresh_choices() -> void:
	var index := clampi(_selected_index, 0, maxi(_options.size() - 1, 0))
	for i in _option_labels.size():
		var active := i == index
		_option_labels[i].add_theme_color_override("font_color",
			COLOR_OPTION_ACTIVE if active else COLOR_OPTION_IDLE)
		if i < _option_descs.size():
			_option_descs[i].add_theme_color_override("font_color",
				COLOR_DESC_ACTIVE if active else COLOR_DESC_IDLE)
	queue_redraw()


func _on_viewport_size_changed() -> void:
	if _layout_override != Vector2.ZERO:
		return
	_layout()


# =============================================================================
# 绘制（全部整数像素矩形，无圆角/渐变/抗锯齿）
# =============================================================================

func _draw() -> void:
	if state == State.CLOSED:
		return
	_draw_count += 1
	_draw_panel()
	if state == State.CHOICES:
		_draw_choice_decor()
		return
	if not _speaker.is_empty():
		_draw_nameplate()
	if state == State.WAITING and _arrow_on:
		_draw_arrow()


func _draw_panel() -> void:
	draw_rect(_panel_rect, COLOR_PANEL_BLACK)
	var inner := Rect2(_panel_rect.position + Vector2(2.0, 2.0), _panel_rect.size - Vector2(4.0, 4.0))
	draw_rect(inner, COLOR_PANEL_BG)
	_draw_pixel_outline(inner, COLOR_EDGE_WARM, 1.0)
	# 四角像素装饰：2px 金线短臂。
	var arm := 10.0
	var thick := 2.0
	var corners: Array[Vector2] = [
		inner.position + Vector2(6.0, 6.0),
		inner.position + Vector2(inner.size.x - 16.0, 6.0),
		inner.position + Vector2(6.0, inner.size.y - 8.0),
		inner.position + Vector2(inner.size.x - 16.0, inner.size.y - 8.0),
	]
	for origin in corners:
		draw_rect(Rect2(origin.x, origin.y, arm, thick), COLOR_CORNER)
		draw_rect(Rect2(origin.x, origin.y, thick, arm), COLOR_CORNER)


func _draw_nameplate() -> void:
	var rect := _nameplate_rect
	draw_rect(rect, COLOR_PANEL_BLACK)
	var inner := Rect2(rect.position + Vector2(2.0, 2.0), rect.size - Vector2(4.0, 4.0))
	draw_rect(inner, COLOR_NAME_BG)
	_draw_pixel_outline(inner, COLOR_EDGE_WARM, 1.0)
	# 左侧说话人色条。
	draw_rect(Rect2(rect.position.x + 8.0, rect.position.y + 9.0, 3.0, rect.size.y - 18.0),
		speaker_color(_speaker))


func _draw_arrow() -> void:
	var base_x := floorf(_panel_rect.end.x) - 52.0
	var base_y := floorf(_panel_rect.end.y) - 46.0
	var widths := [9, 9, 7, 5, 3, 1]
	for row in widths.size():
		var width: int = widths[row]
		draw_rect(Rect2(base_x + float(9 - width) * 0.5, base_y + float(row), float(width), 1.0),
			COLOR_ARROW)


func _draw_choice_decor() -> void:
	if _option_rects.is_empty():
		return
	var index := clampi(_selected_index, 0, _option_rects.size() - 1)
	var row_y := _panel_rect.position.y + float(OPTION_TOP_PAD) + float(index * OPTION_ROW_HEIGHT)
	# 选中行：平铺极低透明度暖色块 + ▶ 像素光标。
	draw_rect(Rect2(_panel_rect.position.x + 36.0, row_y + 1.0, _panel_rect.size.x - 72.0, 32.0),
		Color(1.0, 0.88, 0.62, 0.055))
	var cursor_x := _panel_rect.position.x + 46.0
	var cursor_y := row_y + 12.0
	for column in 4:
		draw_rect(Rect2(cursor_x + float(column), cursor_y + float(column), 1.0,
			9.0 - float(column) * 2.0), COLOR_OPTION_ACTIVE)
	# 提示语下方 1px 像素分隔线。
	draw_rect(Rect2(_prompt_rect.position.x, _prompt_rect.end.y - 6.0, _prompt_rect.size.x, 1.0),
		Color(COLOR_EDGE_WARM.r, COLOR_EDGE_WARM.g, COLOR_EDGE_WARM.b, 0.28))


func _draw_pixel_outline(rect: Rect2, color: Color, thickness: float) -> void:
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, thickness), color)
	draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y - thickness, rect.size.x, thickness), color)
	draw_rect(Rect2(rect.position.x, rect.position.y + thickness, thickness,
		rect.size.y - 2.0 * thickness), color)
	draw_rect(Rect2(rect.position.x + rect.size.x - thickness, rect.position.y + thickness,
		thickness, rect.size.y - 2.0 * thickness), color)
