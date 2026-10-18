extends SceneTree
## G4-009 presentation checks: sub-pixel actor snapping, light-cast shake,
## reduced-motion opt-out, and the lingering light effect staying bounded.

const Campaign = preload("res://scripts/campaign.gd")
const Art = preload("res://scripts/world_art.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var art = Art.new()
	art.subpixel_actors = false
	check(art.snap_actor(Vector2(10.2,20.7)) == Vector2(10,21),"review bench keeps integer actor snapping")
	art.subpixel_actors = true
	var snapped: Vector2 = art.snap_actor(Vector2(10.13,20.62))
	check(is_equal_approx(snapped.x*4.0,roundf(snapped.x*4.0)) and is_equal_approx(snapped.y*4.0,roundf(snapped.y*4.0)),"campaign actor lands on one screen pixel")
	check(snapped.distance_to(Vector2(10.13,20.62)) < 0.2,"campaign sub-pixel offset stays tiny")

	var scene = Campaign.new()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.saves.directory = ProjectSettings.globalize_path("res://").path_join("../qa/runtime-profile/g4-visual-"+str(Time.get_ticks_usec())).simplify_path()
	scene.new_game()
	scene.wake_left = 0
	scene.hide_player = false
	check(scene.art.subpixel_actors,"campaign enables quarter-pixel actors")
	scene.combat.enemies.clear()
	scene.combat.player = Vector2(75,110)
	var previous_x: float = scene.combat.player.x
	var moved_ticks := 0
	for i in 120:
		scene.combat.step(Vector2.RIGHT,Vector2.RIGHT)
		if scene.combat.player.x > previous_x + 0.001: moved_ticks += 1
		previous_x = scene.combat.player.x
	check(moved_ticks >= 118,"rightward movement has no empty physics steps")
	var render_x: float = scene.art.snap_actor(scene.combat.player).x*4.0
	check(is_equal_approx(render_x,roundf(render_x)),"renderer lands on a physical pixel after movement")

	scene.preferences.reduced_motion = false
	scene.reset_screen_shake()
	scene.start_screen_shake(4.0,10)
	check(scene.shake_left == 10,"light shake is armed")
	scene.update_screen_shake()
	check(scene.world.position != Vector2.ZERO,"light shake offsets the world")
	for i in 12: scene.update_screen_shake()
	check(scene.world.position == Vector2.ZERO and scene.floating_ui.position == Vector2.ZERO,"light shake returns to rest")
	scene.preferences.reduced_motion = true
	scene.start_screen_shake(4.0,10)
	check(scene.shake_left == 0 and scene.world.position == Vector2.ZERO,"reduced motion suppresses shake")

	scene.preferences.reduced_motion = false
	scene.combat.clear_hazards()
	scene.combat.enemies.clear()
	scene.combat.player = Vector2(100,100)
	scene.combat.focus = 100
	scene.combat.begin("light",Vector2.ZERO,Vector2.RIGHT)
	for i in 13: scene.combat.step(Vector2.ZERO,Vector2.RIGHT)
	scene.handle_visual_events()
	check(scene.shake_left > 0,"light release triggers the screen shake")
	check(scene.combat.action == "light" and scene.combat.age >= 12,"light cast still resolves on its approved timing")

	scene.combat_audio.stop_all()
	scene.queue_free()
	await process_frame
	print("G4_VISUAL_TEST checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
