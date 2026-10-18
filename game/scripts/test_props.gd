extends SceneTree
## Headless self-test for game/scripts/prop_art.gd + game/assets/props/props_data.json.
##
## Run (project root = game/):
##   godot --headless --path game --script scripts/test_props.gd
## Expected last line: PROP_TEST checks=N failures=0
##
## Covers: JSON schema, every prop kind/variant/frame, palette + binary-alpha +
## 1px outline constraints, texture construction, animation phase bounds,
## reduced_motion/reduced_flash behaviour, furniture crop legality against the
## original tileset, ambient budget/low-effects/static behaviour, aliases and
## prologue.json integration.

const PropArt = preload("res://scripts/prop_art.gd")
const TILESET_PATH := "res://assets/original/Tilesets/Complete.png"
const PROLOGUE_PATH := "res://data/prologue.json"
const PROP_REQUIRED := ["lamp", "chest", "door", "pipe", "ring", "guide", "guide_target",
	"mine_door", "portal", "rail", "rubble", "barrel"]
const FURNITURE_REQUIRED := ["bed", "chest_closed", "chest_open", "crates", "papers", "shelf",
	"barrel", "mushroom_red", "glow_mushroom", "torch", "wall_panel"]
const AMBIENT_REQUIRED := ["spores", "dust", "drip", "ember", "light_pool", "sway"]
const INK := "kKjhvdD"
const EMISSIVE := "yYaAFWw"

var art
var checks := 0
var failures := 0
var source_image: Image = null

class Prefs:
	var low_effects := false
	var reduced_motion := false
	var reduced_flash := false

	func _init(low := false, motion := false, flash := false) -> void:
		low_effects = low
		reduced_motion = motion
		reduced_flash = flash


func check(ok: bool, name: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", name)


func load_source_image() -> Image:
	var file := FileAccess.open(TILESET_PATH, FileAccess.READ)
	if file == null:
		return null
	var bytes := file.get_buffer(file.get_length())
	file.close()
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	return image


func method_arg_count(name: String) -> int:
	for method in art.get_method_list():
		if str(method["name"]) == name:
			return (method["args"] as Array).size()
	return -1


func _initialize() -> void:
	art = PropArt.new()
	check(art.loaded, "props_data.json loads")
	check(art.load_error == "", "no load error: " + art.load_error)
	if not art.loaded:
		print("PROP_TEST checks=%d failures=%d" % [checks, failures])
		quit(1)
		return

	source_image = load_source_image()
	check(source_image != null, "original tileset PNG readable")
	check(art.data.get("schema_version", 0) >= 1, "schema_version present")
	check(not str(art.data.get("build", "")).is_empty(), "deterministic build id present")
	check(str(art.data.get("source", {}).get("tileset", "")) == TILESET_PATH, "source tileset path recorded")
	check(art.palette.size() >= 24, "palette loaded (%d colours)" % art.palette.size())
	check(FileAccess.file_exists(TILESET_PATH), "tileset file exists")

	_test_api()
	_test_required_kinds()
	_test_props()
	_test_variant_mapping()
	_test_furniture()
	_test_ambient()
	_test_aliases_and_prologue()

	# Draw-path smoke: instantiate a Node2D and let the real _draw callback call
	# every public drawing entry point. Headless still issues canvas draw commands,
	# so this catches typing/draw-rect errors that pure data tests cannot.
	await _test_draw_path()

	print("PROP_TEST checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)


class DrawProbe extends Node2D:
	var art = null
	var drew := false

	func _draw() -> void:
		drew = true
		art.draw_prop(self, "lamp", Vector2(30, 60), {"lit": true}, 31, null)
		art.draw_prop(self, "lamp", Vector2(50, 60), {"lit": false}, 31, null)
		art.draw_prop(self, "chest", Vector2(70, 60), {"open": true, "near": true}, 31, null)
		art.draw_prop(self, "door", Vector2(90, 60), {"available": false}, 31, null)
		art.draw_prop(self, "door", Vector2(110, 60), {"open": true}, 31, null)
		art.draw_prop(self, "pipe", Vector2(130, 60), {"scanned": true}, 31, null)
		art.draw_prop(self, "ring", Vector2(150, 60), {"complete": true}, 31, null)
		art.draw_prop(self, "guide", Vector2(170, 60), {"dir": 3, "correct": true, "near": true}, 31, null)
		art.draw_prop(self, "guide", Vector2(190, 60), {"dir": 1, "correct": false}, 31, null)
		art.draw_prop(self, "guide", Vector2(210, 140), {"dir": 2, "correct": true, "beam": false}, 31, null)
		art.draw_prop(self, "guide_target", Vector2(210, 60), {"correct": true}, 31, null)
		art.draw_prop(self, "mine_door", Vector2(230, 60), {"available": false, "scanned": true}, 31, null)
		art.draw_prop(self, "portal", Vector2(250, 60), {"open": true}, 31, null)
		art.draw_prop(self, "rail", Vector2(260, 60), {}, 31, null)
		art.draw_prop(self, "rubble", Vector2(280, 60), {}, 31, null)
		art.draw_prop(self, "barrel", Vector2(300, 60), {}, 31, null)
		for kind in art.furniture_kinds():
			art.draw_furniture(self, str(kind), Vector2(30 + 18 * art.furniture_kinds().find(kind), 140), 31, null, {"near": true})
		for kind in art.ambient_kinds():
			art.draw_ambient(self, str(kind), Vector2(160, 172), 31, null)
		# reduced-motion / low-effects paths
		var prefs = Prefs.new(true, true, true)
		art.draw_prop(self, "lamp", Vector2(30, 30), {"lit": true}, 31, prefs)
		art.draw_prop(self, "guide", Vector2(50, 30), {"dir": 2, "correct": true}, 31, prefs)
		art.draw_furniture(self, "torch", Vector2(70, 30), 31, prefs, {"lit": true})
		for kind in art.ambient_kinds():
			art.draw_ambient(self, str(kind), Vector2(120, 30), 31, prefs)


func _test_draw_path() -> void:
	var draws_before: int = art.draws
	var furniture_before: int = art.furniture_draws
	var ambient_before: int = art.ambient_draws
	var probe := DrawProbe.new()
	probe.art = art
	get_root().add_child(probe)
	await process_frame
	await process_frame
	check(probe.drew, "draw probe _draw executed")
	check(art.draws > draws_before, "draw_prop executed in a real canvas")
	check(art.furniture_draws > furniture_before, "draw_furniture executed in a real canvas")
	check(art.ambient_draws > ambient_before, "draw_ambient executed in a real canvas")
	probe.queue_free()


# ---------------------------------------------------------------------------
func _test_api() -> void:
	check(method_arg_count("draw_prop") == 6, "draw_prop(canvas,kind,pos,state,tick,prefs)")
	check(method_arg_count("draw_furniture") == 6, "draw_furniture(canvas,kind,pos,tick,prefs,state)")
	check(method_arg_count("draw_ambient") == 5, "draw_ambient(canvas,kind,pos,tick,prefs)")
	check(method_arg_count("label_anchor") == 1, "label_anchor(kind)")
	check(method_arg_count("particle_budget") == 1, "particle_budget(prefs)")
	check(art.guide_beam_origin(Vector2(10, 10)) == Vector2(10, -7), "guide beam origin (0,-17)")
	check(art.GUIDE_DIRS[0] == Vector2.UP, "guide dir 0 = up")
	check(art.GUIDE_DIRS[1] == Vector2.RIGHT, "guide dir 1 = right")
	check(art.GUIDE_DIRS[2] == Vector2.DOWN, "guide dir 2 = down")
	check(art.GUIDE_DIRS[3] == Vector2.LEFT, "guide dir 3 = left")
	check(art.sprite_size("lamp") == Vector2(16, 30), "sprite_size(lamp)")
	check(art.prop_rect("lamp", Vector2(100, 100)).position == Vector2(92, 74), "prop_rect(lamp) anchors at pos")


func _test_required_kinds() -> void:
	for kind in PROP_REQUIRED:
		check(art.data.get("kinds", {}).has(kind), "prop kind present: " + kind)
	for kind in FURNITURE_REQUIRED:
		check(art.data.get("furniture", {}).has(kind), "furniture kind present: " + kind)
	for kind in AMBIENT_REQUIRED:
		check(art.data.get("ambient", {}).get("kinds", {}).has(kind), "ambient kind present: " + kind)
	# The APIs must know every declared kind.
	for kind in art.prop_kinds():
		check(art.has_kind(str(kind)), "has_kind(prop) " + str(kind))
	for kind in art.furniture_kinds():
		check(art.has_kind(str(kind)), "has_kind(furniture) " + str(kind))
	for kind in art.ambient_kinds():
		check(art.ambient_def(str(kind)).size() > 0, "ambient_def " + str(kind))


func _test_props() -> void:
	var rendered := 0
	for kind_variant in art.prop_kinds():
		var kind := str(kind_variant)
		var def: Dictionary = art.data["kinds"][kind]
		var size: Array = def["size"]
		var w := int(size[0])
		var h := int(size[1])
		var anchor: Array = def["anchor"]
		var label: Array = def["label_anchor"]
		check(w > 0 and h > 0 and w <= 64 and h <= 64, "size sane " + kind)
		check(anchor.size() == 2 and label.size() == 2, "anchor/label present " + kind)
		check(int(label[1]) <= int(anchor[1]), "label above sprite " + kind)
		check(int(label[0]) == 0, "label centred " + kind)
		var variants: Dictionary = def["variants"]
		check(variants.size() >= 1, "variant ≥1 " + kind)
		var kind_colors := {}
		for variant_key in variants.keys():
			var variant := str(variant_key)
			var vdef: Dictionary = variants[variant]
			var frames: Array = vdef["frames"]
			check(frames.size() >= 3 and frames.size() <= 6,
				"%s/%s frames 3..6 (%d)" % [kind, variant, frames.size()])
			var hold := int(vdef["hold"])
			check(hold >= 3 and hold <= 20, "%s/%s hold sane" % [kind, variant])
			var rest := int(vdef["rest_frame"])
			check(rest >= 0 and rest < frames.size(), "%s/%s rest_frame valid" % [kind, variant])
			for flash_key in vdef.get("flash_frames", []):
				check(int(flash_key) >= 0 and int(flash_key) < frames.size(),
					"%s/%s flash_frame valid" % [kind, variant])
			var colors := {}
			for fi in frames.size():
				var rows: Array = frames[fi]
				check(rows.size() == h, "%s/%s/%d row count" % [kind, variant, fi])
				var width_ok := true
				var palette_ok := true
				for row_key in rows:
					var row := str(row_key)
					if row.length() != w:
						width_ok = false
					for i in row.length():
						var ch := row[i]
						if ch == ".":
							continue
						colors[ch] = true
						if not art.palette.has(ch):
							palette_ok = false
				check(width_ok, "%s/%s/%d row width" % [kind, variant, fi])
				check(palette_ok, "%s/%s/%d chars in palette" % [kind, variant, fi])
				check(_outline_ok(rows, w, h), "%s/%s/%d 1px dark outline" % [kind, variant, fi])
				var texture = art.texture_for(kind, variant, fi)
				check(texture != null, "%s/%s/%d texture builds" % [kind, variant, fi])
				if texture == null:
					continue
				rendered += 1
				check(texture.get_width() == w and texture.get_height() == h,
					"%s/%s/%d texture size" % [kind, variant, fi])
				var image: Image = texture.get_image()
				check(image != null and image.get_width() == w and image.get_height() == h,
					"%s/%s/%d texture image readable" % [kind, variant, fi])
				if image == null:
					continue
				var pixels_ok := true
				var alpha_binary := true
				for y in h:
					var row := str(rows[y])
					for x in w:
						var ch := row[x]
						var col := image.get_pixel(x, y)
						if ch == ".":
							if col.a != 0.0:
								alpha_binary = false
						else:
							if col.a != 1.0:
								alpha_binary = false
							var expected: Color = art.palette[ch]
							if absf(col.r - expected.r) > 0.004 or absf(col.g - expected.g) > 0.004 \
									or absf(col.b - expected.b) > 0.004:
								pixels_ok = false
				check(alpha_binary, "%s/%s/%d binary alpha" % [kind, variant, fi])
				check(pixels_ok, "%s/%s/%d exact palette pixels" % [kind, variant, fi])
			check(colors.size() <= 16, "%s/%s ≤16 colours (%d)" % [kind, variant, colors.size()])
			kind_colors.merge(colors)
			# animation phase bounds
			var phases_ok := true
			for tick in [0, 1, 7, 8, 15, 16, 63, 100, 999]:
				var idx: int = art.frame_index(vdef, int(tick), null)
				if idx < 0 or idx >= frames.size():
					phases_ok = false
			check(phases_ok, "%s/%s frame phase in range" % [kind, variant])
			var frozen := true
			var prefs_motion := Prefs.new(false, true, false)
			for tick in [0, 13, 71, 500]:
				if art.frame_index(vdef, int(tick), prefs_motion) != rest:
					frozen = false
			check(frozen, "%s/%s reduced_motion freezes at rest_frame" % [kind, variant])
			var flash_ok := true
			var flash_frames: Array = vdef.get("flash_frames", [])
			if not flash_frames.is_empty():
				var prefs_flash := Prefs.new(false, false, true)
				for tick in range(0, 300, 7):
					var idx: int = art.frame_index(vdef, tick, prefs_flash)
					for fk in flash_frames:
						if int(fk) == idx:
							flash_ok = false
			check(flash_ok, "%s/%s reduced_flash avoids flash frames" % [kind, variant])
		check(kind_colors.size() <= 16, "%s union ≤16 colours (%d)" % [kind, kind_colors.size()])
	check(rendered >= 100, "textures rendered (%d frames)" % rendered)


func _outline_ok(rows: Array, w: int, h: int) -> bool:
	var directions := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in h:
		var row := str(rows[y])
		for x in w:
			var ch := row[x]
			if ch == ".":
				continue
			var edge := false
			var isolated := true
			var neighbour_ink := false
			for d in directions:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					edge = true
					continue
				var nch := str(rows[ny])[nx]
				if nch == ".":
					edge = true
				else:
					isolated = false
					if INK.contains(nch):
						neighbour_ink = true
			if not edge or isolated:
				continue
			if EMISSIVE.contains(ch):
				continue
			if not (INK.contains(ch) or neighbour_ink):
				return false
	return true


func _test_variant_mapping() -> void:
	check(art.variant_for("lamp", {}) == "unlit", "lamp unlit default")
	check(art.variant_for("lamp", {"lit": true}) == "lit", "lamp lit")
	check(art.variant_for("chest", {}) == "closed", "chest closed")
	check(art.variant_for("chest", {"open": true}) == "open", "chest open")
	check(art.variant_for("chest", {"available": false}) == "dim", "chest dim when unavailable")
	check(art.variant_for("door", {}) == "lit", "door lit default")
	check(art.variant_for("door", {"available": false}) == "sealed", "door sealed")
	check(art.variant_for("door", {"open": true}) == "open", "door open")
	check(art.variant_for("pipe", {"scanned": true}) == "scanned", "pipe scanned")
	check(art.variant_for("ring", {"complete": true}) == "complete", "ring complete")
	check(art.variant_for("guide", {"dir": 0, "correct": true}) == "d0c", "guide d0c")
	check(art.variant_for("guide", {"dir": 1, "correct": false}) == "d1w", "guide d1w")
	check(art.variant_for("guide", {"dir": 2, "correct": true}) == "d2c", "guide d2c")
	check(art.variant_for("guide", {"dir": 3, "correct": false}) == "d3w", "guide d3w")
	check(art.variant_for("guide_target", {"correct": true}) == "on", "guide_target on")
	check(art.variant_for("guide_target", {}) == "off", "guide_target off")
	check(art.variant_for("mine_door", {}) == "lit", "mine_door lit default")
	check(art.variant_for("mine_door", {"available": false}) == "sealed", "mine_door sealed")
	check(art.variant_for("mine_door", {"available": false, "scanned": true}) == "sealed_scan",
		"mine_door sealed_scan")
	check(art.variant_for("mine_door", {"open": true}) == "open", "mine_door open")
	check(art.variant_for("rest", {}) == "", "furniture alias has no prop variant")
	check(art.variant_names("guide").size() == 8, "guide 8 directions/states")
	check(art.variant_names("mine_door").size() == 4, "mine_door 4 states")
	check(art.variant_names("portal").size() == 2, "portal 2 states")
	check(art.variant_for("portal", {"open": true}) == "open", "portal open")
	check(art.variant_for("portal", {"available": false}) == "sealed", "portal sealed")


func _test_furniture() -> void:
	var tileset_size := Vector2i(128, 736)
	for kind_variant in art.furniture_kinds():
		var kind := str(kind_variant)
		var def: Dictionary = art.furniture_def(kind)
		var label: Array = art.data["furniture"][kind]["label_anchor"]
		check(int(label[1]) < 0 and int(label[0]) == 0, "furniture label anchor " + kind)
		if def.has("prop"):
			var prop_name := str(def["prop"])
			check(art.data.get("kinds", {}).has(prop_name), "furniture prop fallback exists " + kind)
			check(art.label_anchor(kind) == art.label_anchor(prop_name), "furniture label delegates " + kind)
			continue
		var layers: Array = def.get("layers", [])
		check(layers.size() >= 1, "furniture layers " + kind)
		if source_image == null:
			continue
		check(source_image.get_width() == tileset_size.x and source_image.get_height() == tileset_size.y,
			"tileset size " + kind)
		var near: Array = def["near_rect"]
		var nx := int(near[0])
		var ny := int(near[1])
		var nw := int(near[2])
		var nh := int(near[3])
		check(nw > 0 and nh > 0 and nw <= 96 and nh <= 96, "furniture near rect sane " + kind)
		check(int(label[1]) <= ny, "furniture label above near rect " + kind)
		for layer_key in layers:
			var layer: Dictionary = layer_key
			var rect: Array = layer["rect"]
			var off: Array = layer["offset"]
			var x := int(rect[0])
			var y := int(rect[1])
			var lw := int(rect[2])
			var lh := int(rect[3])
			var ox := int(off[0])
			var oy := int(off[1])
			check(lw > 0 and lh > 0, "furniture crop size " + kind)
			check(x >= 0 and y >= 0 and x + lw <= tileset_size.x and y + lh <= tileset_size.y,
				"furniture crop inside tileset " + kind)
			check(ox >= nx and oy >= ny and ox + lw <= nx + nw and oy + lh <= ny + nh,
				"furniture crop inside near rect " + kind)
			var opaque := 0
			for py in lh:
				for px in lw:
					if source_image.get_pixel(x + px, y + py).a > 0.01:
						opaque += 1
			check(opaque > 20, "furniture crop not empty " + kind)
			if kind.begins_with("wall_panel"):
				check(opaque >= int(float(lw * lh) * 0.7), "wall panel crop is mostly wall tile " + kind)
			else:
				check(opaque < lw * lh, "furniture crop has transparent margin " + kind)
		var fx: Dictionary = def.get("fx", {})
		var fx_points := []
		for item_key in fx.keys():
			for item in fx[item_key]:
				if item.has("origin"):
					fx_points.append(item["origin"])
				if item.has("center"):
					fx_points.append(item["center"])
				if item.has("points"):
					for p in item["points"]:
						fx_points.append(p)
				if item.has("width") and item.has("origin"):
					var origin: Array = item["origin"]
					check(int(origin[0]) + int(item["width"]) <= nx + nw,
						"furniture seam inside near rect " + kind)
		for p in fx_points:
			check(int(p[0]) >= nx - 12 and int(p[0]) <= nx + nw + 12,
				"furniture fx x near sprite " + kind)
			check(int(p[1]) >= ny - 12 and int(p[1]) <= ny + nh + 12,
				"furniture fx y near sprite " + kind)
	# The interactive bed/chest path must not duplicate art: draw_prop delegates to furniture crops.
	check(art.data["furniture"].has("bed") and not art.data["kinds"].has("bed"),
		"bed only exists as furniture (no duplicate hand-drawn bed)")
	check(art.data["furniture"].get("barrel", {}).get("prop", "") == "barrel",
		"barrel furniture delegates to the hand-drawn barrel prop")
	check(art.furniture_rect("bed", Vector2(100, 100)).position == Vector2(84, 55),
		"furniture_rect(bed) anchors at pos")


func _test_ambient() -> void:
	var base_budget := int(art.data.get("ambient", {}).get("budget", 24))
	check(base_budget == 24, "ambient budget declared (24)")
	var normal := Prefs.new()
	var low := Prefs.new(true)
	var motion := Prefs.new(false, true)
	var flash := Prefs.new(false, false, true)
	var low_motion := Prefs.new(true, true)
	check(art.particle_budget(normal) == base_budget, "particle_budget default 24")
	check(art.particle_budget(low) == int(ceili(base_budget / 2.0)), "particle_budget low halves")
	check(art.particle_budget(motion) == base_budget, "particle_budget reduced_motion keeps count")
	check(art.particle_budget(flash) == base_budget, "particle_budget reduced_flash keeps count")
	check(art.particle_budget(low_motion) == int(ceili(base_budget / 2.0)), "particle_budget low+motion")
	check(art.particle_budget({"low_effects": true}) == int(ceili(base_budget / 2.0)),
		"particle_budget accepts Dictionary prefs")
	var position := Vector2(100, 100)
	for kind_key in art.ambient_kinds():
		var kind := str(kind_key)
		var adef: Dictionary = art.ambient_def(kind)
		check(int(adef.get("base_count", 0)) > 0, "ambient base_count " + kind)
		check(int(adef.get("pixel", 0)) == 1, "ambient 1px " + kind)
		check(float(adef.get("alpha", 0.0)) > 0.0 and float(adef.get("alpha", 0.0)) <= 1.0,
			"ambient alpha " + kind)
		var colors: Array = adef.get("colors", [])
		check(colors.size() >= 1, "ambient colours " + kind)
		for ch in colors:
			check(art.palette.has(str(ch)), "ambient palette char %s/%s" % [kind, str(ch)])
		var count_normal: int = art.ambient_count(kind, normal)
		var count_low: int = art.ambient_count(kind, low)
		check(count_normal <= art.particle_budget(normal), "ambient count <= budget " + kind)
		check(count_low <= art.particle_budget(low), "ambient low count <= budget " + kind)
		var expected_low := int(ceili(int(adef.get("base_count", 0)) / 2.0))
		check(count_low == mini(expected_low, art.particle_budget(low)), "ambient low halves " + kind)
		if kind == "light_pool" or kind == "sway":
			check(art.ambient_count(kind, normal) == 1, "light field count 1 " + kind)
			check(art.ambient_positions(kind, position, 13, normal).is_empty(),
				"light field has no particles " + kind)
			continue
		var positions: Array = art.ambient_positions(kind, position, 13, normal)
		check(positions.size() <= count_normal, "ambient particle count bounded " + kind)
		if kind != "drip":
			check(positions.size() == count_normal, "ambient particle count exact " + kind)
		for p in positions:
			check(p is Vector2, "ambient position is Vector2 " + kind)
			check(float(p.x) == float(int(p.x)) and float(p.y) == float(int(p.y)),
				"ambient particle integer pixel " + kind)
			check(_ambient_in_bounds(kind, p, position), "ambient particle in bounds " + kind)
		var again: Array = art.ambient_positions(kind, position, 13, normal)
		check(again == positions, "ambient deterministic " + kind)
		var frozen_a: Array = art.ambient_positions(kind, position, 0, motion)
		var frozen_b: Array = art.ambient_positions(kind, position, 200, motion)
		check(frozen_a == frozen_b, "ambient reduced_motion static " + kind)
		var moving_a: Array = art.ambient_positions(kind, position, 0, normal)
		var moving_b: Array = art.ambient_positions(kind, position, 13, normal)
		check(moving_a != moving_b, "ambient normal has motion " + kind)


func _ambient_in_bounds(kind: String, p: Vector2, pos: Vector2) -> bool:
	var x := int(p.x)
	var y := int(p.y)
	var cx := int(pos.x)
	var cy := int(pos.y)
	match kind:
		"spores":
			return x >= cx - 17 and x <= cx + 16 and y >= cy - 27 and y <= cy - 2
		"dust":
			return x >= cx - 20 and x <= cx + 19 and y >= cy - 8 and y <= cy - 1
		"drip":
			return x >= cx - 5 and x <= cx + 7 and y >= cy - 12 and y <= cy - 1
		"ember":
			return x >= cx - 3 and x <= cx + 3 and y >= cy - 37 and y <= cy - 18
	return false


func _test_aliases_and_prologue() -> void:
	for alias_key in art.aliases().keys():
		var alias := str(alias_key)
		var target := str(art.aliases()[alias])
		check(art.has_kind(alias), "alias resolves: " + alias)
		check(art.has_kind(target), "alias target exists: " + target)
	check(art.resolve_kind("rest") == "bed", "rest -> bed")
	check(art.resolve_kind("socket") == "lamp", "socket -> lamp")
	check(art.resolve_kind("reward") == "ring", "reward -> ring")
	check(art.resolve_kind("exit") == "portal", "exit -> portal")
	check(art.resolve_kind("end") == "portal", "end -> portal")
	check(art.resolve_kind("crate") == "crates", "crate -> crates")
	check(art.resolve_kind("mushroom") == "mushroom_red", "mushroom -> mushroom_red")
	check(art.resolve_kind("unknown_kind") == "unknown_kind", "unknown kind passes through")
	var prologue_text := FileAccess.get_file_as_string(PROLOGUE_PATH)
	check(not prologue_text.is_empty(), "prologue.json readable")
	var parsed = JSON.parse_string(prologue_text)
	check(typeof(parsed) == TYPE_DICTIONARY, "prologue.json parses")
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var supported := 0
	for node in parsed.get("nodes", []):
		for object in node.get("objects", []):
			var kind := str(object.get("kind", ""))
			if kind == "rong":
				continue  # NPC actor, still rendered by world_art.actor
			check(art.has_kind(kind), "prologue object kind supported: " + kind)
			var anchor: Vector2 = art.label_anchor(kind)
			check(anchor.y < 0.0, "prologue label anchor above pos: " + kind)
			supported += 1
	check(supported >= 8, "prologue interactive kinds covered (%d)" % supported)
