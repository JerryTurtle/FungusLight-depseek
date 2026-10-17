extends RefCounted
## Shared renderer for live combat and the G2 pose workbench. No damage logic.
var cleric: Texture2D = preload("res://assets/original/Characters/Cleric.png")
var fungus: Texture2D = preload("res://assets/original/Characters/Fungus - red.png")
var tiles: Texture2D = preload("res://assets/original/Tilesets/Complete.png")

func row(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y): return 2 if direction.x > 0 else 1
	return 0 if direction.y >= 0 else 3

func tile(canvas: CanvasItem, position: Vector2, cell: Vector2i) -> void:
	canvas.draw_texture_rect_region(tiles,Rect2(position,Vector2(16,16)),Rect2(Vector2(cell)*16,Vector2(16,16)))

func background(canvas: CanvasItem, model, sewer: bool) -> void:
	canvas.draw_rect(Rect2(0,0,320,180),Color("242a25"))
	for y in range(27,159,16):
		for x in range(0,320,16):
			tile(canvas,Vector2(x,y),Vector2i(4,41) if sewer else Vector2i(6,4))
	for wall in model.walls:
		canvas.draw_rect(wall,Color("242322"))
		for y in range(int(wall.position.y),int(wall.end.y),16):
			for x in range(int(wall.position.x),int(wall.end.x),16):
				var size := Vector2(minf(16,wall.end.x-x),minf(16,wall.end.y-y))
				var cell := Vector2(2,1)
				canvas.draw_texture_rect_region(tiles,Rect2(Vector2(x,y),size),Rect2(cell*16,size))
	for door in model.doors:
		canvas.draw_rect(door.rect,Color("98724b") if not door.open else Color(0.5,0.73,0.62,0.15))
		if not door.open:
			for y in range(int(door.rect.position.y)+2,int(door.rect.end.y),6):
				canvas.draw_line(Vector2(door.rect.position.x,y),Vector2(door.rect.end.x,y),Color("382c24"),2)
		else:
			canvas.draw_line(door.rect.position,door.rect.position+Vector2(door.rect.size.x,0),Color("9cbb87"),1)

func hand_region(direction: Vector2, frame: int) -> Rect2:
	# Coordinates of existing hand pixels in each original 16x32 frame.
	var positions := [
		[Vector2(12,25),Vector2(13,24),Vector2(14,22)],
		[Vector2(8,26),Vector2(7,27),Vector2(5,26)],
		[Vector2(10,26),Vector2(7,27),Vector2(6,26)],
		[Vector2(13,20),Vector2(14,24),Vector2(14,24)]
	]
	return Rect2(positions[row(direction)][frame],Vector2(2,2))

func staff(canvas: CanvasItem, grip: Vector2, angle: float, extension: float) -> void:
	var axis := Vector2.from_angle(angle)
	# Same 17px staff, held 2px from the butt instead of 5px.
	# Draw one continuous shaft through the original hand's centre.
	var tip := (grip + axis*(15+extension)).round()
	var butt := (grip-axis*2).round()
	canvas.draw_line(butt,tip,Color("292224"),3)
	canvas.draw_line(butt,tip,Color("b18a55"),1)
	canvas.draw_rect(Rect2(tip-Vector2(3,3),Vector2(7,7)),Color("332c34"))
	canvas.draw_rect(Rect2(tip-Vector2(2,2),Vector2(5,5)),Color("ce9256"))
	canvas.draw_rect(Rect2(tip-Vector2(1,2),Vector2(3,4)),Color("fff1b0"))


func enemy_texture(kind: String) -> Texture2D:
	match kind:
		"T2": return preload("res://assets/original/Characters/Fungus - violet.png")
		"T3": return preload("res://assets/original/Characters/Sewers monster.png")
		"T4","EL1": return preload("res://assets/original/Characters/Fungus - King.png")
	return fungus

func spore_pod(canvas: CanvasItem, foot: Vector2, alive: bool, alpha: float = 1.0) -> void:
	var color := Color("b8a15a") if alive else Color("544d3b")
	var body := Color("574c40")
	var cap := Color("63465b")
	body.a = alpha
	cap.a = alpha
	color.a = alpha
	canvas.draw_rect(Rect2(foot+Vector2(-3,-7),Vector2(6,10)),body)
	canvas.draw_rect(Rect2(foot+Vector2(-8,-15),Vector2(16,8)),cap)
	canvas.draw_rect(Rect2(foot+Vector2(-5,-18),Vector2(10,3)),cap)
	for offset in [Vector2(-5,-12),Vector2(1,-16),Vector2(4,-10)]: canvas.draw_rect(Rect2(foot+offset,Vector2(2,2)),color)

func actor(canvas: CanvasItem, foot: Vector2, direction: Vector2, action: String, age: int, tick: int, moving: bool, player: bool = true, override_texture: Texture2D = null, alpha: float = 1.0) -> void:
	foot = foot.round()
	var texture: Texture2D = cleric if player else fungus
	if override_texture != null: texture = override_texture
	var frame: int = [1,0,1,2][int(tick/8)%4] if moving else 1
	var angle := -PI/2 + (0.28 if row(direction) in [0,3] else (-0.8 if row(direction) == 1 else 0.8))
	var extension := 0.0
	var tint := Color.WHITE
	if action == "melee":
		var keyframe: int = 0 if age < 3 else (1 if age < 6 else (2 if age < 8 else (3 if age < 11 else (4 if age < 16 else 5))))
		var sweep: Array[float] = [-1.0,-0.8,-0.45,0.65,0.85,0.25]
		angle = direction.angle()+sweep[keyframe]
		frame = [1,0,2,2,0,1][keyframe]
	elif action in ["light","shield","rain"]:
		angle = direction.angle()
		var windup: int = {"light":12,"shield":9,"rain":21}[action]
		extension = 3 if age >= windup else 0
		frame = mini(2,int(float(age)/windup*3)) if age < windup else 1
	elif action == "dodge":
		frame = 0 if age < 4 else (2 if age < 8 else 1)
		angle = direction.angle()+PI
	elif action == "hurt":
		tint = Color("ffb5a3") if age < 5 else Color.WHITE
	elif action == "dead":
		if player: staff(canvas,foot+Vector2(4,5),0.15,0)
		var fall: float = [0.2,0.8,PI/2][mini(2,int(age/9))]
		canvas.draw_set_transform(foot,fall,Vector2.ONE)
		canvas.draw_texture_rect_region(texture,Rect2(-8,-25,16,32),Rect2(16,row(direction)*32,16,32),Color(0.61,0.59,0.58,alpha))
		canvas.draw_set_transform(Vector2.ZERO)
		return
	tint.a = alpha
	canvas.draw_set_transform(foot,0,Vector2(1,0.35))
	canvas.draw_circle(Vector2.ZERO,7,Color(0.02,0.04,0.04,0.45))
	canvas.draw_set_transform(Vector2.ZERO)
	var body_origin := foot
	var hand := hand_region(direction,frame)
	var hand_origin := (body_origin+Vector2(-8,-31)+hand.position).round()
	var grip := hand_origin+Vector2.ONE
	var behind := row(direction) == 3
	if player and behind: staff(canvas,grip,angle,extension)
	# Render the original full frame intact: no invented arms or split torso.
	var source := Vector2(frame*16,row(direction)*32)
	canvas.draw_texture_rect_region(texture,Rect2(body_origin+Vector2(-8,-31),Vector2(16,32)),Rect2(source,Vector2(16,32)),tint)
	if player and not behind:
		staff(canvas,grip,angle,extension)
		# Re-layer only the original hand pixels over the shaft, in their original location.
		canvas.draw_texture_rect_region(texture,Rect2(hand_origin,hand.size),Rect2(source+hand.position,hand.size),tint)

func target(canvas: CanvasItem, foot: Vector2, hp: float, alpha: float = 1.0) -> void:
	var wood := Color("775c40"); wood.a = alpha
	var dark := Color("362b29"); dark.a = alpha
	var face := Color("c0a16e") if hp > 0 else Color("625746"); face.a = alpha
	var inner := Color("765443"); inner.a = alpha
	var glow := Color("e5cf8c"); glow.a = alpha
	canvas.draw_rect(Rect2(foot+Vector2(-2,-19),Vector2(4,21)),wood)
	canvas.draw_rect(Rect2(foot+Vector2(-9,-24),Vector2(18,17)),dark)
	canvas.draw_rect(Rect2(foot+Vector2(-8,-23),Vector2(16,15)),face)
	canvas.draw_circle(foot+Vector2(0,-16),5,inner)
	canvas.draw_circle(foot+Vector2(0,-16),2,glow)

func light_tip(foot: Vector2, direction: Vector2, age: int) -> Vector2:
	var frame: int = mini(2,int(float(age)/12*3)) if age < 12 else 1
	var hand := hand_region(direction,frame)
	var grip := foot.round()+Vector2(-8,-31)+hand.position+Vector2.ONE
	return (grip+direction.normalized()*(18 if age >= 12 else 15)).round()
