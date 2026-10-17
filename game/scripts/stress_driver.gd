extends RefCounted
var frame := 0
var caption := "负载验证"
var finished := false
var charge_preview := false

func advance(scene) -> void:
	var m = scene.combat
	if frame % 600 == 0:
		m.reset()
		m.enemies.clear()
		m.player = Vector2(110,95)
		for i in 6:
			var enemy = m.add_enemy(Vector2(45+i*37,65+(i%2)*65),false)
			enemy.hp = 10000
		scene.feedback.reset()
	m.hp = 1000
	m.focus = 100
	var command := ""
	if frame%120 == 0: command = "melee"
	if frame%120 == 30: command = "light"
	if frame%120 == 60: command = "shield"
	if frame%120 == 90: command = "rain"
	while m.projectiles.size() < 20: m.spawn_projectile(Vector2(295,45+m.projectiles.size()*5),Vector2(-80,0))
	if m.zones.size() < 8: m.spawn_zone(Vector2(35+m.zones.size()*33,125))
	m.step(Vector2.from_angle(float(frame)/90)*0.4,Vector2(45,0),command)
	scene.environment_fx = true
	scene.preferences.low_effects = frame >= 27000
	scene.preferences.reduced_motion = frame >= 27000
	scene.preferences.reduced_flash = frame >= 27000
	if frame%6 == 0:
		for i in 10: scene.feedback.effects.append({"kind":"armor_break","pos":Vector2(30+i*27,70+(i%2)*40),"tick":m.tick,"armor":1,"broken":false})
	frame += 1
