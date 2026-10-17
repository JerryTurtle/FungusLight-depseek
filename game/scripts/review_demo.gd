extends RefCounted
var item := 0
var frame := 0
var direction_index := 0
var manual_direction := false
var loop := true
var finished := false
var caption := ""
var charge_preview := false

func setup(scene) -> void:
	var m = scene.combat
	m.reset()
	m.enemies.clear()
	m.player = Vector2(110,95)
	m.walls = m.walls.slice(0,4)
	m.doors.clear()
	scene.feedback.reset()
	scene.combat_audio.stop_all()
	scene.death_age = 0
	scene.scan_tick = -1000
	charge_preview = false

func advance(scene) -> void:
	var m = scene.combat
	var section := int(frame/180)
	var t := frame % 180
	if item == 0:
		section = int(frame/40)
		t = frame % 40
	elif item == 1:
		section = int(frame/120)
		t = frame % 120
	if t == 0: setup(scene)
	var directions := [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]
	var dir: Vector2 = directions[direction_index if manual_direction else (int(section/9)%4 if item == 0 else section%4)]
	if item == 1 and not manual_direction: dir = directions[int(section/3)%4]
	var move := Vector2.ZERO
	var aim := dir*48
	var command := ""
	var hurt := 0.0
	scene.environment_fx = item == 4
	if item == 0:
		var actions := ["idle","walk","melee","light","shield","rain","dodge","hurt","dead"]
		var action: String = actions[section%9]
		caption = ["待机","移动","灯击","净光","护灯","灯雨","闪避","受击","倒地"][section%9]
		if action == "walk" and t < 20: move = dir
		if t == 1 and action in ["melee","light","shield","rain","dodge"]: command = action
		if t == 2 and action in ["hurt","dead"]: hurt = 12 if action == "hurt" else 200
	elif item == 1:
		var phase := section%3
		caption = ["四向挥空","四向命中","净光削壳 → 灯击 → 破壳"][phase]
		if t == 0 and phase != 0:
			var target = m.add_enemy(m.player+dir*18,true)
			if phase == 2: target.armor_layers = 2
		if t == 5: command = "light" if phase == 2 else "melee"
		if phase == 2:
			if t == 50: command = "melee"
			if t == 100: command = "light"
	elif item == 2:
		var phase := section%8
		caption = ["净光 · 下","净光 · 斜向","净光 · 左","净光 · 墙体终止","护灯 · 成形与吸收","护灯 · 破盾","灯雨 · 落点与命中","灯雨 · 移出范围"][phase]
		if phase < 4:
			aim = [Vector2.DOWN,Vector2(1,-0.4),Vector2.LEFT,Vector2.RIGHT][phase]*55
			if t == 0:
				m.add_enemy(m.player+aim.normalized()*55,true)
				if phase == 3: m.walls.append(Rect2(140,65,8,60))
			if t == 5: command = "light"
		elif phase < 6:
			if t == 5: command = "shield"
			if t == 35: hurt = 12
			if t == 70 and phase == 5: hurt = 20
		else:
			aim = Vector2(45,0)
			if t == 0: m.add_enemy(m.player+aim,true)
			if t == 5: command = "rain"
			if t == 40 and phase == 7: m.enemies[0].pos += Vector2(0,35)
	elif item == 3:
		var phase := section%6
		caption = ["追击怪前摇与近击","弹体命中","闪避躲过弹体","毒区伤害与闪避","冲锋线测试发射器预警","护盾挡住弹体"][phase]
		if t == 0 and phase == 0: m.add_enemy(m.player+Vector2(30,0),false)
		if phase in [1,2,5] and t == 30: m.spawn_projectile(m.player+Vector2(60,0),Vector2(-120,0))
		if phase == 2 and t == 53:
			command = "dodge"
			move = Vector2.UP
		if phase == 3:
			if t == 0: m.spawn_zone(m.player)
			if t == 118: command = "dodge"
		if phase == 4:
			charge_preview = t < 60
			if t == 60:
				var shot: Dictionary = m.spawn_projectile(m.player+Vector2(70,0),Vector2(-240,0))
				shot.ttl = 18
		if phase == 5 and t == 5: command = "shield"
	elif item == 4:
		caption = "菌洞 / 水道 · 呼吸光、孢子、扫描与技能叠加"
		scene.sewer = section%2 == 1
		if t == 0:
			m.add_enemy(m.player+Vector2(45,0),true)
			m.spawn_zone(Vector2(165,130))
			scene.scan_tick = m.tick
		aim = Vector2(45,0)
		if t == 5: command = "shield"
		if t == 40: command = "rain"
		if t == 95: command = "light"
	m.step(move,aim,command)
	if hurt > 0: m.damage_player(hurt)
	frame += 1
	if frame >= 1440:
		finished = true
		if loop: frame = 0
		else: scene.paused = true
