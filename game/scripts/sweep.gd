extends RefCounted
## Earliest segment time in [0,1], or INF. No endpoint-only collision sampling.
static func circle(start: Vector2, motion: Vector2, center: Vector2, radius: float) -> float:
	var offset := start-center
	var c := offset.length_squared()-radius*radius
	if c <= 0: return 0
	var a := motion.length_squared()
	if a < 0.000001: return INF
	var b := 2*offset.dot(motion)
	var discriminant := b*b-4*a*c
	if discriminant < 0: return INF
	var t := (-b-sqrt(discriminant))/(2*a)
	return t if t >= 0 and t <= 1 else INF

static func rect(start: Vector2, motion: Vector2, box: Rect2) -> float:
	var enter := 0.0
	var leave := 1.0
	for axis in range(2):
		if absf(motion[axis]) < 0.000001:
			if start[axis] < box.position[axis] or start[axis] > box.end[axis]: return INF
		else:
			var first := (box.position[axis]-start[axis])/motion[axis]
			var last := (box.end[axis]-start[axis])/motion[axis]
			enter = maxf(enter,minf(first,last))
			leave = minf(leave,maxf(first,last))
			if enter > leave: return INF
	return enter
