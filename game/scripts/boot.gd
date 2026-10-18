extends Node
func _ready() -> void:
	# Pixel font is a project-wide baseline: 12px glyph grid, used at 12/24/36 only.
	ThemeDB.fallback_font = load("res://assets/fonts/FusionPixel12px-zh_hans.ttf")
	ThemeDB.fallback_font_size = 24
	# Release exports always open the story and ignore every test/demo switch.
	# A debug export keeps the G2 review bench and the automated entry points.
	if not OS.is_debug_build():
		add_child(preload("res://scripts/campaign.gd").new())
		print("RELEASE_BOOT campaign")
		return
	if "--enemy-arena" in OS.get_cmdline_user_args():
		add_child(load("res://scripts/enemy_arena.gd").new())
		return
	if "--campaign" in OS.get_cmdline_user_args():
		add_child(preload("res://scripts/campaign.gd").new())
		return
	var legacy := false
	for argument in OS.get_cmdline_user_args():
		if argument in ["--legacy","--integration","--replay","--poses","--grip-review","--hazard-demo","--spell-demo","--impact-demo","--armor-demo","--feedback-demo","--settings-demo"]: legacy = true
	if legacy: add_child(load("res://scripts/graybox.gd").new())
	else: add_child(load("res://scripts/review.gd").new())
