extends RefCounted
## Bounded deterministic four-neighbour grid, using the world's collision query.
const CELL := 4.0
const SIZE := Vector2i(80,45)
const NEIGHBOURS := [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]

func center(cell: Vector2i) -> Vector2:
	return Vector2(cell)*CELL+Vector2.ONE*CELL/2

func anchor(pos: Vector2, clear: Callable) -> Vector2i:
	var base := Vector2i((pos/ CELL).floor())
	var best := Vector2i(-1,-1)
	var distance := INF
	for y in range(base.y-2,base.y+3):
		for x in range(base.x-2,base.x+3):
			var cell := Vector2i(x,y)
			if x < 0 or y < 0 or x >= SIZE.x or y >= SIZE.y: continue
			var d := pos.distance_squared_to(center(cell))
			if d < distance and clear.call(pos,center(cell)):
				distance = d
				best = cell
	return best

func route(start: Vector2, goal: Vector2, clear: Callable) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var a := anchor(start,clear)
	var b := anchor(goal,clear)
	if a.x < 0 or b.x < 0: return result
	var frontier: Array[Vector2i] = [a]
	var parents := {a:a}
	var index := 0
	while index < frontier.size() and not parents.has(b):
		var cell := frontier[index]
		index += 1
		for direction in NEIGHBOURS:
			var next: Vector2i = cell+direction
			if next.x < 0 or next.y < 0 or next.x >= SIZE.x or next.y >= SIZE.y or parents.has(next): continue
			if not clear.call(center(cell),center(next)): continue
			parents[next] = cell
			frontier.append(next)
	if not parents.has(b): return result
	var cursor := b
	while cursor != a:
		result.push_front(center(cursor))
		cursor = parents[cursor]
	result.push_front(center(a))
	result.append(goal)
	return result
