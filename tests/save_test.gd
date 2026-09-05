extends RefCounted

func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	if not ResourceLoader.exists("res://game/save/save_service.gd"):
		return ["Save service must exist and preserve validated state"]
	var service = load("res://game/save/save_service.gd").new("user://test_save_" + str(Time.get_ticks_usec()))
	var state = {"version":1,"seed":77,"layout":load("res://game/world/generation/world_generator.gd").new().generate(77),"checkpoint":[4,5],"player":{"health":80,"endurance":100,"weapon":"thorn"},"collected":["a"],"defeated":["c"],"discoveries":["grove"]}
	state.checkpoint = state.layout.landmarks[0].position.duplicate()
	if service.save_game(state) != OK: failures.append("Valid state must save")
	var loaded: Dictionary = service.load_game()
	if loaded.get("layout", {}).get("terrain", []).size() < 20 or loaded.get("player", {}).get("weapon") != "thorn": failures.append("Layout and player must round-trip")
	state.seed = 88
	state.layout = load("res://game/world/generation/world_generator.gd").new().generate(88)
	state.checkpoint = state.layout.landmarks[0].position.duplicate()
	service.save_game(state)
	var file = FileAccess.open(service.base_path + ".json", FileAccess.WRITE)
	file.store_string("{malformed")
	file.close()
	loaded = service.load_game()
	if loaded.get("seed") != 77 or not service.recovered_backup: failures.append("Malformed primary must recover valid backup explicitly")
	if service.save_game(state) == OK: failures.append("Malformed primary must block destructive overwrite")
	if FileAccess.get_file_as_string(service.base_path + ".json") != "{malformed": failures.append("Invalid original must remain unchanged")
	var invalid = state.duplicate(true)
	invalid.erase("checkpoint")
	if service.save_game(invalid) == OK: failures.append("Incomplete state must be rejected")
	var invalid_numeric = state.duplicate(true)
	invalid_numeric.checkpoint = [INF, 5]
	if service.save_game(invalid_numeric) != ERR_INVALID_DATA: failures.append("Nonfinite checkpoint must be rejected")
	if not service.has_method("archive_invalid_primary"):
		failures.append("Recovery must offer preservation archive")
	else:
		if service.archive_invalid_primary() != OK: failures.append("Invalid primary must archive explicitly")
		if not FileAccess.file_exists(service.archived_path): failures.append("Recovery archive must preserve invalid original")
		if service.save_game(state) != OK: failures.append("Saving must resume after explicit archive")
		if service.save_game(invalid_numeric) != ERR_INVALID_DATA: failures.append("Finite checkpoints required even with valid primary")
		invalid_numeric = state.duplicate(true)
		invalid_numeric.player.health = -2
		if service.save_game(invalid_numeric) != ERR_INVALID_DATA: failures.append("Negative health rejected")
		invalid_numeric = state.duplicate(true)
		invalid_numeric.player.weapon = "unknown"
		if service.save_game(invalid_numeric) != ERR_INVALID_DATA: failures.append("Unknown weapon rejected")
		DirAccess.remove_absolute(service.archived_path)
	for bad_position in ["bad", {}, [INF, 0], [0]]:
		var bad = state.duplicate(true)
		bad.player.position = bad_position
		if service.save_game(bad) != ERR_INVALID_DATA: failures.append("Malformed player position rejected")
	var mismatch = state.duplicate(true)
	mismatch.seed = 99
	if service.save_game(mismatch) != ERR_INVALID_DATA: failures.append("Seed mismatch rejected")
	mismatch = state.duplicate(true)
	mismatch.checkpoint = [4, 5]
	if service.save_game(mismatch) != ERR_INVALID_DATA: failures.append("Unknown checkpoint rejected")
	file = FileAccess.open(service.base_path + ".bak", FileAccess.WRITE)
	file.store_string("broken backup")
	file.close()
	if service.save_game(state) != OK: failures.append("Valid primary can save while archiving broken backup")
	if not FileAccess.file_exists(service.archived_path) or FileAccess.get_file_as_string(service.archived_path) != "broken backup": failures.append("Malformed backup must be preserved")
	DirAccess.remove_absolute(service.archived_path)
	for suffix in [".json", ".bak", ".tmp"]:
		DirAccess.remove_absolute(service.base_path + suffix)
	return failures
