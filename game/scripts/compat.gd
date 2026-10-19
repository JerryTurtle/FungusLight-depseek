extends RefCounted
## Runtime compatibility helpers: identify the machine, keep a startup report
## next to the saves, detect low-end hardware and fit the window to the screen.
##
## The release ships both x86_64 and x86_32 executables. This module only
## reports which one is running and how it was started; it never changes the
## approved gameplay/visual timings.

const BUILD_FALLBACK := "G6-013"

static func build_id() -> String:
	return str(ProjectSettings.get_setting("application/config/version", BUILD_FALLBACK))

static func is_64bit() -> bool:
	return OS.has_feature("64")

static func arch_name() -> String:
	if OS.has_feature("x86_64"): return "x86_64"
	if OS.has_feature("x86_32"): return "x86_32"
	if OS.has_feature("arm64"): return "arm64"
	if OS.has_feature("arm32"): return "arm32"
	return "unknown"

## Old dual-core machines and pre-2012 integrated graphics are common among
## players who reported launch problems. Keep the first run light on them;
## the settings panel can still turn every option back on and persists it.
static func low_end_for(cpus: int, adapter_text: String) -> bool:
	if cpus <= 2:
		return true
	var adapter := adapter_text.to_lower()
	for needle in [
		"gma", "hd graphics 2000", "hd graphics 2500", "hd graphics 3000",
		"hd graphics 4000", "radeon hd 4", "radeon hd 5", "geforce 8",
		"geforce 9", "geforce 200", "microsoft basic render", "llvmpipe",
		"swiftshader", "software",
	]:
		if needle in adapter:
			return true
	return false

static func is_low_end() -> bool:
	return low_end_for(
		OS.get_processor_count(),
		RenderingServer.get_video_adapter_name() + " " + RenderingServer.get_video_adapter_vendor()
	)

## Apply low-end defaults only when the player has no saved display config yet.
static func apply_low_end_defaults(settings) -> bool:
	if not is_low_end():
		return false
	settings.low_effects = true
	settings.reduced_motion = true
	return true

## Keep the 1280x720 viewport when the screen can show it; otherwise scale the
## window down so the title/menu is never half off-screen (1024x768 laptops).
static func fit_window_size(desired: Vector2i, usable: Vector2i) -> Vector2i:
	if usable.x <= 0 or usable.y <= 0:
		return desired
	var scale := minf(1.0, minf(float(usable.x) / float(desired.x), float(usable.y) / float(desired.y)))
	if scale >= 1.0:
		return desired
	return Vector2i(
		maxi(320, int(floor(float(desired.x) * scale))),
		maxi(180, int(floor(float(desired.y) * scale)))
	)

static func display_report() -> Dictionary:
	var output := {
		"server": DisplayServer.get_name(),
		"screen_count": 0,
		"screen_size": Vector2i.ZERO,
		"usable_rect": Rect2i(),
		"window_size": Vector2i.ZERO,
		"window_position": Vector2i.ZERO,
		"fullscreen": false,
	}
	if DisplayServer.get_name() == "headless":
		return output
	output["screen_count"] = DisplayServer.get_screen_count()
	if DisplayServer.get_screen_count() > 0:
		output["screen_size"] = DisplayServer.screen_get_size()
		output["usable_rect"] = DisplayServer.screen_get_usable_rect()
		output["window_size"] = DisplayServer.window_get_size()
		output["window_position"] = DisplayServer.window_get_position()
		output["fullscreen"] = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	return output

static func report() -> Dictionary:
	var version := Engine.get_version_info()
	var info := {
		"build": build_id(),
		"engine": str(version.get("string", "")),
		"engine_status": str(version.get("status", "")),
		"os": OS.get_name(),
		"os_distribution": OS.get_distribution_name(),
		"os_version": OS.get_version(),
		"arch": arch_name(),
		"bits": 64 if is_64bit() else 32,
		"processor_count": OS.get_processor_count(),
		"static_memory_bytes": OS.get_static_memory_usage(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"video_vendor": RenderingServer.get_video_adapter_vendor(),
		"video_api": RenderingServer.get_video_adapter_api_version(),
		"rendering_method": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		"rendering_driver": str(ProjectSettings.get_setting("rendering/gl_compatibility/driver", "")),
		"rendering_driver_windows": str(ProjectSettings.get_setting("rendering/gl_compatibility/driver.windows", "")),
		"fallback_to_angle": bool(ProjectSettings.get_setting("rendering/gl_compatibility/fallback_to_angle", true)),
		"file_logging": bool(ProjectSettings.get_setting("debug/file_logging/enable_file_logging", false)),
		"user_data_dir": OS.get_user_data_dir(),
		"executable": OS.get_executable_path(),
		"cmdline": OS.get_cmdline_args() + OS.get_cmdline_user_args(),
		"display": display_report(),
		"low_end": is_low_end(),
		"timestamp": Time.get_datetime_string_from_system(false, true),
	}
	info["storage_dir"] = ProjectSettings.globalize_path(preload("res://scripts/user_storage.gd").directory())
	return info

static func format_report(info: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("《菌灯之下》" + str(info.get("build", "")) + " 启动信息")
	lines.append("生成时间: " + str(info.get("timestamp", "")))
	lines.append("")
	lines.append("引擎: " + str(info.get("engine", "")) + " (" + str(info.get("engine_status", "")) + ")")
	lines.append("系统: " + str(info.get("os", "")) + " " + str(info.get("os_distribution", "")) + " " + str(info.get("os_version", "")))
	lines.append("架构: " + str(info.get("arch", "")) + " / " + str(info.get("bits", 0)) + " 位")
	lines.append("处理器线程: " + str(info.get("processor_count", 0)))
	lines.append("显卡: " + str(info.get("video_vendor", "")) + " " + str(info.get("video_adapter", "")))
	lines.append("图形接口: " + str(info.get("video_api", "")))
	lines.append("渲染方式: " + str(info.get("rendering_method", "")))
	lines.append("渲染驱动: " + str(info.get("rendering_driver_windows", "")) + " (通用: " + str(info.get("rendering_driver", "")) + ")")
	lines.append("ANGLE 自动回退: " + ("开" if bool(info.get("fallback_to_angle", false)) else "关"))
	lines.append("低配自动模式: " + ("是" if bool(info.get("low_end", false)) else "否"))
	lines.append("引擎文件日志: " + ("开" if bool(info.get("file_logging", false)) else "关"))
	lines.append("可执行文件: " + str(info.get("executable", "")))
	lines.append("用户数据: " + str(info.get("user_data_dir", "")))
	lines.append("存档目录: " + str(info.get("storage_dir", "")))
	var display: Dictionary = info.get("display", {})
	lines.append("显示服务: " + str(display.get("server", "")))
	lines.append("屏幕: " + str(display.get("screen_size", Vector2i.ZERO)) + " 可用区: " + str(display.get("usable_rect", Rect2i())))
	lines.append("窗口: " + str(display.get("window_size", Vector2i.ZERO)) + " 位置: " + str(display.get("window_position", Vector2i.ZERO)))
	lines.append("启动参数: " + str(info.get("cmdline", [])))
	lines.append("")
	lines.append("如果游戏无法启动，请把本文件和同目录的 启动日志.txt 一起反馈。")
	return "\n".join(lines) + "\n"

## Write both a readable report and the JSON snapshot. `directory` defaults to
## the chosen user-data directory; tests pass a temporary directory.
static func write_startup_report(directory: String = "") -> String:
	var info := report()
	var base := directory
	if base.is_empty():
		base = preload("res://scripts/user_storage.gd").directory()
	if not base.ends_with("/"):
		base += "/"
	var text := format_report(info)
	var path := ""
	var handle := FileAccess.open(base + "启动信息.txt", FileAccess.WRITE)
	if handle != null:
		handle.store_string(text)
		handle.close()
		path = base + "启动信息.txt"
	# ASCII alias: the batch diagnostics and players on non-936 code pages can
	# always find this file even if a Chinese filename is awkward to type.
	var ascii_handle := FileAccess.open(base + "startup-info.txt", FileAccess.WRITE)
	if ascii_handle != null:
		ascii_handle.store_string(text)
		ascii_handle.close()
		if path.is_empty():
			path = base + "startup-info.txt"
	if path.is_empty():
		return ""
	var json_handle := FileAccess.open(base + "compat_report.json", FileAccess.WRITE)
	if json_handle != null:
		json_handle.store_string(JSON.stringify(info, "  "))
		json_handle.close()
	print("COMPAT_REPORT ", ProjectSettings.globalize_path(path))
	print("COMPAT_ARCH ", info["arch"], " bits=", info["bits"])
	print("COMPAT_GPU ", info["video_adapter"], " | ", info["video_api"])
	print("COMPAT_DRIVER ", info["rendering_driver_windows"], " method=", info["rendering_method"], " low_end=", info["low_end"])
	return ProjectSettings.globalize_path(path)
