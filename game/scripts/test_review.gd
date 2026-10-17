extends Node
var results: Array[Dictionary] = []
func check(value: bool, name: String) -> void:
	results.append({"check":name,"passed":value})
	if not value: print("FAIL REVIEW ",name)

func run(review) -> void:
	review.game.set_physics_process(false)
	review.set_process(false)
	# QA feedback is isolated; no human approval button is invoked.
	review.store = preload("res://scripts/review_store.gd").new()
	review.store.directory = "user://qa-review/G2-007"
	for item in 5:
		review.select_item(item)
		for frame in 1440:
			review.game._physics_process(1.0/60)
			if frame % 120 == 0: await get_tree().process_frame
			if frame == 74 or (item == 2 and frame in [18,558,780,1140]) or (item == 3 and frame in [55,235,415,600,750,960]):
				review._process(0)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(OS.get_environment("FUNGUS_REVIEW_QA")+"/H0%d-action-%d.png" % [item+1,frame])
		check(review.driver.finished,"H0%d complete demonstration timeline" % (item+1))
		check(review.game.feedback.effects.size() <= 64 and review.game.feedback.numbers.size() <= 16,"bounded feedback H0%d" % (item+1))
		review.suspend()
		review._process(0)
		await RenderingServer.frame_post_draw
		var path := OS.get_environment("FUNGUS_REVIEW_QA")+"/H0%d.png" % (item+1)
		check(get_viewport().get_texture().get_image().save_png(path) == OK,"native screenshot H0%d" % (item+1))
	# Exercise every demonstration in both settings and compare actual simulation traces.
	for item in range(1,5):
		var reference: Array = []
		var audio_reference := 0
		var kinds: Dictionary = {}
		for quality in 2:
			review.game.preferences.low_effects = quality == 1
			review.game.preferences.reduced_motion = quality == 1
			review.game.preferences.reduced_flash = quality == 1
			review.select_item(item)
			var trace: Array = []
			var audio_before: int = review.game.combat_audio.playback_count
			var expected_audio := 0
			for frame in 1440:
				review.game._physics_process(1.0/60)
				var m = review.game.combat
				trace.append(var_to_str([m.player,m.hp,m.focus,m.action,m.cooldowns,m.enemies,m.projectiles,m.zones,m.rains,m.shield_hp]))
				for event in m.events:
					kinds[event.kind] = true
					if event.kind in ["hit","release","hurt","armor_break","shield_absorb","rain_impact"] or (event.kind == "action" and event.action == "melee"): expected_audio += 1
				if frame % 120 == 0: await get_tree().process_frame
				if quality == 1 and (frame == 74 or (item == 2 and frame in [18,558,780,1140]) or (item == 3 and frame in [55,235,415,600,750,960])):
					review._process(0)
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png(OS.get_environment("FUNGUS_REVIEW_QA")+"/H0%d-low-%d.png" % [item+1,frame])
			var played: int = review.game.combat_audio.playback_count-audio_before
			check(played == expected_audio,"H0%d quality%d audio exactly matches simulation events" % [item+1,quality])
			if quality == 0:
				reference = trace
				audio_reference = played
			else: check(reference == trace and played == audio_reference,"H0%d low settings preserve entire combat timeline" % (item+1))
		if item == 1: check(kinds.has("armor_break") and kinds.has("hit"),"H02 really hits and breaks armor")
		if item == 2: check(kinds.has("shield_absorb") and kinds.has("rain_impact"),"H03 really absorbs shield and resolves rain")
		if item == 3: check(kinds.has("hurt"),"H04 hazards really cause damage")
	review.game.preferences.low_effects = false
	review.game.preferences.reduced_motion = false
	review.game.preferences.reduced_flash = false
	review.select_item(0)
	review.suspend()
	var before: int = review.driver.frame
	review.step_once()
	check(review.driver.frame == before+1 and review.game.paused,"one-frame playback remains paused")
	review.direction_picker.item_selected.emit(2)
	check(review.driver.manual_direction and review.driver.direction_index == 2,"manual direction selection")
	review.zoom_picker.item_selected.emit(0)
	check(review.game.review_zoom == 1,"one-times pixel scale")
	review.zoom_picker.item_selected.emit(2)
	review.select_item(5)
	review.enter_trial()
	review.game._physics_process(1.0/60)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(700,374)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await get_tree().process_frame
	var click := InputEventMouseButton.new()
	click.position = motion.position
	click.global_position = motion.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await get_tree().process_frame
	check("melee" in review.game.commands,"review viewport routes left click to melee command")
	review.game._physics_process(1.0/60)
	check(review.game.combat.action == "melee","review mouse coordinate converts through camera")
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	check(not review.game.paused and not review.viewport.gui_disable_input and not review.game.practice,"free trial uses normal resources")
	review.toggle_play()
	check(review.game.paused,"free trial pause button pauses")
	review.toggle_play()
	check(not review.game.paused,"free trial play button resumes")
	review.select_item(5)
	review.enter_trial()
	var start_position: Vector2 = review.game.combat.player
	var move_event := InputEventKey.new()
	move_event.physical_keycode = KEY_D
	move_event.pressed = true
	Input.parse_input_event(move_event)
	await get_tree().process_frame
	review.game._physics_process(1.0/60)
	move_event = move_event.duplicate()
	move_event.pressed = false
	Input.parse_input_event(move_event)
	check(review.game.combat.player.x > start_position.x,"review root keyboard event moves trial player")
	var spell_event := InputEventKey.new()
	spell_event.physical_keycode = KEY_1
	spell_event.pressed = true
	Input.parse_input_event(spell_event)
	await get_tree().process_frame
	review.game._physics_process(1.0/60)
	spell_event = spell_event.duplicate()
	spell_event.pressed = false
	Input.parse_input_event(spell_event)
	check(review.game.combat.action == "shield","review root key1 reaches combat controller")
	review.select_item(5)
	review.enter_trial()
	review.game.combat.player = Vector2(70,32)
	review.game._physics_process(1.0/60)
	var screen_foot: Vector2 = review.game.world.position+review.game.combat.player*4
	check(screen_foot.y-31*4 > 0 and screen_foot.y < 480,"camera preserves head near top world boundary")
	for retry in 20: review.select_item(5)
	check(review.game.combat.rains.is_empty() and review.game.feedback.effects.is_empty(),"review reset clears hazards and feedback")
	review.select_item(0)
	review.suspend()
	review.note.text = "QA保存测试，不是人工结论。"
	review.note.text_changed.emit()
	review.verdict.item_selected.emit(2)
	review.tags["方向不对"].button_pressed = true
	await review.record_problem()
	check(review.store.records.H01.captures.size() == 1,"issue record includes screenshot")
	review.export_feedback()
	check(FileAccess.file_exists(review.store.directory+"/审核反馈.md"),"readable feedback export exists")
	var reloaded = preload("res://scripts/review_store.gd").new()
	reloaded.directory = review.store.directory
	check(reloaded.load_review() == OK and reloaded.records.H01.status == "需修改" and reloaded.records.H01.note == review.note.text,"feedback reload preserves status and note")
	check(not reloaded.confirmed,"QA never confirms H2 approval")
	var old_clipboard := DisplayServer.clipboard_get()
	await review.copy_feedback()
	await get_tree().process_frame
	check(DisplayServer.clipboard_get().replace("\r\n","\n") == review.store.markdown(),"copy feedback matches exported text")
	DisplayServer.clipboard_set(old_clipboard)
	var directory: String = review.store.directory
	review.store.directory = "res://missing-read-only/review"
	check(review.store.export_files(review.context()) != OK,"save failure reported")
	check(not review.store.markdown().is_empty(),"feedback text remains available after failed save")
	review.store.directory = directory
	review.show_settings()
	check(review.game.paused and review.settings.visible,"settings pauses review world")
	review.settings.hide()
	var failures := results.filter(func(value): return not value.passed).size()
	var output := FileAccess.open(OS.get_environment("FUNGUS_REVIEW_QA")+"/checks.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":results.size(),"failures":failures,"results":results},"\t"))
	output.close()
	print("REVIEW_TEST_DONE checks=",results.size()," failures=",failures)
	review.game.combat_audio.stop_all()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if failures == 0 else 1)
