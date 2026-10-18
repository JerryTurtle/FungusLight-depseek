class_name CampaignHUD
extends Control
## Pixel HUD for the campaign: lamp-keeper portrait, health / focus / potions
## on the upper-left, skill slots and cooldowns on the lower-right.
##
## The HUD is presentation-only. It reads the campaign's combat/progress state
## and never mutates it, so every number shown here is the same state the
## simulation uses. Drawing is on a 2-4 px grid to match the 320x180 world.

const FONT := preload("res://assets/fonts/FusionPixel12px-zh_hans.ttf")
const CLERIC := preload("res://assets/original/Characters/Cleric.png")
const ICON_MELEE := preload("res://assets/hud/icon_melee.png")
const ICON_LIGHT := preload("res://assets/hud/icon_light.png")
const ICON_SHIELD := preload("res://assets/hud/icon_shield.png")
const ICON_RAIN := preload("res://assets/hud/icon_rain.png")
const ICON_DODGE := preload("res://assets/hud/icon_dodge.png")
const ICON_POTION := preload("res://assets/hud/icon_potion.png")
const ICON_POTION_EMPTY := preload("res://assets/hud/icon_potion_empty.png")

const C_SHADOW := Color(0.015, 0.024, 0.024, 0.82)
const C_PANEL := Color(0.035, 0.064, 0.062, 0.94)
const C_PANEL_INNER := Color(0.055, 0.091, 0.083, 0.94)
const C_BRASS_DARK := Color(0.32, 0.235, 0.145, 1.0)
const C_BRASS := Color(0.60, 0.455, 0.245, 1.0)
const C_BRASS_HI := Color(0.86, 0.70, 0.41, 1.0)
const C_TEXT := Color(0.93, 0.88, 0.74, 1.0)
const C_MUTED := Color(0.62, 0.64, 0.56, 1.0)
const C_HP := Color(0.72, 0.24, 0.22, 1.0)
const C_HP_HI := Color(1.0, 0.51, 0.40, 1.0)
const C_FOCUS := Color(0.25, 0.66, 0.61, 1.0)
const C_FOCUS_HI := Color(0.66, 0.96, 0.84, 1.0)
const C_SHIELD := Color(0.56, 0.90, 0.88, 1.0)
const C_LOCK := Color(0.78, 0.66, 0.47, 0.95)

var game = null
var _pulse := 0.0

func _ready() -> void:
	size = Vector2(1280, 720)
	position = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func bind(value) -> void:
	game = value
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta, 10.0)
	if visible:
		queue_redraw()

func _draw() -> void:
	if game == null or not game.running:
		return
	_draw_status_panel()
	_draw_skill_tray()

func _draw_status_panel() -> void:
	var panel := Rect2(16, 12, 404, 160)
	_draw_frame(panel)
	# Portrait: the accepted down-facing Cleric frame, nearest-scaled 3x.
	var portrait := Rect2(30, 28, 48, 96)
	draw_rect(Rect2(portrait.position - Vector2(3, 3), portrait.size + Vector2(6, 6)), C_BRASS_DARK)
	draw_rect(Rect2(portrait.position - Vector2(1, 1), portrait.size + Vector2(2, 2)), C_SHADOW)
	draw_texture_rect_region(CLERIC, portrait, Rect2(16, 0, 16, 32))
	_draw_corner_rivets(panel)

	var hp_ratio := _ratio(game.combat.hp, maxf(1.0, game.progress.max_hp()))
	var focus_ratio := _ratio(game.combat.focus, maxf(1.0, game.progress.max_focus()))
	_text(Vector2(94, 38), "岚 · 最后守灯人", 24, C_TEXT)
	var time_text: String = game.elapsed_text() if game.has_method("elapsed_text") else "00:00"
	_text_right(Vector2(344, 38), time_text, 20, C_MUTED, 60)

	_text(Vector2(94, 62), "生命", 20, C_MUTED)
	_text_right(Vector2(296, 62), "%d / %d" % [ceili(game.combat.hp), ceili(game.progress.max_hp())], 20, C_TEXT, 104)
	_draw_bar(Rect2(94, 68, 306, 14), hp_ratio, C_HP, C_HP_HI, 10)
	if hp_ratio <= 0.3:
		var blink := 0.45 + 0.35 * sin(_pulse * 4.0)
		draw_rect(Rect2(94, 68, 306, 14), Color(1.0, 0.35, 0.28, blink), false, 2)

	_text(Vector2(94, 96), "精力", 20, C_MUTED)
	_text_right(Vector2(296, 96), "%d / %d" % [ceili(game.combat.focus), ceili(game.progress.max_focus())], 20, C_TEXT, 104)
	_draw_bar(Rect2(94, 102, 306, 9), focus_ratio, C_FOCUS, C_FOCUS_HI, 0)

	var shield: float = float(game.combat.shield_hp)
	if shield > 0.0:
		var shield_ratio := _ratio(shield, maxf(1.0, float(game.progress.shield_capacity())))
		draw_rect(Rect2(94, 114, 306, 3), Color(0.07, 0.14, 0.14, 0.95))
		draw_rect(Rect2(94, 114, round(306 * shield_ratio), 3), C_SHIELD)
		_text(Vector2(94, 132), "护灯 %d" % ceili(shield), 16, C_SHIELD)
	else:
		var shield_label := "护灯 未习得" if not bool(game.progress.skills().get("shield", false)) else "护灯 未展开"
		_text(Vector2(94, 132), shield_label, 16, Color(0.39, 0.48, 0.43, 1.0))

	# Three potion bottles; empty slots stay visible so the player can read 0/3.
	for i in 3:
		var bottle := Rect2(206 + i * 34, 112, 26, 36)
		var full := i < int(game.combat.potions)
		draw_texture_rect(ICON_POTION if full else ICON_POTION_EMPTY, bottle, false)
		if not full:
			draw_rect(bottle, Color(0.02, 0.03, 0.03, 0.28))
	_text(Vector2(314, 132), "%d/3" % int(game.combat.potions), 20, C_TEXT)
	if str(game.combat.action) == "heal":
		var windup: float = maxf(1.0, float(game.combat.config.actions.heal.windup))
		var heal_progress := clampf(float(game.combat.age) / windup, 0.0, 1.0)
		draw_rect(Rect2(206, 151, 94, 3), Color(0.07, 0.13, 0.10, 0.95))
		draw_rect(Rect2(206, 151, round(94.0 * heal_progress), 3), Color(0.52, 0.96, 0.62, 1.0))
		_text(Vector2(314, 154), "使用药剂中", 16, Color(0.58, 0.92, 0.59, 1.0))
	else:
		_text(Vector2(314, 154), "R 饮用药剂", 16, C_MUTED)
	if game.combat.poison_until > game.combat.tick:
		var seconds := maxi(1, ceili(float(game.combat.poison_until - game.combat.tick) / 60.0))
		_text(Vector2(94, 154), "孢毒 %ds" % seconds, 16, Color(0.58, 0.90, 0.40, 1.0))

func _draw_skill_tray() -> void:
	var panel := Rect2(884, 568, 380, 138)
	_draw_frame(panel)
	_draw_corner_rivets(panel)
	_text(Vector2(900, 588), "技能 · 冷却", 20, C_MUTED)
	_text_right(Vector2(1248, 588), "数字键 / 鼠标", 16, Color(0.45, 0.50, 0.44, 1.0), 120)
	var slots := skill_slots()
	for slot in slots:
		_draw_skill_slot(slot)

func skill_slots() -> Array:
	if game == null:
		return []
	var learned: Dictionary = game.progress.skills()
	var cooldowns: Dictionary = game.combat.cooldowns
	var focus: float = float(game.combat.focus)
	var shield_total: float = maxf(1.0, float(game.progress.shield_cooldown()))
	var entries := [
		{"id":"melee", "name":"灯击", "key":"左键", "icon":ICON_MELEE, "locked":false, "cd":0.0, "total":1.0, "cost":0.0},
		{"id":"light", "name":"净光", "key":"右键", "icon":ICON_LIGHT, "locked":not bool(learned.get("light", false)), "cd":float(cooldowns.get("light", 0)), "total":72.0, "cost":float(game.combat.config.actions.light.cost)},
		{"id":"shield", "name":"护灯", "key":"1", "icon":ICON_SHIELD, "locked":not bool(learned.get("shield", false)), "cd":float(cooldowns.get("shield", 0)), "total":shield_total, "cost":float(game.combat.config.actions.shield.cost)},
		{"id":"rain", "name":"灯雨", "key":"2", "icon":ICON_RAIN, "locked":not bool(learned.get("rain", false)), "cd":float(cooldowns.get("rain", 0)), "total":360.0, "cost":float(game.combat.config.actions.rain.cost)},
		{"id":"dodge", "name":"闪避", "key":"空格", "icon":ICON_DODGE, "locked":false, "cd":float(cooldowns.get("dodge", 0)), "total":60.0, "cost":0.0},
	]
	var out: Array = []
	for i in entries.size():
		var entry: Dictionary = entries[i]
		entry["rect"] = Rect2(900 + i * 66, 596, 58, 58)
		entry["enough"] = focus >= float(entry.cost)
		out.append(entry)
	return out

func _draw_skill_slot(slot: Dictionary) -> void:
	var rect: Rect2 = slot.rect
	var locked: bool = slot.locked
	var active := false
	if slot.id == "shield" and game.combat.shield_hp > 0:
		active = true
	var border := C_BRASS
	if active:
		border = C_SHIELD
	draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size), Color(0.01, 0.02, 0.02, 0.6))
	draw_rect(rect, border)
	draw_rect(rect.grow(-2), C_PANEL_INNER)
	draw_line(rect.position + Vector2(3, 2), rect.position + Vector2(rect.size.x - 3, 2), C_BRASS_HI, 1)
	draw_line(rect.position + Vector2(2, 3), rect.position + Vector2(2, rect.size.y - 3), C_BRASS_HI, 1)
	draw_line(rect.position + Vector2(3, rect.size.y - 2), rect.position + Vector2(rect.size.x - 3, rect.size.y - 2), C_BRASS_DARK, 1)
	# Icon, 2x from the 24px source, inset into the 58px slot.
	var icon_rect := Rect2(rect.position + Vector2(5, 5), Vector2(48, 48))
	var dim := 1.0
	if locked:
		dim = 0.30
	elif not bool(slot.enough):
		dim = 0.58
	draw_texture_rect(slot.icon, icon_rect, false, Color(dim, dim, dim, 1.0))
	var cd := float(slot.cd)
	if cd > 0.05:
		var ratio: float = clampf(cd / maxf(0.01, float(slot.total)), 0.0, 1.0)
		var fill_h: float = round(48.0 * ratio)
		draw_rect(Rect2(icon_rect.position, Vector2(48, fill_h)), Color(0.02, 0.05, 0.055, 0.78))
		if fill_h > 0:
			draw_line(icon_rect.position + Vector2(0, fill_h), icon_rect.position + Vector2(48, fill_h), C_BRASS_HI, 1)
		var seconds := ceili(cd / 60.0)
		var label := str(seconds) if seconds >= 10 else "%.1f" % (cd / 60.0)
		_text_center(icon_rect, label, 24, Color(1.0, 0.93, 0.73, 1.0))
	elif locked:
		# A small brass lock; the key/name stay visible under the slot.
		var lock_pos := icon_rect.position + Vector2(17, 19)
		draw_rect(Rect2(lock_pos, Vector2(14, 11)), C_LOCK)
		draw_rect(Rect2(lock_pos + Vector2(2, 2), Vector2(10, 7)), C_PANEL)
		draw_arc(lock_pos + Vector2(7, 0), 5, PI, TAU, 8, C_LOCK, 2)
		draw_rect(Rect2(lock_pos + Vector2(6, 4), Vector2(2, 4)), C_LOCK)
	elif slot.id == "melee":
		draw_circle(rect.position + Vector2(rect.size.x - 9, 9), 2.0, Color(0.72, 1.0, 0.86, 0.85))
	var cost := float(slot.cost)
	if cost > 0.0:
		var cost_color := C_MUTED if bool(slot.enough) else Color(1.0, 0.48, 0.38, 1.0)
		_text_right(Vector2(rect.position.x + 53, rect.position.y + 55), str(int(cost)), 16, cost_color, 24)
	_text_center(Rect2(rect.position.x, rect.position.y + 59, rect.size.x, 18), str(slot.key), 16, C_MUTED)
	_text_center(Rect2(rect.position.x, rect.position.y + 75, rect.size.x, 18), str(slot.name), 16, C_TEXT if not locked else Color(0.49, 0.48, 0.41, 1.0))

func _draw_bar(rect: Rect2, ratio: float, fill: Color, highlight: Color, segments: int) -> void:
	draw_rect(Rect2(rect.position + Vector2(1, 1), rect.size), Color(0.01, 0.02, 0.02, 0.75))
	draw_rect(rect, C_BRASS_DARK)
	draw_rect(rect.grow(-1), Color(0.04, 0.075, 0.068, 1.0))
	var inner := rect.grow(-2)
	draw_rect(inner, Color(0.10, 0.12, 0.105, 1.0))
	var width: float = roundf(inner.size.x * clampf(ratio, 0.0, 1.0))
	if width > 0:
		draw_rect(Rect2(inner.position, Vector2(width, inner.size.y)), fill)
		draw_line(inner.position, inner.position + Vector2(width, 0), highlight, 1)
		draw_line(inner.position + Vector2(0, inner.size.y - 1), inner.position + Vector2(width, inner.size.y - 1), fill.darkened(0.35), 1)
	if segments > 0:
		for i in range(1, segments):
			var x: float = roundf(inner.position.x + inner.size.x * float(i) / float(segments))
			draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y - 1), Color(0.02, 0.025, 0.02, 0.48), 1)
	draw_rect(rect, C_BRASS, false, 1)

func _draw_frame(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position + Vector2(4, 4), rect.size), C_SHADOW)
	draw_rect(rect, C_BRASS_DARK)
	draw_rect(rect.grow(-2), C_BRASS)
	draw_rect(rect.grow(-4), C_PANEL)
	draw_rect(Rect2(rect.position + Vector2(6, 6), rect.size - Vector2(12, 12)), C_PANEL_INNER, false, 1)
	draw_line(rect.position + Vector2(4, 2), rect.position + Vector2(rect.size.x - 4, 2), C_BRASS_HI, 1)
	draw_line(rect.position + Vector2(2, 4), rect.position + Vector2(2, rect.size.y - 4), C_BRASS_HI, 1)
	draw_line(rect.position + Vector2(4, rect.size.y - 2), rect.position + Vector2(rect.size.x - 4, rect.size.y - 2), Color(0.17, 0.125, 0.08, 1.0), 1)
	draw_line(rect.position + Vector2(rect.size.x - 2, 4), rect.position + Vector2(rect.size.x - 2, rect.size.y - 4), Color(0.17, 0.125, 0.08, 1.0), 1)

func _draw_corner_rivets(rect: Rect2) -> void:
	for p in [rect.position + Vector2(7, 7), rect.position + Vector2(rect.size.x - 8, 7),
			rect.position + Vector2(7, rect.size.y - 8), rect.position + Vector2(rect.size.x - 8, rect.size.y - 8)]:
		draw_rect(Rect2(p, Vector2(4, 4)), C_BRASS_HI)
		draw_rect(Rect2(p + Vector2(1, 1), Vector2(2, 2)), C_BRASS_DARK)

func _ratio(value: float, maximum: float) -> float:
	return clampf(value / maximum, 0.0, 1.0)

func _text(pos: Vector2, value: String, size: int, color: Color) -> void:
	draw_string(FONT, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _text_right(pos: Vector2, value: String, size: int, color: Color, width: float) -> void:
	draw_string(FONT, pos, value, HORIZONTAL_ALIGNMENT_RIGHT, width, size, color)

func _text_center(rect: Rect2, value: String, size: int, color: Color) -> void:
	draw_string(FONT, Vector2(rect.position.x, rect.position.y + size), value, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)
