extends Node
## One playback per simulation event; the owner calls consume once after step.
var voices: Dictionary = {}
var music: AudioStreamPlayer
var music_stream: AudioStreamWAV
var playback_count := 0

func _ready() -> void:
	for kind in ["swing","hit","cast","hurt","shell_break","shield_hit","rain_impact"]:
		var voice := AudioStreamPlayer.new()
		voice.stream = load("res://assets/audio/"+kind+".wav")
		voice.max_polyphony = 4
		voice.volume_db = -7
		add_child(voice)
		voices[kind] = voice
	music_stream = load("res://assets/audio/boss_theme.wav") as AudioStreamWAV
	if music_stream != null:
		music_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		music_stream.loop_begin = 0
		music_stream.loop_end = int(music_stream.data.size() / (4 if music_stream.stereo else 2))
	music = AudioStreamPlayer.new()
	music.stream = music_stream
	music.volume_db = -13
	add_child(music)

func consume(events: Array) -> void:
	for event in events:
		var kind := ""
		if event.kind == "action" and event.action == "melee": kind = "swing"
		elif event.kind == "hit": kind = "hit"
		elif event.kind == "release": kind = "cast"
		elif event.kind in ["hurt","dot"]: kind = "hurt"
		elif event.kind == "armor_break": kind = "shell_break"
		elif event.kind == "shield_absorb": kind = "shield_hit"
		elif event.kind == "rain_impact": kind = "rain_impact"
		if not kind.is_empty():
			voices[kind].play()
			playback_count += 1

func play_boss_music() -> void:
	if music != null and not music.playing:
		music.play()

func stop_music() -> void:
	if music != null:
		music.stop()

func stop_all() -> void:
	for voice in voices.values(): voice.stop()

func set_volume(value: float) -> void:
	for voice in voices.values(): voice.volume_db = -7.0+linear_to_db(value) if value > 0 else -80.0
	if music != null:
		music.volume_db = -13.0+linear_to_db(value) if value > 0 else -80.0
