extends RefCounted
## Campaign saves are separate from presentation settings and H2 review records.
const SCHEMA := 1
const SLOTS := ["manual_1", "manual_2", "manual_3", "auto"]
const ENDING_BACKUP := "ending_pre.json"
const MAP_FIELDS := ["quests", "story", "puzzles", "encounters", "rewards", "skills", "upgrades", "equipment"]
const SAFETY_FIELDS := ["no_alert_enemies", "no_hazards", "player_idle", "no_blocking_event", "walkable_position", "no_elite_battle"]
var directory: String

func _init(storage_directory: String = "") -> void:
	directory = storage_directory if not storage_directory.is_empty() else preload("res://scripts/user_storage.gd").directory()+"saves"

static func validate_snapshot(value: Variant) -> String:
	if not value is Dictionary: return "存档结构损坏"
	if value.get("schema_version") != SCHEMA: return "存档版本不兼容"
	for key in ["build_id", "chapter_id", "node_id"]:
		if not value.get(key) is String or value[key].is_empty(): return "存档缺少位置或构建标识"
	for key in MAP_FIELDS:
		if not value.get(key) is Dictionary: return "存档缺少必要的进度数据。"
	var position = value.get("safe_position")
	if not position is Array or position.size() != 2: return "安全位置无效"
	for number in position:
		if not _number(number) or not is_finite(float(number)): return "安全位置无效"
	for key in ["health", "focus", "potions", "effective_seconds"]:
		if not _number(value.get(key)) or not is_finite(float(value[key])) or value[key] < 0: return "存档里的生命、精力或药剂数据无效。"
	if value.health <= 0 or value.potions > 3 or value.potions != floor(value.potions): return "生命或药剂无效"
	return ""

static func _number(value: Variant) -> bool:
	return value is int or value is float

static func is_safe(context: Dictionary) -> bool:
	for key in SAFETY_FIELDS:
		if not context.get(key) is bool or context[key] != true: return false
	return true

func save_slot(slot: String, snapshot: Dictionary, safety: Dictionary, overwrite_confirmed: bool = false) -> Dictionary:
	if slot not in SLOTS: return _failure("invalid_slot", "存档位置无效")
	if not is_safe(safety): return _failure("unsafe", "请在安全点、战斗和演出结束后保存")
	var reason := validate_snapshot(snapshot)
	if not reason.is_empty(): return _failure("invalid_snapshot", reason)
	var path := directory+"/"+slot+".json"
	if slot != "auto" and (FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak")) and not overwrite_confirmed:
		return _failure("confirmation_required", "覆盖已有存档需要确认")
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return _failure("io", "无法创建存档目录，原存档保留")
	# Whitelist persisted fields; debug/review controls never enter campaign saves.
	var clean := {}
	for key in ["schema_version", "build_id", "chapter_id", "node_id", "safe_position", "health", "focus", "potions", "effective_seconds"]+MAP_FIELDS:
		clean[key] = snapshot[key]
	var written := _write_checked(path+".tmp", clean)
	if not written: return _failure("io", "写入存档失败，原存档保留")
	# Never replace a valid backup with a corrupt/incompatible primary.
	var previous := _read(path)
	if previous.ok:
		if not _write_checked(path+".bak.tmp", previous.snapshot): return _failure("io", "备份写入失败，原存档保留")
		if DirAccess.rename_absolute(path+".bak.tmp", path+".bak") != OK: return _failure("io", "备份替换失败，原存档保留")
	if DirAccess.rename_absolute(path+".tmp", path) != OK: return _failure("io", "存档替换失败，原存档保留")
	return {"ok":true, "message":"保存成功", "slot":slot}

func save_ending_backup(snapshot: Dictionary) -> Dictionary:
	if not validate_snapshot(snapshot).is_empty(): return _failure("invalid_snapshot", validate_snapshot(snapshot))
	var path := directory+"/"+ENDING_BACKUP
	var clean := {}
	for key in ["schema_version", "build_id", "chapter_id", "node_id", "safe_position", "health", "focus", "potions", "effective_seconds"]+MAP_FIELDS:
		clean[key] = snapshot[key]
	if not _write_checked(path, clean): return _failure("io", "结局前存档写入失败")
	return {"ok":true, "message":"结局前存档已保留", "path":path}

func load_ending_backup() -> Dictionary:
	return _read(directory+"/"+ENDING_BACKUP)

func load_slot(slot: String, use_backup: bool = false) -> Dictionary:
	if slot not in SLOTS: return _failure("invalid_slot", "存档位置无效")
	var path := directory+"/"+slot+".json"
	var result := _read(path+".bak" if use_backup else path)
	if result.ok:
		result["source"] = "backup" if use_backup else "primary"
		return result
	# Caller must display the recovery choice, never silently roll back progress.
	result["backup_available"] = _read(path+".bak").ok if not use_backup else false
	return result

func _write_checked(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(value))
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK and _read(path).ok

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return _failure("missing", "未找到存档")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return _failure("io", "无法读取存档")
	var raw := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(raw) != OK: return _failure("invalid_data", "存档结构损坏")
	var value = parser.data
	var reason := validate_snapshot(value)
	if not reason.is_empty(): return _failure("invalid_data", reason)
	return {"ok":true, "snapshot":value}

static func _failure(code: String, message: String) -> Dictionary:
	return {"ok":false, "code":code, "message":message}
