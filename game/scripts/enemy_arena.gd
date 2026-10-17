extends "res://scripts/graybox.gd"
var kind := "T2"
var warnings: Node2D

func _ready() -> void:
	combat = preload("res://scripts/campaign_combat.gd").new()
	super._ready()
	warnings = Node2D.new()
	world.add_child(warnings)
	warnings.draw.connect(func(): preload("res://scripts/enemy_warnings.gd").draw(warnings,combat))
	var choices := HBoxContainer.new()
	choices.position = Vector2(540,12)
	add_child(choices)
	for type in ["T2","T3","T4","T5","EL1"]:
		var b := Button.new()
		b.text = type
		b.pressed.connect(func(): setup(type))
		choices.add_child(b)
	setup("T2")
	if "--enemy-capture" in OS.get_cmdline_user_args(): call_deferred("capture")

func setup(type: String) -> void:
	kind = type
	combat.reset()
	combat.enemies.clear()
	combat.walls = combat.DEFAULT_WALLS.slice(0,4)
	combat.player = Vector2(100,100)
	combat.add_archetype(kind,Vector2(175,100))
	paused = false
	feedback.reset()
	commands.clear()
	combat_audio.stop_all()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F5:
		setup(kind)
		return
	super._unhandled_input(event)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_instance_valid(warnings): return
	warnings.queue_redraw()
	hud.text = "敌人专项场 · %s   生命 %d   专注 %d\n净光削壳 / 空格躲预警 · 本场不写主线存档" % [kind,combat.hp,combat.focus]
	status.text = "F5重新开始本敌人 · Esc暂停 · 左/右键灯击/净光 · 1护灯 · 2灯雨\n投孢：保持距离；冲锋：锁定方向后侧移；护冠：破壳后近战；孢囊：预警中击毁。"

func capture() -> void:
	for type in ["T2","T3","T4","T5","EL1"]:
		setup(type)
		combat.player = Vector2(155,100) if type in ["T4","EL1"] else Vector2(135,100)
		for i in 15: await get_tree().physics_frame
		paused = true
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("FUNGUS_ENEMY_CAPTURE")+"-"+type+".png")
	combat_audio.stop_all()
	get_tree().quit()
