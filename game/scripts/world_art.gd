extends RefCounted
## Shared renderer for live combat and the G2 pose workbench. No damage logic.
var cleric: Texture2D = preload("res://assets/original/Characters/Cleric.png")
var fungus: Texture2D = preload("res://assets/original/Characters/Fungus - red.png")
var boss: Texture2D = preload("res://assets/original/Characters/BOSS.png")
var tiles: Texture2D = preload("res://assets/original/Tilesets/Complete.png")
## The mother is the original 155x135 battler. Drawn at half world scale it is
## 77.5x67.5 world units (310x270 screen pixels at the 4x world scale), i.e. two
## screen pixels per source pixel: readable on the 320x180 canvas while the lower
## half of the arena stays walkable. Anchoring the feet at the actor position
## keeps the existing painter/foot ordering and the core ring at ground level.
const BOSS_DRAW_SCALE := 0.5
const BOSS_TEXTURE_SIZE := Vector2(155,135)
## Campaign actors render on a quarter-pixel grid (one physical screen pixel at
## the 4x world scale). The G2 review bench keeps the accepted integer snapping.
var subpixel_actors := false

func snap_actor(p: Vector2) -> Vector2:
	if not subpixel_actors: return p.round()
	return (p * 4.0).round() / 4.0

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

func staff(canvas: CanvasItem, grip: Vector2, angle: float, extension: float, visual_tick: int = 0, preferences = null) -> void:
	var axis := Vector2.from_angle(angle)
	# Same 17px staff, held 2px from the butt instead of 5px.
	# Draw one continuous shaft through the original hand's centre.
	var tip := snap_actor(grip + axis*(15+extension))
	var butt := snap_actor(grip-axis*2)
	canvas.draw_line(butt,tip,Color("292224"),3)
	canvas.draw_line(butt,tip,Color("b18a55"),1)
	canvas.draw_rect(Rect2(tip-Vector2(3,3),Vector2(7,7)),Color("332c34"))
	# Dark lantern glass with a breathing hard-pixel flame inside. The old
	# solid amber block read as a held torch; this keeps a lantern silhouette.
	canvas.draw_rect(Rect2(tip-Vector2(2,2),Vector2(5,5)),Color("4a2c25"))
	canvas.draw_rect(Rect2(tip+Vector2(-2,-2),Vector2(1,5)),Color("d5a062"))
	canvas.draw_rect(Rect2(tip+Vector2(2,-2),Vector2(1,5)),Color("d5a062"))
	var rest: bool = preferences != null and preferences.reduced_motion
	var frame: int = 0 if rest else int(visual_tick/7)%4
	var lean: int = [0,1,0,-1][frame]
	var flame_height: int = 3 if rest else [4,5,4,3][frame]
	var flame_base := tip+Vector2(0,2)
	canvas.draw_circle(tip+Vector2(0,-1),7.0,Color(1.0,0.62,0.22,0.06 if not rest else 0.04))
	canvas.draw_rect(Rect2(flame_base+Vector2(-1,0),Vector2(3,1)),Color(1.0,0.50,0.18,0.96))
	canvas.draw_rect(Rect2(flame_base+Vector2(-1,-1),Vector2(2,1)),Color(1.0,0.72,0.26,0.98))
	canvas.draw_rect(Rect2(flame_base+Vector2(lean,-2),Vector2(1,mini(2,flame_height-1))),Color(1.0,0.94,0.58,1.0))
	canvas.draw_rect(Rect2(flame_base+Vector2(lean,-1),Vector2(1,1)),Color(1.0,1.0,0.88,1.0))
	if not rest and not (preferences != null and preferences.low_effects):
		for i in 2:
			var rise := fmod(float(visual_tick)/18.0+float(i)*0.5,1.0)
			var mote := tip+Vector2(lean*2+(-1 if i==0 else 1),-4.0-rise*7.0)
			canvas.draw_rect(Rect2(mote.round(),Vector2.ONE),Color(1.0,0.72,0.28,(1.0-rise)*0.65))


func enemy_texture(kind: String) -> Texture2D:
	match kind:
		"T2": return preload("res://assets/original/Characters/Fungus - violet.png")
		"T3": return preload("res://assets/original/Characters/Sewers monster.png")
		"BOSS": return boss
		"T4","T6","EL1","EL2": return preload("res://assets/original/Characters/Fungus - King.png")
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

func sleep_pose(canvas: CanvasItem, foot: Vector2, rotation: float, alpha: float) -> void:
	# Flat waking pose used only for the opening bed animation. No staff/shadow:
	# the body is drawn over the bed before the actor layer takes over.
	canvas.draw_set_transform(foot.round(),rotation,Vector2.ONE)
	var region := Rect2(16,0,16,32)
	var space := Rect2(-8,-31,16,32)
	for offset in [Vector2(-1,0),Vector2(1,0),Vector2(0,-1),Vector2(0,1)]:
		canvas.draw_texture_rect_region(cleric,space,region,Color(0.04,0.06,0.06,alpha*0.9))
	canvas.draw_texture_rect_region(cleric,space,region,Color(1,1,1,alpha))
	canvas.draw_set_transform(Vector2.ZERO)

func actor(canvas: CanvasItem, foot: Vector2, direction: Vector2, action: String, age: int, tick: int, moving: bool, player: bool = true, override_texture: Texture2D = null, alpha: float = 1.0, body_tint: Color = Color.WHITE, preferences = null) -> void:
	foot = snap_actor(foot)
	var texture: Texture2D = cleric if player else fungus
	if override_texture != null: texture = override_texture
	if texture == boss:
		battler_actor(canvas,foot,action,age,tick,alpha,body_tint,preferences)
		return
	var frame: int = [1,0,1,2][int(tick/8)%4] if moving else 1
	var angle := -PI/2 + (0.28 if row(direction) in [0,3] else (-0.8 if row(direction) == 1 else 0.8))
	var extension := 0.0
	var tint := body_tint
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
		if player: staff(canvas,foot+Vector2(4,5),0.15,0,0,preferences)
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
	var hand_origin := snap_actor(body_origin+Vector2(-8,-31)+hand.position)
	var grip := hand_origin+Vector2(0.25,0.25)
	var behind := row(direction) == 3
	if player and behind: staff(canvas,grip,angle,extension,tick,preferences)
	# Render the original full frame intact: no invented arms or split torso.
	var source := Vector2(frame*16,row(direction)*32)
	canvas.draw_texture_rect_region(texture,Rect2(body_origin+Vector2(-8,-31),Vector2(16,32)),Rect2(source,Vector2(16,32)),tint)
	if player and not behind:
		staff(canvas,grip,angle,extension,tick,preferences)
		# Re-layer only the original hand pixels over the shaft, in their original location.
		canvas.draw_texture_rect_region(texture,Rect2(hand_origin,hand.size),Rect2(source+hand.position,hand.size),tint)

func battler_actor(canvas: CanvasItem, foot: Vector2, action: String, age: int, tick: int, alpha: float = 1.0, body_tint: Color = Color.WHITE, preferences = null) -> void:
	# Boss battler: one 155x135 frame, no sheet slicing. The original battler
	# reads as the mother body; its only frame is animated with a small breath
	# and an attack shudder so warning readability lives in enemy_warnings.
	var rest: bool = preferences != null and preferences.reduced_motion
	var bob := Vector2.ZERO
	if not rest:
		bob.y = roundf(sin(float(tick)/22.0))
	var shake := Vector2.ZERO
	if action == "melee" and not rest:
		shake.x = roundf(sin(float(age)*1.7))
	var size := BOSS_TEXTURE_SIZE*BOSS_DRAW_SCALE
	var origin := foot+Vector2(-size.x*0.5,-size.y)+bob+shake
	var tint := body_tint
	if action == "melee" and age < 6: tint = Color(1.0,0.86,0.80)
	tint.a = alpha
	# Soft contact shadow, flattened to the ground plane.
	canvas.draw_set_transform(foot,0,Vector2(1,0.34))
	canvas.draw_circle(Vector2.ZERO,31,Color(0.02,0.04,0.04,0.38*alpha))
	canvas.draw_set_transform(Vector2.ZERO)
	canvas.draw_texture_rect(boss,Rect2(origin,size),false,tint)
	# A dim amber core glow at the reachable ground edge hints at the weak point.
	canvas.draw_circle(foot+Vector2(0,-8),9.0,Color(0.95,0.72,0.28,0.10*alpha))

func wounded_npc(canvas: CanvasItem, foot: Vector2, tick: int) -> void:
	# Based on the accepted Cleric sheet: muted umber cloak, no staff, bandage.
	actor(canvas,foot,Vector2.DOWN,"idle",0,tick,false,false,cleric,1.0,Color(0.82,0.86,0.68))
	canvas.draw_rect(Rect2(foot+Vector2(-6,-22),Vector2(12,3)),Color("e7ddc8"))
	canvas.draw_rect(Rect2(foot+Vector2(-1,-22),Vector2(3,3)),Color("b85a4d"))
	canvas.draw_rect(Rect2(foot+Vector2(-8,-13),Vector2(3,2)),Color("e7ddc8"))
	canvas.draw_rect(Rect2(foot+Vector2(5,-13),Vector2(3,2)),Color("e7ddc8"))
	# A simple wooden crutch keeps the silhouette readable as the camp's wounded scout.
	canvas.draw_line(foot+Vector2(-12,-21),foot+Vector2(-14,0),Color("6b4c32"),2)
	canvas.draw_line(foot+Vector2(-14,0),foot+Vector2(-10,1),Color("6b4c32"),2)

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
