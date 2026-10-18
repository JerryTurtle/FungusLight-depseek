extends RefCounted
## Bounded visual records, advanced exclusively by simulation ticks.
var effects: Array[Dictionary] = []
var numbers: Array[Dictionary] = []
var sparks: Array[Dictionary] = []

func reset() -> void:
	effects.clear()
	numbers.clear()
	sparks.clear()

func consume(model) -> void:
	effects = effects.filter(func(e): return model.tick-e.tick < 18)
	numbers = numbers.filter(func(e): return model.tick-e.tick < 36)
	sparks = sparks.filter(func(e): return model.tick-e.tick < 22)
	for event in model.events:
		var kind: String = event.kind
		if kind not in ["hit","hurt","shield_absorb","shield_end","armor_break"]: continue
		var position: Vector2 = model.player-Vector2(0,12)
		if kind in ["hit","armor_break"]:
			var target: Dictionary = model.enemy_by_id(int(event.target))
			if target.is_empty(): continue
			position = target.pos-Vector2(0,14)
		effects.append({"kind":kind,"pos":position,"tick":model.tick,"armor":int(event.get("armor_layers",0)),"broken":event.get("reason","") == "broken"})
		if kind in ["hit","armor_break"]:
			for i in (10 if kind == "armor_break" else 6):
				var angle := float(i)*TAU/float(10 if kind == "armor_break" else 6) + float(model.tick%7)*0.11
				var speed := 0.9+float((int(event.target)+i*3)%5)*0.35
				sparks.append({"pos":position,"vel":Vector2.from_angle(angle)*speed,"tick":model.tick,"life":16+i%5,"hot":i%3==0})
		if kind in ["hit","hurt"] and event.damage > 0:
			var found := false
			for number in numbers:
				if number.target == event.target and model.tick-number.tick < 12:
					number.amount += event.damage
					found = true
					break
			if not found: numbers.append({"target":event.target,"pos":position-Vector2(0,17),"amount":event.damage,"tick":model.tick})
	while effects.size() > 64: effects.pop_front()
	while numbers.size() > 16: numbers.pop_front()
	while sparks.size() > 96: sparks.pop_front()

func draw(canvas: CanvasItem, tick: int, preferences) -> void:
	for effect in effects:
		var age: int = tick-effect.tick
		var alpha := (1.0-float(age)/18.0)*(0.5 if preferences.reduced_flash else 1.0)
		var tint := Color(1,0.88,0.6,alpha) if effect.armor > 0 or effect.kind == "armor_break" else Color(0.8,0.95,0.9,alpha)
		if effect.kind == "hurt": tint = Color(0.9,0.5,0.4,alpha)
		if effect.kind in ["shield_absorb","shield_end"]:
			canvas.draw_arc(effect.pos,17,0,TAU,24,tint,1)
		elif preferences.low_effects or preferences.reduced_motion:
			canvas.draw_arc(effect.pos,5,0,TAU,12,tint,1)
		else:
			for piece in (8 if effect.kind == "armor_break" else 4):
				var axis := Vector2.from_angle(piece*TAU/(8 if effect.kind == "armor_break" else 4))
				canvas.draw_line(effect.pos+axis*(3+age*0.5),effect.pos+axis*(5+age*0.7),tint,1)

func draw_sparks(canvas: CanvasItem, tick: int, preferences) -> void:
	if preferences.low_effects or preferences.reduced_motion: return
	for spark in sparks:
		var age: int = tick-spark.tick
		var t := float(age)/float(spark.life)
		if t >= 1.0: continue
		var p: Vector2 = spark.pos+spark.vel*float(age)*(1.0-0.45*t)
		var color := Color(0.86,1.0,0.92,1.0-t) if spark.hot else Color(0.34,0.94,0.80,1.0-t)
		if not spark.hot and int(spark.life)%4 == 0: color = Color(1.0,0.84,0.40,1.0-t)
		canvas.draw_rect(Rect2(p.round(),Vector2.ONE*(2 if spark.hot else 1)),color)
		canvas.draw_line(p,p-spark.vel*2.0,Color(color.r,color.g,color.b,(1.0-t)*0.55),0.5)

func draw_numbers(canvas: CanvasItem, tick: int, preferences) -> void:
	for number in numbers:
		var age: int = tick-number.tick
		var lift := 0.0 if preferences.reduced_motion else minf(age*0.15,4)
		var position: Vector2 = (number.pos-Vector2(0,lift))*4
		var text := str(snappedf(number.amount,0.1))
		canvas.draw_string_outline(ThemeDB.fallback_font,position,text,HORIZONTAL_ALIGNMENT_LEFT,-1,24,3,Color(0.06,0.07,0.05,1.0-float(age)/36))
		canvas.draw_string(ThemeDB.fallback_font,position,text,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color(1,0.92,0.7,1.0-float(age)/36))
