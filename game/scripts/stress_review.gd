extends Node
var review
var start_usec := 0
var last_sample := 0.0
var samples: Array[Dictionary] = []
var frames := 0
var elapsed_sum := 0.0
var max_delta := 0.0
var long_frames := 0
var buckets: Dictionary = {}
var complete := false

func run(root) -> void:
	review = root
	root.set_process(false)
	root.select_item(5)
	root.game.demo_driver = preload("res://scripts/stress_driver.gd").new()
	root.game.paused = false
	root.get_viewport().gui_disable_input = true
	root.game.combat_audio.set_volume(0)
	Engine.max_fps = 60
	start_usec = Time.get_ticks_usec()
	print("STRESS_STARTED duration_seconds=900 profile=standard_then_low")

func _process(delta: float) -> void:
	if start_usec == 0 or complete: return
	frames += 1
	elapsed_sum += delta
	max_delta = maxf(max_delta,delta)
	if delta > 0.05: long_frames += 1
	var bin := mini(500,int(delta*1000))
	buckets[bin] = int(buckets.get(bin,0))+1
	var elapsed := float(Time.get_ticks_usec()-start_usec)/1000000
	if elapsed-last_sample >= 5:
		last_sample = elapsed
		samples.append({"elapsed":elapsed,"fps":frames/maxf(elapsed_sum,0.001),"max_frame_ms":max_delta*1000,"over_50ms":long_frames,"memory_static":Performance.get_monitor(Performance.MEMORY_STATIC),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"effects":review.game.feedback.effects.size(),"projectiles":review.game.combat.projectiles.size(),"enemies":review.game.combat.enemies.size(),"quality":"low" if review.game.preferences.low_effects else "standard"})
		frames = 0
		elapsed_sum = 0
		max_delta = 0
		long_frames = 0
	if elapsed >= 900:
		complete = true
		var output := FileAccess.open(OS.get_environment("FUNGUS_STRESS_OUTPUT"),FileAccess.WRITE)
		output.store_string(JSON.stringify({"elapsed_seconds":elapsed,"samples":samples,"frame_ms_histogram":buckets,"resolution":[1280,720],"renderer":"gl_compatibility","video_adapter":RenderingServer.get_video_adapter_name(),"os":OS.get_name(),"cpu":OS.get_processor_name()},"\t"))
		output.close()
		print("STRESS_DONE elapsed=",elapsed," samples=",samples.size())
		review.game.combat_audio.stop_all()
		await get_tree().process_frame
		get_tree().quit()
