extends RefCounted
## Danger geometry follows the archetype's actual configuration. Boss sectors and
## field hazards are drawn from the same values the damage checks use.
static func draw(canvas: Node2D, model) -> void:
	_draw_field_hazards(canvas,model)
	for enemy in model.enemies:
		if enemy.hp <= 0 or not enemy.has("archetype"): continue
		var spec: Dictionary = model.enemy_specs[enemy.archetype]
		var pos: Vector2 = enemy.pos
		if enemy.archetype == "EL1":
			# Readable elite cap; the rearm watch fills it over exactly 0.8s.
			canvas.draw_arc(pos-Vector2(0,20),13,PI,TAU,12,Color("f6d68b"),1)
		if enemy.state == "rearm":
			var telegraph := maxf(1.0,float(spec.get("rearm_telegraph",48)))
			var progress := clampf(float(enemy.age)/telegraph,0.0,1.0)
			var center := pos-Vector2(0,20)
			canvas.draw_arc(center,16,0,TAU,24,Color(0.32,0.27,0.18,0.8),1)
			canvas.draw_arc(center,16,-PI/2,-PI/2+TAU*progress,24,Color("e3ca77"),2)
			for layer in int(spec.get("rearm_layers",2)):
				if progress >= 0.5+float(layer)*0.5:
					canvas.draw_circle(center+Vector2.from_angle(-PI/2+TAU*progress-0.4+float(layer)*0.8)*16,1.5,Color("f2dc93"))
			continue
		if enemy.archetype == "BOSS":
			_draw_boss(canvas,model,enemy,spec,pos)
			continue
		if enemy.state != "attack" or enemy.age >= spec.windup+spec.active: continue
		var direction: Vector2 = enemy.dir
		var color := Color("f0b474") if enemy.age < spec.windup else Color("f17b73")
		match enemy.archetype:
			"T2":
				canvas.draw_circle(pos-Vector2(0,18),3,color)
				canvas.draw_line(pos,pos+direction*18,color,1)
			"T6":
				# Two visible launch points; a filled dot marks the shot already fired.
				for index in int(spec.get("shots",2)):
					var muzzle: Vector2 = model.t6_muzzle(enemy,index)
					var fired: bool = int(enemy.get("shots_fired",0)) > index
					canvas.draw_circle(muzzle,2.5,Color("ffd8a0") if fired else color)
					canvas.draw_line(pos,muzzle,color,0.5)
				canvas.draw_arc(pos,18.0,direction.angle()-0.22,direction.angle()+0.22,8,color,0.7)
			"T3":
				for side in [-5,5]: canvas.draw_line(pos+direction.orthogonal()*side,pos+direction*72+direction.orthogonal()*side,color,0.7)
				canvas.draw_line(pos+direction*66-direction.orthogonal()*5,pos+direction*72,color,1)
				canvas.draw_line(pos+direction*66+direction.orthogonal()*5,pos+direction*72,color,1)
			"EL2":
				if str(enemy.get("elite_attack","charge")) == "charge":
					var reach := float(spec.get("charge_speed",160))*float(spec.active)/60.0
					for side in [-5,5]: canvas.draw_line(pos+direction.orthogonal()*side,pos+direction*reach+direction.orthogonal()*side,color,0.7)
					canvas.draw_line(pos+direction*(reach-6)-direction.orthogonal()*5,pos+direction*reach,color,1)
					canvas.draw_line(pos+direction*(reach-6)+direction.orthogonal()*5,pos+direction*reach,color,1)
			"T5": canvas.draw_arc(pos,float(spec.range),0,TAU,24,color,1)
			_:
				canvas.draw_arc(pos,float(spec.range),direction.angle()-PI/4,direction.angle()+PI/4,24,color,1)
				for edge in [-PI/4,PI/4]: canvas.draw_line(pos,pos+direction.rotated(edge)*float(spec.range),color,0.7)

static func _draw_field_hazards(canvas: Node2D, model) -> void:
	for hazard in model.field_hazards:
		var warning := int(model.tick) < int(hazard.warn_until)
		var radius := float(hazard.radius)
		var rect: Rect2 = hazard.rect
		if str(hazard.shape) == "circle":
			var center: Vector2 = hazard.pos
			if warning:
				var total := maxf(1.0,float(hazard.warn_until)-float(hazard.get("warn_start",hazard.warn_until)))
				var progress := clampf((float(model.tick)-float(hazard.get("warn_start",hazard.warn_until)))/total,0.0,1.0)
				var pulse := 0.5+0.5*sin(float(model.tick)/6.0)
				canvas.draw_circle(center,radius,Color(0.82,0.36,0.24,0.10+0.06*pulse))
				canvas.draw_circle(center,radius*progress,Color(0.9,0.45,0.25,0.10))
				canvas.draw_arc(center,radius,0,TAU,28,Color("f0b474"),1.2)
			else:
				canvas.draw_circle(center,radius,Color(0.85,0.30,0.18,0.32))
				canvas.draw_arc(center,radius,0,TAU,28,Color("f17b73"),1.5)
		else:
			if warning:
				canvas.draw_rect(rect,Color(0.32,0.55,0.66,0.16))
				canvas.draw_rect(rect,Color("8fb8c9"),false,1)
				var total := maxf(1.0,float(hazard.warn_until)-float(hazard.get("warn_start",hazard.warn_until)))
				var progress := clampf((float(model.tick)-float(hazard.get("warn_start",hazard.warn_until)))/total,0.0,1.0)
				canvas.draw_line(Vector2(rect.position.x,rect.end.y),Vector2(rect.position.x+rect.size.x*progress,rect.end.y),Color("a8d3e2"),1.5)
			else:
				# Running water: translucent band with travelling ripples.
				canvas.draw_rect(rect,Color(0.28,0.55,0.72,0.26))
				for x in range(int(rect.position.x)+16,int(rect.end.x),32):
					var wave := sin(float(model.tick)/7.0+float(x)/24.0)*4.0
					canvas.draw_line(Vector2(x,rect.position.y+4+wave),Vector2(x+12,rect.position.y+4-wave),Color(0.65,0.85,0.95,0.5),0.8)
					canvas.draw_line(Vector2(x,rect.position.y+16-wave),Vector2(x+10,rect.position.y+16+wave),Color(0.65,0.85,0.95,0.35),0.6)

static func _draw_boss(canvas: Node2D, model, enemy: Dictionary, spec: Dictionary, pos: Vector2) -> void:
	var core_open := bool(enemy.get("core_open",false))
	var age := int(enemy.get("age",0))
	if core_open:
		# The core glow is readable feedback; the whole battler is vulnerable
		# at all times now, so this is not a damage gate.
		var pulse := 0.5+0.5*sin(float(model.tick)/5.0)
		canvas.draw_circle(pos,7.0+pulse*2.0,Color(1.0,0.82,0.35,0.18))
		canvas.draw_arc(pos,13,0,TAU,26,Color("f5d87a"),2)
		canvas.draw_arc(pos,9.0+pulse*3.0,0,TAU,20,Color(1.0,0.90,0.55,0.55),1)
	else:
		canvas.draw_arc(pos,10,0,TAU,20,Color(0.50,0.40,0.42,0.75),1)
	if str(enemy.state) == "transition":
		var safe := maxi(1,int(spec.get("safe_window",72)))
		var progress := clampf(float(age)/float(safe),0.0,1.0)
		canvas.draw_arc(pos,18.0+12.0*progress,0,TAU,28,Color(0.70,0.90,0.80,0.70),1)
		return
	if str(enemy.state) != "attack": return
	var attack := str(enemy.get("boss_attack",""))
	var timing: Dictionary = spec.get("attacks",{}).get(attack,{})
	var windup := int(timing.get("warn",0))
	var active := int(timing.get("active",1))
	if attack == "sweep" and age < windup+active:
		# Exactly the model's sector: same origin/direction/radius/half-angle.
		var shape: Dictionary = model.boss_sweep_shape(enemy)
		var origin: Vector2 = shape.origin
		var facing: Vector2 = shape.direction
		var radius: float = shape.radius
		var half: float = shape.half_angle
		var color := Color("f0b474") if age < windup else Color("f17b73")
		canvas.draw_arc(origin,radius,facing.angle()-half,facing.angle()+half,32,color,1.5)
		for edge in [-half,half]: canvas.draw_line(origin,origin+Vector2.from_angle(facing.angle()+edge)*radius,color,0.8)
		if age >= windup:
			canvas.draw_arc(origin,radius-1.0,facing.angle()-half,facing.angle()+half,32,Color(1.0,0.35,0.25,0.35),3)
