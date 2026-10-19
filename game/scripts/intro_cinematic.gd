class_name IntroCinematic
extends Control
## Five-panel opening cinematic for 《菌灯之下》.
##
## The opening is presentation-only: it never changes campaign progress. It can
## be skipped with Esc, advanced with Enter/Space/left click, and always emits
## `finished` exactly once. The campaign decides whether to start the run or
## return to the title after the signal.

signal finished

const FONT := preload("res://assets/fonts/FusionPixel12px-zh_hans.ttf")
const SCENES := [
	{
		"image": preload("res://assets/intro/scene_01_cavern.png"),
		"chapter": "第一幕 · 灯与根",
		"text": "地下三百尺，避难所靠菌灯活着。\n灯根喝水，灯线发光；人和根，共用一条水脉。",
	},
	{
		"image": preload("res://assets/intro/scene_02_pumps.png"),
		"chapter": "第二幕 · 旧约",
		"text": "三百年前，逃难的人与地下的菌王立约：\n人取水，要给根留光；根供水，要给人留路。",
	},
	{
		"image": preload("res://assets/intro/scene_03_drought.png"),
		"chapter": "第三幕 · 水少了",
		"text": "后来水少了。泵站整夜响，井绳一天比一天短。\n有人说禾把水泵推过了红线；也有人说，根先堵了水管。",
	},
	{
		"image": preload("res://assets/intro/scene_04_keeper.png"),
		"chapter": "第四幕 · 最后一盏",
		"text": "菌群开始攻击，营地只剩最后一盏灯。\n守灯人岚提灯下到旧矿道，要查清：水到底断在哪一步。",
	},
	{
		"image": preload("res://assets/intro/scene_05_core.png"),
		"chapter": "第五幕 · 灯根",
		"text": "旧约说，灯与根同饮一脉水。\n如今水快干了，最后一条路在灯根之下。",
	},
]

var index := -1
var playing := false
var final_hint := "进入营地"
var auto_left := 0.0
var _finished := false
var _bg: TextureRect
var _shade: ColorRect
var _chapter: Label
var _text: Label
var _hint: Label
var _dots: Label
var _title: Label
var _scene_root: Control

func _ready() -> void:
	size = Vector2(1280, 720)
	position = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_scene_root = Control.new()
	_scene_root.position = Vector2.ZERO
	_scene_root.size = Vector2(1280, 720)
	_scene_root.clip_contents = true
	add_child(_scene_root)
	_bg = TextureRect.new()
	_bg.position = Vector2(-22, -12)
	_bg.size = Vector2(1280, 720)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bg.pivot_offset = Vector2(640, 360)
	_bg.scale = Vector2(1.035, 1.035)
	_scene_root.add_child(_bg)
	# Vignette + subtitle bed. The vignette is the same deep teal as the world.
	var vignette := ColorRect.new()
	vignette.position = Vector2.ZERO
	vignette.size = Vector2(1280, 720)
	vignette.color = Color(0.012, 0.026, 0.027, 0.30)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)
	var lower := ColorRect.new()
	lower.position = Vector2(0, 500)
	lower.size = Vector2(1280, 220)
	lower.color = Color(0.01, 0.022, 0.023, 0.66)
	lower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lower)
	_shade = ColorRect.new()
	_shade.position = Vector2.ZERO
	_shade.size = Vector2(1280, 720)
	_shade.color = Color(0.005, 0.012, 0.012, 0.0)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_title = _label("菌灯之下", 36, Color(0.93, 0.82, 0.55, 1.0))
	_title.position = Vector2(76, 54)
	_title.add_theme_constant_override("outline_size", 6)
	_title.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.02, 0.95))
	add_child(_title)
	_chapter = _label("", 20, Color(0.90, 0.76, 0.46, 1.0))
	_chapter.position = Vector2(78, 106)
	_chapter.add_theme_constant_override("outline_size", 4)
	_chapter.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.02, 0.95))
	add_child(_chapter)
	_text = _label("", 24, Color(0.95, 0.91, 0.79, 1.0))
	_text.position = Vector2(140, 548)
	_text.size = Vector2(1000, 92)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_constant_override("outline_size", 5)
	_text.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.02, 0.98))
	add_child(_text)
	_hint = _label("回车 / 空格 / 左键 继续    Esc 跳过", 16, Color(0.64, 0.65, 0.55, 0.95))
	_hint.position = Vector2(900, 684)
	_hint.size = Vector2(350, 24)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_constant_override("outline_size", 3)
	_hint.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.02, 0.95))
	add_child(_hint)
	_dots = _label("", 20, Color(0.80, 0.64, 0.36, 1.0))
	_dots.position = Vector2(78, 676)
	_dots.size = Vector2(300, 30)
	add_child(_dots)

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func play() -> void:
	_finished = false
	playing = true
	index = -1
	visible = true
	_title.modulate.a = 1.0
	_chapter.modulate.a = 1.0
	_text.modulate.a = 1.0
	_show_scene(0)

func _show_scene(next_index: int) -> void:
	index = clampi(next_index, 0, SCENES.size() - 1)
	var scene: Dictionary = SCENES[index]
	_bg.texture = scene.image
	_bg.scale = Vector2(1.035, 1.035)
	_bg.position = Vector2(-22, -12)
	_chapter.text = str(scene.chapter)
	_text.text = str(scene.text)
	_hint.text = "回车 / 空格 / 左键 继续    Esc 跳过" if index < SCENES.size() - 1 else "回车 / 空格 / 左键 "+final_hint+"    Esc 跳过"
	_dots.text = "  ".join(range(SCENES.size()).map(func(i): return "●" if i == index else "○"))
	# Fade from black, with a slow push-in that keeps the pixel art crisp.
	_shade.color = Color(0.005, 0.012, 0.012, 0.92)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_shade, "color:a", 0.0, 0.65).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_bg, "scale", Vector2(1.075, 1.075), 7.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_bg, "position", Vector2(-48, -26), 7.2).set_trans(Tween.TRANS_SINE)
	auto_left = 7.2

func next() -> void:
	if not playing:
		return
	if index >= SCENES.size() - 1:
		_finish()
		return
	_show_scene(index + 1)

func skip() -> void:
	if not playing:
		return
	_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	playing = false
	auto_left = 0.0
	var tween := create_tween()
	tween.tween_property(_shade, "color:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		visible = false
		finished.emit())

func _process(delta: float) -> void:
	if not playing or not visible:
		return
	auto_left -= delta
	if auto_left <= 0.0:
		next()

func handle_input(event: InputEvent) -> bool:
	if not playing:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			skip()
			return true
		if event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			next()
			return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		next()
		return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if playing:
		handle_input(event)
