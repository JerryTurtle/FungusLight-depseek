extends Node

var clock := 0.0
var actors: Array[Sprite2D] = []
var direction_label: Label

func _ready() -> void:
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/NotoSansSC.ttf")
	ThemeDB.fallback_font = theme.default_font
	var background := ColorRect.new()
	background.color = Color("111d22")
	background.size = Vector2(1280, 720)
	add_child(background)
	var title := Label.new()
	title.text = "菌灯之下  /  G0 素材与工程验证"
	title.position = Vector2(72, 44)
	title.add_theme_font_size_override("font_size", 32)
	add_child(title)
	var description := Label.new()
	description.text = "守灯人 · 岚     原图 16 × 32 / 脚底锚点 (8,31) / 最近邻 4 倍\n四向行走切片验证 · 下 / 左 / 右 / 上     尚未进入动作审核"
	description.position = Vector2(72, 108)
	description.add_theme_font_size_override("font_size", 22)
	add_child(description)
	var tex := load("res://assets/original/Characters/Cleric.png") as Texture2D
	for row in range(4):
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.region_enabled = true
		sprite.centered = false
		sprite.offset = Vector2(-8, -31)
		sprite.region_rect = Rect2(16, row * 32, 16, 32)
		sprite.position = Vector2(260 + row * 240, 400)
		sprite.scale = Vector2(4, 4)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		actors.append(sprite)
		var caption := Label.new()
		caption.text = ["向下", "向左", "向右", "向上"][row]
		caption.position = sprite.position + Vector2(-24, 35)
		caption.add_theme_font_size_override("font_size", 24)
		add_child(caption)
		var line := Line2D.new()
		line.points = PackedVector2Array([sprite.position + Vector2(-60, 0), sprite.position + Vector2(60, 0)])
		line.default_color = Color("77c3a2")
		line.width = 1
		add_child(line)
	direction_label = Label.new()
	direction_label.position = Vector2(72, 570)
	direction_label.add_theme_font_size_override("font_size", 22)
	add_child(direction_label)
	print("G0_READY | Godot ", Engine.get_version_info().string, " | actors=4 | build=G0-001")
	print("USER_DIR ", OS.get_user_data_dir())
	var probe := FileAccess.open("user://write_probe.txt", FileAccess.WRITE)
	if probe:
		probe.store_string("G0 persistence probe")
		probe.close()
		print("USER_WRITE_OK")
	else:
		print("USER_WRITE_FAILED ", FileAccess.get_open_error())
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var path := OS.get_environment("FUNGUS_CAPTURE")
		if not path.is_empty():
			var result := get_viewport().get_texture().get_image().save_png(path)
			print("G0_CAPTURE ", result)

func _process(delta: float) -> void:
	clock += delta
	var frame: int = [1, 0, 1, 2][int(clock * 7) % 4]
	for row in range(actors.size()):
		actors[row].region_rect.position.x = frame * 16
	direction_label.text = "G0-001    •    Compatibility    •    60 Hz 物理\n开发验证版本，非完整游戏。Esc 退出。"
	if Input.is_physical_key_pressed(KEY_ESCAPE):
		get_tree().quit()
