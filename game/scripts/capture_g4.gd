extends "res://scripts/campaign.gd"
## Dev-only G4 screenshots. Not referenced by boot.tscn.

func _ready() -> void:
	super._ready()
	saves.directory = ProjectSettings.globalize_path("res://").path_join("../qa/runtime-profile/capture-g4").simplify_path()
	call_deferred("tour")

func shot(name: String, frames: int = 8) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://").path_join("../qa/local/g4cap-"+name+".png").simplify_path())

func load_state(node: String, boss: bool = false) -> void:
	for id in progress.flag_ids: progress.flags[id] = true
	for id in ["M1","M2","M3","M4"]: progress.choices[id] = {"M1":"melee","M2":"echo","M3":"rain","M4":"ward"}[id]
	progress.choice = "melee"
	progress.flags.E30 = not boss
	progress.flags.S10 = false
	progress.flags.S11 = false
	progress.flags.END_RESTORE = false
	progress.flags.END_SEAL = false
	progress.node_id = node
	load_room()

func tour() -> void:
	new_game()
	load_state("N2-01")
	combat.player = Vector2(160,110)
	await shot("branch")
	load_state("N1-06")
	combat.player = Vector2(160,110)
	await shot("rootbridge")
	load_state("N3-05")
	combat.player = Vector2(160,110)
	await shot("court")
	load_state("N4-06", true)
	combat.player = Vector2(120,110)
	await shot("boss")
	var boss: Dictionary = combat.enemies.filter(func(e): return e.get("archetype","") == "BOSS")[0]
	boss.hp = boss.max_hp * 0.7
	combat.step(Vector2.ZERO,Vector2.RIGHT)
	await shot("boss-phase")
	boss.hp = 0
	_physics_process(1.0/60.0)
	await shot("ending")
