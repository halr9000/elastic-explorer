class_name EESaveService
extends RefCounted

var base_path: String
var last_error: String = ""
var archived_path: String = ""
var recovered_backup: bool = false

func _init(path: String = "user://expedition") -> void:
	base_path = path

func exists() -> bool:
	return FileAccess.file_exists(base_path + ".json") or FileAccess.file_exists(base_path + ".bak")

func _valid(data: Variant) -> bool:
	if not data is Dictionary: return false
	if data.get("version", 0) != 1: return false
	if not data.get("seed") is float and not data.get("seed") is int: return false
	if not is_finite(float(data.seed)) or float(data.seed) != floor(float(data.seed)): return false
	if not data.get("layout") is Dictionary or not data.get("player") is Dictionary: return false
	if not load("res://game/world/generation/route_validator.gd").new().validate(data.layout).is_empty(): return false
	if data.seed != data.layout.seed: return false
	if data.player.has("position") and not _point(data.player.position): return false
	if data.player.get("shape_mode", "walk") not in ["walk", "roll", "squeeze"]: return false
	for key in ["health", "endurance"]:
		var value = data.player.get(key)
		if not value is int and not value is float: return false
		if not is_finite(float(value)) or float(value) < 0 or float(value) > 100: return false
	if data.player.get("weapon") not in ["club", "heavy", "thorn"]: return false
	var checkpoint = data.get("checkpoint")
	if not checkpoint is Array or checkpoint.size() != 2: return false
	for value in checkpoint:
		if not value is int and not value is float: return false
		if not is_finite(float(value)): return false
	var known_checkpoint: bool = false
	for landmark: Dictionary in data.layout.landmarks:
		if landmark.kind == "checkpoint" and Vector2(float(checkpoint[0]), float(checkpoint[1])).distance_to(Vector2(float(landmark.position[0]), float(landmark.position[1]))) < 1.0:
			known_checkpoint = true
	if not known_checkpoint: return false
	for key in ["collected", "defeated", "discoveries"]:
		if not data.get(key) is Array: return false
	return true

func _point(value: Variant) -> bool:
	if not value is Array or value.size() != 2: return false
	for coordinate: Variant in value:
		if not coordinate is int and not coordinate is float: return false
		if not is_finite(float(coordinate)): return false
	return true

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return {}
	var parsed = parser.data
	return parsed if _valid(parsed) else {}

func load_game() -> Dictionary:
	last_error = ""
	recovered_backup = false
	var primary = _read(base_path + ".json")
	if not primary.is_empty(): return primary
	var backup = _read(base_path + ".bak")
	if not backup.is_empty():
		recovered_backup = true
		last_error = "Recovered backup. The unreadable original has been preserved; saving is disabled until it is moved aside."
		return backup
	if exists(): last_error = "Save is malformed or unsupported. Original files have been preserved."
	return {}

func save_game(data: Dictionary) -> Error:
	last_error = ""
	if not _valid(data):
		last_error = "Incomplete or unsupported save state."
		return ERR_INVALID_DATA
	var primary_path = base_path + ".json"
	if FileAccess.file_exists(primary_path) and _read(primary_path).is_empty():
		last_error = "Unreadable original preserved. Move it aside before saving a new expedition."
		return ERR_INVALID_DATA
	var file = FileAccess.open(base_path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Could not write temporary save."
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()
	if _read(base_path + ".tmp").is_empty():
		last_error = "Temporary save verification failed."
		return ERR_FILE_CORRUPT
	if FileAccess.file_exists(primary_path):
		var backup_path: String = base_path + ".bak"
		if FileAccess.file_exists(backup_path) and _read(backup_path).is_empty():
			archived_path = base_path + ".backup.corrupt." + str(int(Time.get_unix_time_from_system())) + "." + str(Time.get_ticks_usec()) + ".json"
			var archive_error: Error = DirAccess.rename_absolute(backup_path, archived_path)
			if archive_error != OK:
				last_error = "Could not preserve malformed backup. Save unchanged."
				return archive_error
		var backup_error = DirAccess.copy_absolute(primary_path, base_path + ".bak")
		if backup_error != OK:
			last_error = "Could not preserve previous save backup."
			return backup_error
	var replace_error = DirAccess.rename_absolute(base_path + ".tmp", primary_path)
	if replace_error != OK: last_error = "Save replacement failed; backup and temporary state preserved."
	return replace_error



func archive_invalid_primary() -> Error:
	last_error = ""
	var source: String = base_path + ".json"
	if not FileAccess.file_exists(source): return ERR_FILE_NOT_FOUND
	if not _read(source).is_empty():
		last_error = "Primary save is valid; recovery archive is unnecessary."
		return ERR_ALREADY_EXISTS
	archived_path = base_path + ".corrupt." + str(int(Time.get_unix_time_from_system())) + "." + str(Time.get_ticks_usec()) + ".json"
	var error: Error = DirAccess.rename_absolute(source, archived_path)
	if error != OK: last_error = "Could not archive invalid primary; original preserved."
	else: last_error = "Invalid original preserved at " + archived_path
	return error
