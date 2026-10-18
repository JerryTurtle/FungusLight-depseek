extends "res://scripts/campaign.gd"
## Dev-only VFX screenshots; not referenced by boot.tscn.

func _ready() -> void:
	super._ready()
	saves.directory = ProjectSettings.globalize_path("res://").path_join("../qa/runtime-profile/capture-fx").simplify_path()
	call_deferred("tour")

func shot(name: String, frames: int = 4) -> void:
	for i in frames: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://").path_join("../qa/local/fx-"+name+".png").simplify_path())

func setup(node: String) -> void:
	for id in progress.flag_ids: progress.flags[id] = true
	progress.flags.S02 = true
	progress.flags.M1 = true
	progress.choices.M1 = "melee"
	progress.choice = "melee"
	progress.node_id = node
	load_room()

func tour() -> void:
	new_game()
	set_physics_process(false)
	setup("N0-02")
	combat.hp = 1000
	combat.focus = 100
	combat.enemies.clear()
	combat.player = Vector2(150,100)
	combat.focus = 100
	var target: Dictionary = combat.add_enemy(Vector2(230,100),true)
	target.hp = 1000
	combat.begin("light",Vector2.ZERO,Vector2.RIGHT)
	for i in 14: combat.step(Vector2.ZERO,Vector2.RIGHT)
	world.queue_redraw()
	objects_layer.queue_redraw()
	ui_layer.queue_redraw()
	await shot("light",2)
	for i in 40: combat.step(Vector2.ZERO,Vector2.RIGHT)
	combat.hp = 1000
	combat.enemies.clear()
	combat.player = Vector2(150,100)
	target = combat.add_enemy(Vector2(172,100),true)
	target.hp = 1000
	combat.begin("melee",Vector2.ZERO,Vector2.RIGHT)
	for i in 8: combat.step(Vector2.ZERO,Vector2.RIGHT)
	world.queue_redraw()
	objects_layer.queue_redraw()
	ui_layer.queue_redraw()
	await shot("melee",2)
	setup("N0-01")
	combat.player = Vector2(130,130)
	world.queue_redraw()
	objects_layer.queue_redraw()
	ui_layer.queue_redraw()
	await shot("wounded",2)
	get_tree().quit()
