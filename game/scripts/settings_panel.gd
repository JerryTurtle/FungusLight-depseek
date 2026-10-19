extends Control
signal dismissed
signal changed
var preferences
var controls: Dictionary = {}
var volume_slider: HSlider

func _ready() -> void:
	size = Vector2(1280,720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.size = size
	shade.color = Color(0.015,0.03,0.04,0.86)
	add_child(shade)
	var box := VBoxContainer.new()
	box.position = Vector2(470,170)
	box.size = Vector2(340,330)
	box.add_theme_constant_override("separation",8)
	box.add_theme_font_size_override("font_size",16)
	add_child(box)
	var title := Label.new()
	title.text = "设置"
	title.add_theme_font_size_override("font_size",24)
	box.add_child(title)
	for item in [["全屏","fullscreen"],["低特效","low_effects"],["减少动态","reduced_motion"],["降低闪光","reduced_flash"],["屏幕震动","shake_enabled"]]:
		var checkbox := CheckButton.new()
		checkbox.text = item[0]
		checkbox.add_theme_font_size_override("font_size",16)
		checkbox.custom_minimum_size.y = 24
		checkbox.button_pressed = preferences.get(item[1])
		var field: String = item[1]
		controls[field] = checkbox
		checkbox.toggled.connect(func(value):
			preferences.set(field,value)
			if field == "fullscreen": preferences.apply_display()
			persist())
		box.add_child(checkbox)
	var volume_label := Label.new()
	volume_label.text = "音效 / 音乐"
	volume_label.add_theme_font_size_override("font_size",16)
	box.add_child(volume_label)
	var slider := HSlider.new()
	volume_slider = slider
	slider.max_value = 100
	slider.value = preferences.sfx_volume*100
	slider.custom_minimum_size.y = 20
	slider.value_changed.connect(func(value):
		preferences.sfx_volume = value/100.0
		persist())
	box.add_child(slider)
	var close := Button.new()
	close.text = "返回"
	close.add_theme_font_size_override("font_size",16)
	close.custom_minimum_size.y = 32
	close.pressed.connect(func(): dismissed.emit())
	box.add_child(close)
	hide()

func persist() -> void:
	preferences.write_settings()
	changed.emit()
