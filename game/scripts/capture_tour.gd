extends "res://scripts/campaign.gd"
## Dev-only capture tour for G3 evidence screenshots. Not referenced by boot.tscn.

func _ready() -> void:
	super._ready()
	saves.directory = ProjectSettings.globalize_path("res://").path_join("../qa/runtime-profile/capture-tour").simplify_path()
	call_deferred("tour")

func shot(base: String, name: String, frames: int = 8) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(base + name + ".png")

func clear_enemies() -> void:
	for enemy in combat.enemies: enemy.hp = 0
	for i in 3:
		await get_tree().physics_frame

func tour() -> void:
	var base := ProjectSettings.globalize_path("res://").path_join("../qa/local/cap-").simplify_path()
	await shot(base,"title")
	new_game()
	await shot(base,"camp")
	combat.player = Vector2(88,100)
	interact()
	dialogue.reveal_all()
	await shot(base,"dialog-s01")
	finish_dialogue()
	progress.flags.S01 = true
	progress.flags.S02 = true
	progress.flags.tutorial = true
	progress.flags.E01 = true
	show_growth_choice()
	await shot(base,"choice-m1")
	choice_pending = false
	dialogue.close()
	resume()
	progress.node_id = "N0-02"
	load_room()
	await shot(base,"storage")
	progress.flags.pipe = true
	progress.flags.S03 = true
	progress.flags.E02 = true
	progress.node_id = "N0-04"
	load_room()
	await shot(base,"mine-corridor")
	await clear_enemies()
	await shot(base,"mine-corridor-clear")
	combat.player = Vector2(290,85)
	interact()
	await shot(base,"mine-entrance")
	await clear_enemies()
	combat.player = Vector2(292,120)
	interact()
	await shot(base,"light-room-enemies")
	await clear_enemies()
	await shot(base,"light-room-pods")
	await clear_enemies()
	await shot(base,"light-room-unsolved")
	for guide in progress.guides():
		guide_dirs[guide.id] = int(guide.solution)
	await shot(base,"light-room-solved")
	progress.flags.P02 = true
	await shot(base,"light-room-open")
	begin_lore("L01")
	dialogue.reveal_all()
	await shot(base,"dialog-lore")
	finish_dialogue()
	combat_audio.stop_all()
	print("CAPTURE_TOUR_DONE ",base)
	get_tree().quit()
