extends RefCounted

const Compat = preload("res://scripts/compat.gd")

var low_effects := false
var reduced_motion := false
var reduced_flash := false
var shake_enabled := true
var fullscreen := false
var sfx_volume := 0.8
var path: String = preload("res://scripts/user_storage.gd").directory()+"presentation.cfg"

func read_settings() -> Error:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK:
		# First launch: keep old dual-core / pre-2012 iGPU machines playable
		# without hiding the options; saving the panel persists the choice.
		Compat.apply_low_end_defaults(self)
		apply_display()
		return error
	low_effects = bool(config.get_value("display","low_effects",false))
	reduced_motion = bool(config.get_value("display","reduced_motion",false))
	reduced_flash = bool(config.get_value("display","reduced_flash",false))
	shake_enabled = bool(config.get_value("display","shake_enabled",true))
	fullscreen = bool(config.get_value("display","fullscreen",false))
	sfx_volume = clampf(float(config.get_value("audio","sfx_volume",0.8)),0,1)
	apply_display()
	return OK

func apply_display() -> void:
	if DisplayServer.get_name() == "headless": return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	var usable := DisplayServer.screen_get_usable_rect()
	var size := Compat.fit_window_size(Vector2i(1280,720), usable.size)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	if usable.size.x > 0 and usable.size.y > 0:
		DisplayServer.window_set_position(usable.position + Vector2i(
			(usable.size.x - size.x) / 2,
			(usable.size.y - size.y) / 2
		))

func write_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("display","low_effects",low_effects)
	config.set_value("display","reduced_motion",reduced_motion)
	config.set_value("display","reduced_flash",reduced_flash)
	config.set_value("display","shake_enabled",shake_enabled)
	config.set_value("display","fullscreen",fullscreen)
	config.set_value("audio","sfx_volume",sfx_volume)
	return config.save(path)
