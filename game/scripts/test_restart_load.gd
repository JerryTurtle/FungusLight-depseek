extends SceneTree
## Two-process persistence regression: the first run writes a mid-game save,
## the second brand-new process must load it through the normal campaign path.
## The phase is auto-detected from the save file, so two plain Godot runs are a
## true cross-process test. Evidence is the stdout captured by the runner.
const Campaign = preload("res://scripts/campaign.gd")
const SAVE_DIR := "res://../qa/runtime-profile/restart-load"
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
	var folder: String = OS.get_environment("FUNGUS_RESTART_DIR")
	if folder.is_empty():
		folder = ProjectSettings.globalize_path("res://").path_join("../qa/runtime-profile/restart-load").simplify_path()
	var phase: String = OS.get_environment("FUNGUS_RESTART_PHASE")
	if phase.is_empty():
		phase = "load" if FileAccess.file_exists(folder + "/manual_1.json") else "write"
	DirAccess.make_dir_recursive_absolute(folder)
	print("RESTART_PHASE ", phase, " dir=", folder)
	var scene = Campaign.new()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.saves.directory = folder
	if phase == "write":
		for name in ["manual_1.json", "manual_1.json.bak"]:
			if FileAccess.file_exists(folder + "/" + name): DirAccess.remove_absolute(folder + "/" + name)
		scene.new_game()
		scene.wake_left = 0
		scene.hide_player = false
		# Valid mid-game state: prologue cleared, light + shield unlocked, Q1 done.
		for flag in ["P01", "S02", "P02", "Q1"]:
			scene.progress.flags[flag] = true
		scene.save_game("manual_1", true)
		check(FileAccess.file_exists(folder + "/manual_1.json"), "mid-game save written")
		check(scene.notice == "保存成功", "save accepted: " + scene.notice)
		print("RESTART_WRITE checks=%d failures=%d" % [checks, failures])
	else:
		var stored: Dictionary = scene.saves.load_slot("manual_1")
		check(stored.ok, "save readable before load")
		if stored.ok:
			check(bool(stored.snapshot.skills.get("light", false)), "saved skills contain light")
		scene.load_game("manual_1")
		check(scene.running, "load enters playable state")
		check(not scene.overlay.visible, "no load-error overlay")
		check(scene.progress.node_id == "N0-01", "node restored")
		check(scene.progress.has("S02") and scene.progress.has("P02") and scene.progress.has("Q1"), "flags restored")
		var sk: Dictionary = scene.progress.skills()
		check(bool(sk.get("light", false)) and bool(sk.get("shield", false)) and not bool(sk.get("rain", false)), "skills restored")
		var qs: Dictionary = scene.progress.quests()
		check(bool(qs.get("Q1", false)) and not bool(qs.get("Q2", false)), "quests restored")
		print("RESTART_LOAD checks=%d failures=%d" % [checks, failures])
		for name in ["manual_1.json", "manual_1.json.bak"]:
			if FileAccess.file_exists(folder + "/" + name): DirAccess.remove_absolute(folder + "/" + name)
	scene.combat_audio.stop_all()
	scene.free()
	quit(1 if failures > 0 else 0)
