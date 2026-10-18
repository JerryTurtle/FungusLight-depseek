extends Control
signal dismissed
signal changed
var preferences
var save_label: Label
var controls: Dictionary = {}
var volume_slider: HSlider

func _ready() -> void:
	size = Vector2(1280,720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.size = size
	shade.color = Color(0.015,0.03,0.04,0.94)
	add_child(shade)
	var box := VBoxContainer.new()
	box.position = Vector2(380,50)
	box.size = Vector2(520,620)
	box.add_theme_constant_override("separation",18)
	box.add_theme_font_size_override("font_size",24)
	add_child(box)
	var title := Label.new()
	title.text = "画面与声音设置"
	title.add_theme_font_size_override("font_size",36)
	box.add_child(title)
	for item in [["全屏窗口","fullscreen"],["低特效（保留全部危险预告）","low_effects"],["减少动态（关闭碎片飞散）","reduced_motion"],["降低闪光（保留命中轮廓）","reduced_flash"],["开启震屏（重击/阶段反馈）","shake_enabled"]]:
		var checkbox := CheckButton.new()
		checkbox.text = item[0]
		checkbox.button_pressed = preferences.get(item[1])
		var field: String = item[1]
		controls[field] = checkbox
		checkbox.toggled.connect(func(value):
			preferences.set(field,value)
			if field == "fullscreen": preferences.apply_display()
			persist())
		box.add_child(checkbox)
	var volume_label := Label.new()
	volume_label.text = "音效音量（最左为静音）"
	box.add_child(volume_label)
	var slider := HSlider.new()
	volume_slider = slider
	slider.max_value = 100
	slider.value = preferences.sfx_volume*100
	slider.custom_minimum_size.y = 32
	slider.value_changed.connect(func(value):
		preferences.sfx_volume = value/100.0
		persist())
	box.add_child(slider)
	var controls_label := Label.new()
	controls_label.text = "操作：WASD/方向键移动 · E 交互 · Q 观察 · R 治疗 · 空格闪避\n左键灯击 · 右键净光 · 1/2 护灯/灯雨 · Esc 暂停"
	controls_label.add_theme_font_size_override("font_size",16)
	controls_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(controls_label)
	save_label = Label.new()
	save_label.text = "设置保存在用户目录；当前战斗已暂停。"
	save_label.add_theme_font_size_override("font_size",18)
	box.add_child(save_label)
	var close := Button.new()
	close.text = "返回（F1 / Esc）"
	close.custom_minimum_size.y = 48
	close.pressed.connect(func(): dismissed.emit())
	box.add_child(close)
	hide()

func persist() -> void:
	var error: Error = preferences.write_settings()
	save_label.text = "设置已保存" if error == OK else "保存失败；本次运行仍使用当前设置（%d）" % error
	changed.emit()
