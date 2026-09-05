extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var suites: Array[String] = ["player", "world", "combat", "save", "integration"]
	var selected: PackedStringArray = OS.get_cmdline_user_args()
	var count: int = 0
	for suite: String in suites:
		if not selected.is_empty() and not suite in selected:
			continue
		var path: String = "res://tests/%s_test.gd" % suite
		if not ResourceLoader.exists(path):
			failures.append("Missing required suite: " + suite)
			continue
		var script: Script = load(path) as Script
		if script == null or not script.can_instantiate():
			failures.append("Cannot instantiate suite: " + suite)
			continue
		var instance: RefCounted = script.new() as RefCounted
		var result: Array[String] = await instance.call("run", self)
		failures.append_array(result)
		count += 1
		print("SUITE ", suite, ": ", "PASS" if result.is_empty() else "FAIL")
	for failure: String in failures:
		printerr("FAIL: ", failure)
	print("RESULT: ", count, " suites; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
