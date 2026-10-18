extends "res://scripts/campaign.gd"
## Dev-only G4-009 screenshots. Not referenced by boot.tscn.

func _ready() -> void:
	super._ready()
	saves.directory = ProjectSettings.globalize_path("res://").path_join("../qa/runtime-profile/capture-g4-009").simplify_path()
	call_deferred("tour")

func shot(name: String, frames: int = 6) -> void:
	for i in frames: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var base := ProjectSettings.globalize_path("res://").path_join("../qa/evidence/G4/").simplify_path()
	var path := base.path_join("G4-009-"+name+".png")
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print("G4_009_SHOT ",name," ",path," err=",err," size=",image.get_size())

func prepare(node: String) -> void:
	for id in progress.flag_ids: progress.flags[id] = true
	progress.node_id = node
	load_room()
	combat.hp = 1000
	combat.enemies.clear()
	paused = true
	world.queue_redraw()
	objects_layer.queue_redraw()
	ui_layer.queue_redraw()

func tour() -> void:
	print("G4_009_CAPTURE start")
	await shot("title")
	new_game()
	await shot("camp")
	print("G4_009_CAPTURE title")
	prepare("N0-02")
	combat.player = Vector2(150,100)
	combat.facing = Vector2.RIGHT
	combat.action = "idle"
	combat.age = 0
	world.queue_redraw()
	ui_layer.queue_redraw()
	await shot("flame")
	combat.clear_hazards()
	combat.enemies.clear()
	combat.focus = 100
	combat.action = "idle"
	combat.age = 0
	combat.begin("light",Vector2.ZERO,Vector2.RIGHT)
	for i in 13: combat.step(Vector2.ZERO,Vector2.RIGHT)
	handle_visual_events()
	update_screen_shake()
	world.queue_redraw()
	ui_layer.queue_redraw()
	await shot("light")
	for i in 9: combat.step(Vector2.ZERO,Vector2.RIGHT)
	world.queue_redraw()
	ui_layer.queue_redraw()
	await shot("light-linger")
	prepare("N1-02")
	combat.player = Vector2(190,110)
	world.queue_redraw()
	objects_layer.queue_redraw()
	ui_layer.queue_redraw()
	await shot("lightroom")
	prepare("N1-07")
	combat.player = Vector2(90,110)
	world.queue_redraw()
	objects_layer.queue_redraw()
	ui_layer.queue_redraw()
	await shot("room-n1-07")
	prepare("N2-08")
	combat.player = Vector2(105,110)
	world.queue_redraw()
	objects_layer.queue_redraw()
	ui_layer.queue_redraw()
	await shot("room-n2-08")
	print("G4_009_CAPTURE done")
	combat_audio.stop_all()
	get_tree().quit()
