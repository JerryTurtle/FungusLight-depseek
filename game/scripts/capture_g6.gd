extends "res://scripts/campaign.gd"
## Dev-only G6 release screens. Not referenced by boot.tscn.

func _ready() -> void:
	super._ready()
	saves.directory = ProjectSettings.globalize_path("res://").path_join("../qa/runtime-profile/capture-g6").simplify_path()
	call_deferred("tour")

func shot(name: String, frames: int = 6) -> void:
	for i in frames: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var base := ProjectSettings.globalize_path("res://").path_join("../qa/evidence/G6/").simplify_path()
	var path := base.path_join("G6-002-"+name+".png")
	var image := get_viewport().get_texture().get_image()
	print("G6_SHOT ",path," err=",image.save_png(path))

func tour() -> void:
	show_title()
	await shot("title")
	open_settings("title")
	await shot("settings")
	on_settings_closed()
	show_load_menu()
	await shot("load-empty")
	show_title()
	new_game()
	wake_left = 0
	hide_player = false
	show_pause()
	await shot("pause")
	resume()
	combat.hp = 0
	paused = false
	running = true
	_physics_process(1.0/60.0)
	await shot("death")
	show_title()
	new_game()
	wake_left = 0
	hide_player = false
	progress.flags["E30"] = true
	progress.flags["S11"] = true
	progress.node_id = "N4-06"
	load_room()
	choice_mode = "ending"
	choose_ending("restore")
	show_credits()
	await shot("credits")
	combat_audio.stop_all()
	get_tree().quit()
