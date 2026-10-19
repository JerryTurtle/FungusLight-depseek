extends SceneTree
## G6 release-flow checks: title/continue/load, two isolated manual slots,
## corrupt-primary backup recovery, death menu, both endings and credits.
## This runs against the same campaign scene as the release build; it does not
## claim human acceptance or a clean-directory launch (see tools/test_clean_release.py).

const Campaign = preload("res://scripts/campaign.gd")
var checks := 0
var failures := 0
var scene

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func menu_texts() -> Array[String]:
	var out: Array[String] = []
	for child in scene.menu.get_children():
		if child is Label or child is Button:
			out.append(str(child.text))
	return out

func has_text(needle: String) -> bool:
	for text in menu_texts():
		if text.find(needle) >= 0: return true
	return false

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	scene = Campaign.new()
	root.add_child(scene)
	check(scene.combat_audio.music != null and scene.combat_audio.music.stream is AudioStreamWAV and scene.combat_audio.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "boss BGM loaded and loops")
	await process_frame
	scene.set_physics_process(false)
	scene.saves.directory = ProjectSettings.globalize_path("res://").path_join("../qa/runtime-profile/g6-flow-"+str(Time.get_ticks_usec())).simplify_path()
	scene.show_title()
	await process_frame
	check(has_text("新游戏") and has_text("继续游戏（无自动存档）") and has_text("读取存档") and has_text("设置") and has_text("退出"),"title menu complete on first run")
	check(not has_text("开发切片") and not has_text("重看开场故事") and not scene.world.visible and not scene.hud.visible,"title is a clean release screen")
	var continue_button: Button = null
	for child in scene.menu.get_children():
		if child is Button and str(child.text).begins_with("继续"): continue_button = child
	check(continue_button != null and continue_button.disabled,"continue disabled without auto save")

	scene.show_load_menu()
	await process_frame
	var empty_buttons := 0
	for child in scene.menu.get_children():
		if child is Button and child.disabled: empty_buttons += 1
	check(empty_buttons >= 4,"empty slots are disabled in load menu")
	scene.show_title()
	var settings_button: Button = null
	for child in scene.menu.get_children():
		if child is Button and str(child.text) == "设置": settings_button = child
	if settings_button != null: settings_button.emit_signal("pressed")
	await process_frame
	check(settings_button != null and scene.settings_panel.visible and scene.settings_panel.z_index >= 100 and scene.paused,"settings button from title opens above")
	scene.on_settings_closed()
	check(not scene.settings_panel.visible and has_text("新游戏"),"settings closes back to title")
	var prefs = preload("res://scripts/presentation_settings.gd").new()
	DirAccess.make_dir_recursive_absolute(scene.saves.directory)
	prefs.path = scene.saves.directory+"/presentation-test.cfg"
	prefs.fullscreen = true
	prefs.sfx_volume = 0.35
	check(prefs.write_settings() == OK,"settings write independently")
	prefs.fullscreen = false
	prefs.sfx_volume = 1.0
	check(prefs.read_settings() == OK and prefs.fullscreen and is_equal_approx(prefs.sfx_volume,0.35),"settings persist fullscreen and volume")

	scene.new_game()
	scene.wake_left = 0
	scene.hide_player = false
	await process_frame
	check(scene.running and not scene.paused and scene.world.visible,"new game enters playable world")
	check(FileAccess.file_exists(scene.saves.directory+"/auto.json"),"new game writes auto checkpoint")
	scene.show_title()
	check(has_text("继续游戏（自动存档）"),"continue enabled after auto save")
	scene.new_game()
	scene.wake_left = 0
	scene.hide_player = false
	scene.progress.seconds = 12.0
	scene.save_game("manual_1",true)
	check(FileAccess.file_exists(scene.saves.directory+"/manual_1.json"),"manual slot 1 saved")
	scene.progress.seconds = 34.0
	scene.save_game("manual_2",true)
	check(FileAccess.file_exists(scene.saves.directory+"/manual_2.json"),"manual slot 2 saved independently")
	# A second save creates the valid .bak used by the corrupt-primary path.
	scene.progress.seconds = 13.0
	scene.save_game("manual_1",true)
	check(FileAccess.file_exists(scene.saves.directory+"/manual_1.json.bak"),"manual slot keeps a backup")
	scene.load_game("manual_1")
	check(is_equal_approx(scene.progress.seconds,13.0),"slot 1 reloads its own time")
	scene.load_game("manual_2")
	check(is_equal_approx(scene.progress.seconds,34.0),"slot 2 reloads its own time")

	# Corrupt primary but leave the valid .bak; the UI must offer recovery.
	var primary: String = scene.saves.directory+"/manual_1.json"
	var bad := FileAccess.open(primary,FileAccess.WRITE)
	bad.store_string("{broken")
	bad.close()
	scene.load_game("manual_1")
	check(has_text("恢复上一次备份"),"corrupt primary offers backup recovery")
	scene.load_game("manual_1",true)
	check(is_equal_approx(scene.progress.seconds,12.0),"backup recovery restores valid slot")

	# Regression: derived fields must be validated against the save's own story
	# flags, not the live progress. This covers a restart (fresh Campaign) and an
	# older save read after later unlocks.
	scene.new_game()
	scene.wake_left = 0
	scene.hide_player = false
	scene.save_game("manual_3",true)
	for flag in ["P01","S02","P02","Q1"]: scene.progress.flags[flag] = true
	scene.save_game("manual_2",true)
	scene.load_game("manual_3")
	check(scene.running and not scene.progress.has("S02") and not scene.progress.has("Q1"),"older save loads after later unlocks")
	var fresh = Campaign.new()
	root.add_child(fresh)
	await process_frame
	fresh.set_physics_process(false)
	fresh.saves.directory = scene.saves.directory
	fresh.show_title()
	fresh.load_game("manual_2")
	check(fresh.running,"fresh instance loads mid-game save")
	check(fresh.progress.has("S02") and fresh.progress.has("P02") and fresh.progress.has("Q1"),"fresh load restores flags")
	var fresh_skills: Dictionary = fresh.progress.skills()
	var fresh_quests: Dictionary = fresh.progress.quests()
	check(bool(fresh_skills.get("light",false)) and bool(fresh_skills.get("shield",false)) and not bool(fresh_skills.get("rain",false)) and bool(fresh_quests.get("Q1",false)),"fresh load restores skills/quests")
	fresh.combat_audio.stop_all()
	fresh.queue_free()
	await process_frame

	# Every authored room must load, have a walkable spawn, and resolve its props.
	var map_ok := true
	for node_def in scene.progress.content.nodes:
		scene.progress.node_id = str(node_def.id)
		scene.load_room()
		if scene.combat.blocked(scene.combat.player,5): map_ok = false
		for obj in node_def.get("objects", []):
			var visual := str(obj.get("visual", obj.kind))
			if visual in ["wounded","rong"]: continue
			if not scene.props.has_kind(visual): map_ok = false
		scene.combat.enemies.clear()
	check(map_ok,"all 37 rooms load with walkable spawn and resolvable props")
	for sound in ["swing","hit","cast","hurt","shell_break","shield_hit","rain_impact"]:
		check(load("res://assets/audio/"+sound+".wav") != null,"audio asset "+sound)
	scene.new_game()
	scene.wake_left = 0
	scene.hide_player = false

	# Death overlay must expose retry, load and title, not only retry.
	scene.combat.hp = 0
	scene.paused = false
	scene.running = true
	scene._physics_process(1.0/60.0)
	check(has_text("回到最近安全点") and has_text("读取存档") and has_text("返回标题"),"death menu has retry/load/title")
	scene.show_title()

	# Both endings and the credits/backup path.
	scene.new_game()
	scene.wake_left = 0
	scene.hide_player = false
	scene.progress.flags["E30"] = true
	scene.show_ending_choice()
	check(not scene.choice_pending,"ending choice gated without evidence")
	for flag in ["E30","S04","S07","S08","P06","P08","P09"]: scene.progress.flags[flag] = true
	scene.progress.node_id = "N4-06"
	scene.load_room()
	scene.choice_mode = "ending"
	scene.choose_ending("restore")
	check(scene.progress.ending_id() == "restore","restore ending commits")
	var pre_backup: Dictionary = scene.saves.load_ending_backup()
	check(pre_backup.ok and not bool(pre_backup.snapshot.story.get("END_RESTORE",false)),"independent pre-ending backup")
	# A later autosave (the exit into the credits room) must not overwrite it.
	scene.save_game("auto",true)
	var after_exit: Dictionary = scene.saves.load_ending_backup()
	check(after_exit.ok and not bool(after_exit.snapshot.story.get("END_RESTORE",false)),"pre-ending backup survives exit autosave")
	scene.show_credits()
	check(has_text("返回标题") and has_text("读取结局前存档"),"credits expose title and pre-ending backup")
	check(scene.chapter_report_text().begins_with("章节记录："),"credits include chapter statistics")
	scene.show_title()
	scene.new_game()
	scene.wake_left = 0
	scene.hide_player = false
	for flag in ["E30","S04","S07","S08","P06","P08","P09"]: scene.progress.flags[flag] = true
	scene.progress.node_id = "N4-06"
	scene.load_room()
	scene.choice_mode = "ending"
	scene.choose_ending("seal")
	check(scene.progress.ending_id() == "seal","seal ending commits")

	scene.combat_audio.stop_all()
	scene.queue_free()
	await process_frame
	print("G6_RELEASE_TEST checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
