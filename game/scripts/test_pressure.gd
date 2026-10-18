extends SceneTree
## A15 smoke: narrow gate + closed/open dynamic door + 10 pursuers.
## This is a deterministic model pressure check, not a human play session.

const Combat = preload("res://scripts/combat_model.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func _initialize() -> void:
	var combat = Combat.new()
	combat.reset()
	combat.enemies.clear()
	combat.doors.clear()
	var pressure_walls: Array[Rect2] = [
		Rect2(0,0,320,27), Rect2(0,159,320,21), Rect2(0,0,8,180), Rect2(312,0,8,180),
		Rect2(120,40,20,55), Rect2(120,120,20,40),
	]
	combat.walls = pressure_walls
	var pressure_doors: Array[Dictionary] = [{"id":"gate","rect":Rect2(120,95,20,25),"open":false}]
	combat.doors = pressure_doors
	combat.player = Vector2(60,110)
	combat.hp = 100000.0
	for i in 10:
		var enemy := combat.add_enemy(Vector2(170+(i%4)*14,100+(i/4)*14))
		enemy.alert = true
	var started := Time.get_ticks_usec()
	var crossed := 0
	for tick in 900:
		combat.step(Vector2.ZERO, Vector2.RIGHT)

	var elapsed := (Time.get_ticks_usec()-started)/1000.0
	var inside := 0
	crossed = 0
	for enemy in combat.enemies:
		if enemy.hp > 0 and enemy.pos.x < 120: crossed += 1
	for enemy in combat.enemies:
		if enemy.hp > 0 and combat.blocked(enemy.pos,2): inside += 1
	check(combat.enemies.size() == 10, "pressure keeps ten pursuers")
	check(combat.path_queries > 100, "pressure issued >100 path queries")
	check(inside == 0, "no pursuer inside walls/blockers")
	check(crossed >= 1, "at least one pursuer crossed the opened gate")
	check(elapsed < 15000.0, "pressure 900 steps under 15s (actual %.0f ms)" % elapsed)
	print("PRESSURE_TEST checks=%d failures=%d path_queries=%d crossed=%d ms=%.0f" % [checks,failures,combat.path_queries,crossed,elapsed])
	quit(1 if failures else 0)
