extends RefCounted
const BUILD := "G2-007"
var directory: String = preload("res://scripts/user_storage.gd").directory()+"reviews/"+BUILD
var records: Dictionary = {}
var current := 0
var confirmed := false

func _init() -> void:
	for i in 6: records["H%02d" % (i+1)] = {"status":"未审核","tags":[],"note":"","captures":[]}

func load_review() -> Error:
	if not FileAccess.file_exists(directory+"/review.json"): return ERR_FILE_NOT_FOUND
	var value = JSON.parse_string(FileAccess.get_file_as_string(directory+"/review.json"))
	if not value is Dictionary or value.get("build","") != BUILD: return ERR_INVALID_DATA
	for key in records:
		var record = value.get("items",{}).get(key,{})
		if record is Dictionary and record.get("status","") in ["未审核","通过","需修改"]:
			records[key] = record
	current = clampi(int(value.get("current",0)),0,5)
	confirmed = bool(value.get("human_confirmed",false))
	return OK

func payload(context: Dictionary) -> Dictionary:
	return {"build":BUILD,"current":current,"items":records,"human_confirmed":confirmed,"context":context,"manifest":JSON.parse_string(FileAccess.get_file_as_string("res://data/review_manifest.json"))}

func save(context: Dictionary = {}) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK: return error
	var file := FileAccess.open(directory+"/review.json",FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload(context),"\t"))
	file.close()
	return OK

func markdown() -> String:
	var result := "# 菌灯之下 · 人工审核反馈\n\n构建："+BUILD+"\n本构建人工确认："+("是" if confirmed else "否")+"\n\n"
	for key in records:
		var record: Dictionary = records[key]
		result += "## "+key+" · "+str(record.status)+"\n\n标签："+", ".join(record.tags)+"\n说明："+str(record.note)+"\n"
		for capture in record.captures: result += "截图："+str(capture.path)+"\n"
		result += "\n"
	return result

func export_files(context: Dictionary) -> Error:
	var error := save(context)
	if error != OK: return error
	var file := FileAccess.open(directory+"/审核反馈.md",FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(markdown())
	file.close()
	return OK

func all_passed() -> bool:
	for record in records.values():
		if record.status != "通过": return false
	return true
