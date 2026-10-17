extends RefCounted
## Select a writable per-user location, without changing OS permissions.
static var cached := ""
static func directory() -> String:
	if not cached.is_empty(): return cached
	var candidates := ["user://",OS.get_environment("LOCALAPPDATA")+"/FungusLight/",OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)+"/FungusLight/",OS.get_executable_path().get_base_dir()+"/用户数据/"]
	for candidate in candidates:
		if DirAccess.make_dir_recursive_absolute(candidate) != OK: continue
		var probe := FileAccess.open(candidate+"storage-check.tmp",FileAccess.WRITE)
		if probe == null: continue
		probe.store_string("storage check")
		probe.close()
		DirAccess.remove_absolute(candidate+"storage-check.tmp")
		cached = candidate
		print("USER_STORAGE ",ProjectSettings.globalize_path(candidate))
		return cached
	cached = "user://"
	return cached
