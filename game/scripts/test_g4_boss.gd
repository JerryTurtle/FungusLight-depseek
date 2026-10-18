extends SceneTree
## G4 Boss mechanics at the design HP target (2200), independent of the
## shortened 150-HP route build. This proves phase/armor mechanics, not balance.
const Combat = preload("res://scripts/campaign_combat.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func _initialize() -> void:
	var c = Combat.new()
	c.reset()
	c.enemies.clear()
	c.enemy_specs.BOSS.hp = 2200
	c.enemy_specs.BOSS.damage = 20
	var boss: Dictionary = c.add_archetype("BOSS",Vector2(200,90))
	check(boss.max_hp == 2200 and boss.phase == 0, "boss design HP 2200")
	boss.hp = 2200 * 0.7
	c.step(Vector2.ZERO,Vector2.RIGHT)
	check(int(boss.phase) == 1 and int(boss.armor_layers) == 2 and int(boss.hp) == 1540, "phase 1 at 70%, shell 2")
	boss.hp = 2200 * 0.35
	c.step(Vector2.ZERO,Vector2.RIGHT)
	check(int(boss.phase) == 2 and int(boss.armor_layers) == 0 and bool(boss.core_open) and int(boss.hp) == 770, "phase 2 at 35%, core exposed")
	# Let the boss run its attack cycle long enough to exercise warnings/damage.
	for i in 240:
		c.step(Vector2.ZERO,Vector2.RIGHT)
	check(c.hp > 0, "boss phase 2 does not immediately kill full-health player")
	check(c.enemies.size() == 1 and boss.hp > 0, "boss remains controllable")
	print("G4_BOSS_TEST checks=%d failures=%d hp=%d phase=%d" % [checks,failures,int(c.hp),int(boss.phase)])
	quit(1 if failures else 0)
