extends RefCounted

var low_effects := false
var reduced_motion := false
var reduced_flash := false
var sfx_volume := 0.8
var path: String = preload("res://scripts/user_storage.gd").directory()+"presentation.cfg"

func read_settings() -> Error:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK: return error
	low_effects = bool(config.get_value("display","low_effects",false))
	reduced_motion = bool(config.get_value("display","reduced_motion",false))
	reduced_flash = bool(config.get_value("display","reduced_flash",false))
	sfx_volume = clampf(float(config.get_value("audio","sfx_volume",0.8)),0,1)
	return OK

func write_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("display","low_effects",low_effects)
	config.set_value("display","reduced_motion",reduced_motion)
	config.set_value("display","reduced_flash",reduced_flash)
	config.set_value("audio","sfx_volume",sfx_volume)
	return config.save(path)
