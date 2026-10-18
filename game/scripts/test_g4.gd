extends SceneTree
## G4 structural smoke: 31 nodes, 30 encounters, 9 puzzles, choices and endings.
const Progress = preload("res://scripts/campaign_state.gd")
const Combat = preload("res://scripts/campaign_combat.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func _initialize() -> void:
	var p = Progress.new()
	check(p.content.nodes.size() >= 31, "31+ main nodes")
	check(p.content.encounters.size() >= 31, "30+ main encounters + tutorial")
	check(p.puzzle_ids.size() == 9, "9 puzzles")
	check(p.node().id == "N0-01", "start node")
	var snap: Dictionary = p.snapshot(Vector2(80,110),100,100)
	check(p.validate(snap).is_empty(), "initial snapshot valid: " + p.validate(snap))
	check(p.max_hp() == 100.0, "base HP")
	p.node_id = "N0-02"
	p.flags.pipe = true
	p.flags.S01 = true
	p.flags.P01 = true
	p.flags.S02 = true
	p.flags.tutorial = true
	p.flags.E01 = true
	var m1 := p.start_event("M1")
	check(m1 and p.finish_event("melee"), "M1 choice")
	check(p.max_hp() == 120.0, "M1 HP")
	p.node_id = "N1-05"
	for flag in ["S03","E02","E03","E04","E05","E06","P02","E07","E08","E09","E10","E11"]: p.flags[flag] = true
	var m2 := p.start_event("M2")
	check(m2 and p.finish_event("energy"), "M2 choice")
	check(p.skills().shield, "M2 shield")
	check(p.max_hp() == 130.0, "M2 HP")
	check(p.max_focus() == 110.0, "M2 focus")
	check(p.hit_focus_gain() == 6, "M2 energy")
	p.node_id = "N2-08"
	for flag in ["E12","E13","E14","E15","E16","E17","E18","E19","E20","P03","P04","P05","S04","S05","S06","S07"]: p.flags[flag] = true
	var m3 := p.start_event("M3")
	check(m3 and p.finish_event("cost"), "M3 choice")
	check(p.skills().rain, "M3 rain")
	check(p.light_cost() == 15, "M3 light cost")
	check(p.max_hp() == 140.0, "M3 HP")
	p.node_id = "N3-05"
	for flag in ["E21","E22","E23","E24","E25","P06","P07","P08"]: p.flags[flag] = true
	var m4 := p.start_event("M4")
	check(m4 and p.finish_event("life"), "M4 choice")
	check(p.max_hp() == 170.0, "M4 HP")
	check(p.max_focus() == 120.0, "M4 focus")
	p.node_id = "N4-06"
	for flag in ["E26","E27","E28","E29","E30","E31","E32","E33","E34","E35","E36","M4","P08","P09","S08","S09"]: p.flags[flag] = true
	p.set_ending("restore")
	check(p.ending_id() == "restore", "restore ending")
	p.flags.S12 = true
	var late: Dictionary = p.snapshot(Vector2(80,110),170,120)
	var late_error := p.validate(late)
	for eid in p.encounter_ids:
		var req := str(p.content.encounters[eid].get("requires",""))
		if not req.is_empty() and p.has(eid) and not p.has(req): late_error += " | "+eid+"<-"+req
	check(late_error.is_empty(), "late snapshot valid: " + late_error)
	p.flags.EQ_FOCUS = true
	p.flags.EQ_THROTTLE = true
	p.flags.EQ_CLASP = true
	p.auto_equip()
	check(p.equipment().charm == "guardian_knot" and p.equipment().lens == "focus_lens", "equipment defaults")
	check(is_equal_approx(p.light_damage(),28.8), "focus lens light damage")
	p.equip("lens","throttle_lens")
	check(p.light_cost() == 12, "throttle lens light cost")
	p.equip("charm","artisan_clasp")
	check(p.shield_capacity() == 35, "artisan clasp shield capacity")
	check(p.shield_cooldown() == 540, "artisan clasp shield cooldown")
	p.flags.Q2 = true
	p.equip("charm","ember_talisman")
	check(p.heal_amount() == 45.0 and p.heal_windup() == 42, "ember talisman heal")
	p.equip("charm","guardian_knot")
	check(p.equipment().lens == "throttle_lens" and p.equipment().charm == "guardian_knot", "equipment slots independent")
	check(p.rewards().M4 and not p.rewards().Q1, "rewards")
	# Second ending and optional equipment.
	p.flags.END_RESTORE = false
	p.flags.END_SEAL = true
	p.flags.S11 = true
	check(p.ending_id() == "seal", "seal ending")
	p.flags.Q1a = true; p.flags.Q1b = true; p.flags.Q1c = true; p.flags.Q1 = true
	p.flags.Q2a = true; p.flags.Q2b = true; p.flags.Q2c = true; p.flags.Q2 = true
	check(p.owns("clear_mirror") and p.owns("ember_talisman"), "optional equipment")
	# Every switch puzzle can complete from its authored switches.
	for puzzle in ["P03","P04","P05","P06","P07","P08","P09"]:
		p.flags[puzzle] = false
		for part in p.content.puzzles[puzzle].flags: p.flags[part] = false
		for node in p.content.nodes:
			for object in node.objects:
				if object.get("puzzle","") == puzzle:
					p.set_switch(object)
		check(p.has(puzzle), "puzzle completes "+puzzle)
	# Chapter-2 branch independence: neither branch requires the other's reward.
	p.flags.P05 = false; p.flags.E16 = false; p.flags.E17 = false
	check(not p.node_reachable("N2-06", p.flags), "merge closed without branch B")
	p.flags.P05 = true; p.flags.E16 = true; p.flags.E17 = true
	check(p.node_reachable("N2-06", p.flags), "merge opens with both branches")
	check(p.content.nodes.filter(func(n): return n.id in ["N2-02","N2-04"]).size() == 2, "two chapter-2 branch roots")
	# Boss phases and T6/EL2 can be added without errors.
	var c = Combat.new()
	c.reset()
	c.enemies.clear()
	var boss: Dictionary = c.add_archetype("BOSS",Vector2(200,90))
	check(boss.archetype == "BOSS" and boss.phase == 0, "boss entity")
	c.add_archetype("T6",Vector2(120,90))
	c.add_archetype("EL2",Vector2(140,90))
	check(c.enemies.size() == 3, "T6/EL2 boss entities")
	c.step(Vector2.ZERO,Vector2.RIGHT)
	check(c.hp > 0, "boss step runs")
	print("G4_TEST checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
