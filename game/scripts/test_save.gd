extends SceneTree
const Store = preload("res://scripts/save_store.gd")
var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL ", label)

func write_raw(path: String, data: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(data)
	file.close()

func _initialize() -> void:
	var folder := ProjectSettings.globalize_path("res://").path_join("../qa/runtime-profile/save-"+str(Time.get_ticks_usec())).simplify_path()
	var store := Store.new(folder)
	var safe := {}
	for key in Store.SAFETY_FIELDS: safe[key] = true
	var state := {"schema_version":1, "build_id":"G3-001", "chapter_id":"prologue", "node_id":"camp", "safe_position":[80,100], "health":100, "focus":60, "potions":3, "effective_seconds":12.5}
	for key in Store.MAP_FIELDS: state[key] = {}
	state.quests = {"S01":"completed"}
	state.rewards = {"M1":true}
	state.skills = {"light":true}
	state["debug_invulnerable"] = true
	check(store.load_slot("manual_1").code == "missing", "empty slot")
	check(store.save_slot("../escape", state, safe).code == "invalid_slot", "path traversal rejected")
	check(store.load_slot("../escape").code == "invalid_slot", "load traversal rejected")
	check(store.save_slot("auto", state, {}).code == "unsafe", "missing safety fails closed")
	var numeric_safe := safe.duplicate()
	numeric_safe.player_idle = 1
	check(not Store.is_safe(numeric_safe), "numeric flag is not safety proof")
	for key in Store.SAFETY_FIELDS:
		var blocked := safe.duplicate()
		blocked[key] = false
		check(store.save_slot("auto", state, blocked).code == "unsafe", "safety gate "+key)
	for slot in Store.SLOTS:
		check(store.save_slot(slot, state, safe).ok, "first save "+slot)
		var loaded := Store.new(folder).load_slot(slot)
		check(loaded.ok and loaded.snapshot.quests == state.quests and loaded.snapshot.rewards == state.rewards and loaded.snapshot.skills == state.skills, "new instance restores whole snapshot "+slot)
		check(not loaded.snapshot.has("debug_invulnerable"), "debug excluded "+slot)
	check(store.save_slot("manual_1", state, safe).code == "confirmation_required", "manual overwrite confirmation")
	state.health = 42
	state.rewards = {"M1":true,"chest_1":true}
	check(store.save_slot("manual_1", state, safe, true).ok, "confirmed replacement")
	check(store.load_slot("manual_1").snapshot.health == 42, "new primary")
	check(store.load_slot("manual_1", true).snapshot.health == 100, "previous backup")
	check(store.load_slot("manual_2").snapshot.health == 100, "slot isolation")
	check(store.save_slot("auto", state, safe).ok, "automatic replacement")
	var broken := state.duplicate(true)
	broken.schema_version = 999
	check(store.save_slot("manual_1", broken, safe, true).code == "invalid_snapshot", "incompatible write rejected")
	check(store.load_slot("manual_1").snapshot.health == 42, "failed validation preserves primary")
	for key in state.keys():
		if key == "debug_invulnerable": continue
		broken = state.duplicate(true)
		broken.erase(key)
		check(not Store.validate_snapshot(broken).is_empty(), "required field "+key)
	for bad in [-1,4,1.5,"three",true]:
		broken = state.duplicate(true)
		broken.potions = bad
		check(not Store.validate_snapshot(broken).is_empty(), "invalid potion "+str(bad))
	write_raw(folder+"/manual_1.json", "{truncated")
	var corrupt := store.load_slot("manual_1")
	check(not corrupt.ok and corrupt.backup_available, "corruption offers explicit recovery")
	var recovered := store.load_slot("manual_1", true)
	check(recovered.ok and recovered.snapshot.health == 100 and not recovered.snapshot.rewards.has("chest_1"), "rollback rewards and resources together")
	check(store.save_slot("manual_1", state, safe, true).ok, "repair corrupt primary")
	check(store.load_slot("manual_1", true).snapshot.health == 100, "corrupt primary does not destroy backup")
	broken = state.duplicate(true)
	broken.schema_version = 999
	write_raw(folder+"/manual_2.json", JSON.stringify(broken))
	check(store.load_slot("manual_2").message == "存档版本不兼容", "incompatible load diagnostic")
	write_raw(folder+"/manual_3.json", "null")
	check(not store.load_slot("manual_3").ok and not store.load_slot("manual_3").backup_available, "unrecoverable corruption")
	write_raw(folder+"/auto.json.tmp", "unfinished write")
	check(store.load_slot("auto").snapshot.health == 42, "interrupted temporary file ignored")
	DirAccess.remove_absolute(folder+"/auto.json.tmp")
	DirAccess.make_dir_absolute(folder+"/auto.json.tmp")
	state.health = 20
	check(store.save_slot("auto", state, safe).code == "io", "failed staging write reported")
	check(store.load_slot("auto").snapshot.health == 42, "failed staging write preserves primary")
	check(store.load_slot("auto", true).snapshot.health == 100, "failed staging write preserves backup")
	write_raw(folder+"/blocked", "file blocks directory")
	check(Store.new(folder+"/blocked/subdir").save_slot("auto", state, safe).code == "io", "filesystem failure reported")
	check(store.load_slot("auto").snapshot.health == 42, "unrelated IO failure preserves saved data")
	print("SAVE_TEST checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
