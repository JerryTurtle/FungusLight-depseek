extends SceneTree
## G6-013 compatibility checks: build identity, screen fitting, low-end
## detection, startup report and the release logging/ANGLE settings.

const Compat = preload("res://scripts/compat.gd")
const Preferences = preload("res://scripts/presentation_settings.gd")

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	check(Compat.build_id() == "G6-013", "build id is G6-013")
	check(Compat.arch_name() in ["x86_64", "x86_32", "arm64", "arm32"], "architecture tag is known")
	check(Compat.is_64bit() == OS.has_feature("64"), "bitness matches engine feature tag")

	check(Compat.fit_window_size(Vector2i(1280, 720), Vector2i(1024, 728)) == Vector2i(1024, 576), "1024x728 screen fits")
	check(Compat.fit_window_size(Vector2i(1280, 720), Vector2i(1920, 1080)) == Vector2i(1280, 720), "large screen keeps 1280x720")
	check(Compat.fit_window_size(Vector2i(1280, 720), Vector2i(800, 600)) == Vector2i(800, 450), "800x600 screen fits")
	check(Compat.fit_window_size(Vector2i(1280, 720), Vector2i(0, 0)) == Vector2i(1280, 720), "unknown screen keeps default")

	check(Compat.low_end_for(2, "AMD Radeon 780M"), "dual-core is low-end")
	check(Compat.low_end_for(8, "Intel(R) HD Graphics 3000"), "old Intel iGPU is low-end")
	check(Compat.low_end_for(8, "Microsoft Basic Render Driver"), "basic render driver is low-end")
	check(not Compat.low_end_for(16, "AMD Radeon 780M Graphics"), "modern GPU is not low-end")

	var settings = Preferences.new()
	var before_low: bool = settings.low_effects
	var before_motion: bool = settings.reduced_motion
	var applied := Compat.apply_low_end_defaults(settings)
	if Compat.is_low_end():
		check(applied and settings.low_effects and settings.reduced_motion, "low-end defaults applied on weak host")
	else:
		check(not applied and settings.low_effects == before_low and settings.reduced_motion == before_motion, "settings untouched on fast host")

	var info := Compat.report()
	for key in ["build", "engine", "os", "arch", "bits", "processor_count", "video_adapter",
			"rendering_method", "rendering_driver_windows", "display", "low_end", "storage_dir"]:
		check(info.has(key), "report has " + key)
	check(str(info["build"]) == "G6-013", "report build id")
	check(str(info["display"]).find("server") >= 0, "display report present")

	var tmp := ProjectSettings.globalize_path("res://").path_join(
		"../qa/runtime-profile/g6-compat-" + str(Time.get_ticks_usec())).simplify_path()
	check(DirAccess.make_dir_recursive_absolute(tmp) == OK, "temp report directory created")
	var report_path := Compat.write_startup_report(tmp + "/")
	check(not report_path.is_empty() and FileAccess.file_exists(report_path), "startup report written")
	if not report_path.is_empty():
		var text := FileAccess.get_file_as_string(report_path)
		check(text.find("《菌灯之下》G6-013") >= 0, "report header")
		check(text.find("渲染驱动") >= 0 and text.find("显卡") >= 0, "report has driver/GPU sections")
		check(FileAccess.file_exists(tmp + "/compat_report.json"), "JSON report written")
		check(FileAccess.file_exists(tmp + "/startup-info.txt"), "ASCII startup-info alias written")

	# Logging through user:// at engine start would abort on a read-only profile;
	# diagnostics come from the launcher's --log-file and the startup report.
	check(not bool(ProjectSettings.get_setting("debug/file_logging/enable_file_logging", false)), "engine user:// logging stays off")
	check(bool(ProjectSettings.get_setting("rendering/gl_compatibility/fallback_to_angle", false)), "automatic ANGLE fallback enabled")

	# apply_display must be a no-op in headless instead of crashing on a missing screen.
	settings.apply_display()
	check(true, "apply_display survives headless")

	print("COMPAT_TEST checks=", checks, " failures=", failures)
	quit(1 if failures > 0 else 0)
