extends Node
## Native viewport event dispatch, not operating-system keyboard automation.
var results: Array[Dictionary] = []
var scene

func check(ok: bool, label: String) -> void:
	results.append({"check":label,"passed":ok})
	if not ok: print("FAIL integration: ",label)

func key(code: int, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func click(button: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = Vector2(440,380)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func step() -> void:
	scene._physics_process(1.0/60.0)

func run(root) -> void:
	scene = root
	await get_tree().process_frame
	Input.warp_mouse(Vector2(440,380))
	await get_tree().process_frame
	scene.paused = false
	var model = scene.combat
	click(MOUSE_BUTTON_LEFT,true)
	click(MOUSE_BUTTON_LEFT,false)
	check(scene.commands == ["melee"],"mouse press/release dispatch")
	step()
	check(model.action == "melee","quick click starts melee")
	check(scene.combat_audio.playback_count == 1,"one swing event triggers one audio playback")
	for i in 30: step()
	check(model.action == "idle","released mouse does not repeat")
	for reverse in [false,true]:
		model.reset()
		if reverse:
			key(KEY_SPACE)
			click(MOUSE_BUTTON_RIGHT,true)
		else:
			click(MOUSE_BUTTON_RIGHT,true)
			key(KEY_SPACE)
		click(MOUSE_BUTTON_RIGHT,false)
		key(KEY_SPACE,false)
		step()
		check(model.action == "dodge","same callback priority reverse="+str(reverse))
	model.reset()
	key(KEY_D)
	for i in 6: step()
	key(KEY_D,false)
	check(model.player.x > 77.9,"physical movement key held")
	var stopped: Vector2 = model.player
	step()
	check(model.player == stopped,"movement key released")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE,false)
	var tick: int = model.tick
	click(MOUSE_BUTTON_LEFT,true)
	click(MOUSE_BUTTON_LEFT,false)
	for i in 5: step()
	check(scene.paused and model.tick == tick,"Escape freezes simulation")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE,false)
	step()
	check(not scene.paused and model.action == "idle","resume drops paused commands")
	scene.get_window().focus_exited.emit()
	step()
	check(scene.paused,"focus loss pauses")
	scene.get_window().focus_entered.emit()
	check(scene.paused,"focus regain requires explicit resume")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE,false)
	var nodes: int = get_tree().get_node_count()
	var connections: int = scene.get_window().focus_exited.get_connections().size()
	for retry in 20:
		model.hp = 0
		model.shield_hp = 25
		model.rains.append({"id":999,"pos":Vector2(110,95),"impact_tick":100,"hit":false})
		model.spawn_zone(Vector2(90,130))
		model.spawn_projectile(Vector2(280,90),Vector2.LEFT*80)
		model.set_door_open("test_gate",false)
		scene.commands.append("light")
		key(KEY_F5)
		key(KEY_F5,false)
		check(model.hp == 100 and model.tick == 0 and model.action == "idle","retry restores player "+str(retry))
		check(model.projectiles.is_empty() and model.zones.is_empty() and model.doors[0].open and model.path_queries == 0 and scene.commands.is_empty(),"retry clears transient state "+str(retry))
		check(model.shield_hp == 0 and model.rains.is_empty(),"retry clears shield and rain "+str(retry))
		step()
		check("生命 100" in scene.hud.text and "已倒地" not in scene.status.text,"retry refreshes HUD "+str(retry))
		await get_tree().process_frame
	check(get_tree().get_node_count() == nodes,"20 retries stable scene node count")
	check(scene.get_window().focus_exited.get_connections().size() == connections,"20 retries stable signal connections")
	click(MOUSE_BUTTON_LEFT,true)
	click(MOUSE_BUTTON_LEFT,false)
	check(scene.commands == ["melee"],"20 retries preserve single input dispatch")
	step()
	check(model.action == "melee","20 retries preserve playable input")
	var audio_count: int = scene.combat_audio.playback_count
	key(KEY_ESCAPE)
	key(KEY_ESCAPE,false)
	for i in 5: step()
	check(scene.combat_audio.playback_count == audio_count,"paused callbacks do not replay audio events")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE,false)
	var before_preview: int = model.tick
	key(KEY_F2)
	key(KEY_F2,false)
	for i in 5: step()
	check(scene.pose_view and model.tick == before_preview,"pose preview freezes live combat")
	key(KEY_COMMA)
	key(KEY_COMMA,false)
	var preview_tick: int = scene.pose_tick
	for i in 3: step()
	check(scene.pose_tick == preview_tick,"pose playback pause")
	key(KEY_PERIOD)
	key(KEY_PERIOD,false)
	step()
	check(scene.pose_tick == preview_tick+1,"pose single frame step")
	key(KEY_F3)
	key(KEY_F3,false)
	check(scene.sewer,"sewer background switch")
	key(KEY_F4)
	key(KEY_F4,false)
	check(scene.debug_shapes,"debug overlays opt in")
	key(KEY_F2)
	key(KEY_F2,false)
	step()
	check(not scene.pose_view and model.tick == before_preview+1,"return to live combat resumes exactly once")
	key(KEY_F5)
	key(KEY_F5,false)
	key(KEY_1)
	key(KEY_1,false)
	for i in 10: step()
	check(model.shield_hp == 25 and model.cooldowns.shield == 480,"key 1 releases shield through production input")
	key(KEY_F5)
	key(KEY_F5,false)
	key(KEY_2)
	key(KEY_2,false)
	for i in 22: step()
	check(model.rains.size() == 1 and model.cooldowns.rain == 360,"key 2 releases rain through production input")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE,false)
	var impact_tick: int = model.rains[0].impact_tick if not model.rains.is_empty() else -1
	var frozen_tick: int = model.tick
	for i in 35: step()
	check(model.tick == frozen_tick and not model.rains.is_empty() and model.rains[0].impact_tick == impact_tick,"pause freezes pending rain")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE,false)
	key(KEY_F5)
	key(KEY_F5,false)
	key(KEY_H)
	key(KEY_H,false)
	var armored = model.enemies[0]
	check(armored.armor_layers == 2,"H enables two-layer armored target")
	click(MOUSE_BUTTON_RIGHT,true)
	click(MOUSE_BUTTON_RIGHT,false)
	for i in 13: step()
	check(armored.armor_layers == 1 and armored.hp == 54,"native light strips then applies 25 percent reduction")
	for i in 80: step()
	click(MOUSE_BUTTON_RIGHT,true)
	click(MOUSE_BUTTON_RIGHT,false)
	for i in 13: step()
	check(armored.armor_layers == 0 and armored.hp == 30,"second light breaks shell and deals full damage")
	check(model.history.filter(func(e): return e.kind == "armor_break").size() == 1,"native break feedback event occurs once")
	check(not scene.feedback.effects.is_empty(),"combat events create bounded feedback records")
	key(KEY_F1)
	key(KEY_F1,false)
	var settings_tick: int = model.tick
	key(KEY_2)
	key(KEY_2,false)
	for i in 5: step()
	check(scene.settings_panel.visible and scene.paused and model.tick == settings_tick and scene.commands.is_empty(),"settings panel freezes combat and blocks spell keys")
	for field in ["low_effects","reduced_motion","reduced_flash"]:
		scene.settings_panel.controls[field].button_pressed = true
	scene.settings_panel.volume_slider.value = 0
	check(scene.preferences.low_effects and scene.preferences.reduced_motion and scene.preferences.reduced_flash,"settings controls apply display options")
	check(scene.combat_audio.voices.hit.volume_db <= -80,"zero audio slider mutes effect voices")
	var saved = preload("res://scripts/presentation_settings.gd").new()
	saved.path = scene.preferences.path
	check(saved.read_settings() == OK and saved.low_effects and saved.reduced_motion and saved.reduced_flash and saved.sfx_volume == 0,"presentation settings persist and reload")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE,false)
	step()
	check(not scene.settings_panel.visible and not scene.paused and model.tick == settings_tick+1,"closing settings resumes exactly one step")
	key(KEY_F5)
	key(KEY_F5,false)
	check(scene.feedback.effects.is_empty() and scene.feedback.numbers.is_empty(),"retry clears visual records")
	key(KEY_1)
	key(KEY_1,false)
	for i in 10: step()
	check(model.shield_hp == 25 and model.focus == 75,"low effects still releases shield with same resource cost")
	for field in ["low_effects","reduced_motion","reduced_flash"]:
		scene.settings_panel.controls[field].button_pressed = false
	scene.settings_panel.volume_slider.value = 80
	var failures := results.filter(func(item): return not item.passed).size()
	var file := FileAccess.open(OS.get_environment("FUNGUS_INTEGRATION_OUTPUT"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results.size(),"failures":failures,"results":results,"scope":"Exported native viewport events and explicit physics callbacks; not OS keyboard automation."},"\t"))
	file.close()
	print("INTEGRATION_DONE checks=",results.size()," failures=",failures)
	scene.combat_audio.stop_all()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if failures == 0 else 1)
