extends Node
func _ready() -> void:
	if "--enemy-arena" in OS.get_cmdline_user_args():
		add_child(preload("res://scripts/enemy_arena.gd").new())
		return
	if "--campaign" in OS.get_cmdline_user_args():
		add_child(preload("res://scripts/campaign.gd").new())
		return
	var legacy := false
	for argument in OS.get_cmdline_user_args():
		if argument in ["--legacy","--integration","--replay","--poses","--grip-review","--hazard-demo","--spell-demo","--impact-demo","--armor-demo","--feedback-demo","--settings-demo"]: legacy = true
	if legacy: add_child(preload("res://scripts/graybox.gd").new())
	else: add_child(preload("res://scripts/review.gd").new())
