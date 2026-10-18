extends SceneTree
## Regression: dying in chapter-2 branch B must retry the current room, not
## restart the hub/branch selection. This uses the same room checkpoint that
## the game restores from the death overlay.
var scene
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	scene = load("res://scenes/campaign.tscn").instantiate()
	get_root().add_child(scene)
	await process_frame
	scene.new_game()
	await process_frame
	for flag in scene.progress.flag_ids:
		scene.progress.flags[flag] = true
	scene.progress.flags.E16 = false
	scene.progress.flags.E17 = false
	scene.progress.choices.M1 = "melee"
	scene.progress.choices.M2 = "guard"
	scene.progress.choices.M3 = "focus"
	scene.progress.choices.M4 = "step"
	scene.progress.choice = "melee"
	scene.progress.flags.BRANCH_B = true
	scene.progress.node_id = "N2-04"
	scene.load_room()
	await process_frame
	check(scene.progress.node_id == "N2-04", "entered branch B room")
	check(not scene.room_checkpoint.is_empty() and str(scene.room_checkpoint.node_id) == "N2-04", "room checkpoint at branch B")
	scene.progress.flags.AFTER_DEATH = true
	scene.retry_from_room()
	await process_frame
	check(scene.progress.node_id == "N2-04", "retry returns to branch B room, not hub")
	check(bool(scene.progress.flags.get("P05",false)), "branch B prerequisite survives retry")
	check(not bool(scene.progress.flags.get("AFTER_DEATH",false)), "uncommitted post-checkpoint flag is rolled back")
	print("G4_DEATH_TEST checks=%d failures=%d node=%s" % [checks,failures,scene.progress.node_id])
	scene.free()
	await process_frame
	quit(1 if failures else 0)
