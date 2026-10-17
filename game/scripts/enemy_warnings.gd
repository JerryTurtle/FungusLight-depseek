extends RefCounted
## Danger geometry follows the archetype's actual configuration.
static func draw(canvas: Node2D, model) -> void:
	for enemy in model.enemies:
		if enemy.hp <= 0 or not enemy.has("archetype"): continue
		var spec: Dictionary = model.enemy_specs[enemy.archetype]
		var pos: Vector2 = enemy.pos
		var direction: Vector2 = enemy.dir
		var color := Color("f0b474") if enemy.age < spec.windup else Color("f17b73")
		if enemy.archetype == "EL1":
			canvas.draw_arc(pos-Vector2(0,20),13,PI,TAU,12,Color("f6d68b"),2)
		if enemy.state == "rearm":
			canvas.draw_arc(pos,16,0,TAU,24,Color("e3ca77"),1.5)
		if enemy.state != "attack" or enemy.age >= spec.windup+spec.active: continue
		match enemy.archetype:
			"T2":
				canvas.draw_circle(pos-Vector2(0,18),3,color)
				canvas.draw_line(pos,pos+direction*18,color,1)
			"T3":
				for side in [-5,5]: canvas.draw_line(pos+direction.orthogonal()*side,pos+direction*72+direction.orthogonal()*side,color,0.7)
				canvas.draw_line(pos+direction*66-direction.orthogonal()*5,pos+direction*72,color,1)
				canvas.draw_line(pos+direction*66+direction.orthogonal()*5,pos+direction*72,color,1)
			"T5": canvas.draw_arc(pos,float(spec.range),0,TAU,24,color,1)
			_:
				canvas.draw_arc(pos,float(spec.range),direction.angle()-PI/4,direction.angle()+PI/4,24,color,1)
				for edge in [-PI/4,PI/4]: canvas.draw_line(pos,pos+direction.rotated(edge)*float(spec.range),color,0.7)
