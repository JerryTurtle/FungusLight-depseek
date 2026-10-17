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

func wait_frames(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame

func clear_enemies() -> void:
	for enemy in combat.enemies: enemy.hp = 0
	await wait_frames(4)

func tour() -> void:
	var base := ProjectSettings.globalize_path("res://").path_join("../qa/local/cap-").simplify_path()
	await shot(base,"title")
	new_game()
	await shot(base,"camp")
	for flag in ["S01","S02","tutorial","E01","M1","pipe"]: progress.flags[flag] = true
	progress.node_id = "N0-02"
	load_room()
	await shot(base,"storage")
	progress.node_id = "N0-03"
	load_room()
	combat.player = Vector2(190,104)
	await shot(base,"rong")
	progress.flags.S03 = true
	progress.flags.E02 = true
	progress.flags.E03 = true
	progress.node_id = "N1-01"
	load_room()
	await clear_enemies()
	combat.player = Vector2(262,132)
	await shot(base,"lore-exit")
	progress.flags.E04 = true
	progress.node_id = "N1-02"
	load_room()
	await clear_enemies()
	await clear_enemies()
	await wait_frames(25)
	await shot(base,"corpse-visible")
	await wait_frames(230)
	await shot(base,"corpse-gone")
	await shot(base,"guides-unsolved")
	for guide in progress.guides():
		guide_dirs[guide.id] = int(guide.solution)
	await shot(base,"guides-solved")
	begin_lore("L01")
	dialogue.reveal_all()
	await shot(base,"dialog-lore")
	finish_dialogue()
	show_growth_choice()
	await shot(base,"choice-m1")
	choice_pending = false
	dialogue.close()
	resume()
	combat_audio.stop_all()
	print("CAPTURE_TOUR_DONE ",base)
	get_tree().quit()
