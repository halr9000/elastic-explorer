extends RefCounted

func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var generator = load("res://game/world/generation/world_generator.gd").new()
	var validator = load("res://game/world/generation/route_validator.gd").new()
	for seed_value in range(100):
		var first: Dictionary = generator.generate(seed_value)
		var second: Dictionary = generator.generate(seed_value)
		if JSON.stringify(first) != JSON.stringify(second):
			failures.append("World is nondeterministic for seed %d" % seed_value)
		var problems: Array[String] = validator.validate(first)
		if not problems.is_empty():
			failures.append("Invalid seed %d: %s" % [seed_value, str(problems)])
		var changed: Dictionary = generator.generate(seed_value, 999)
		if first.terrain != changed.terrain or first.route != changed.route or first.landmarks != changed.landmarks:
			failures.append("Decoration changed traversal for seed %d" % seed_value)
		var restored: Dictionary = JSON.parse_string(JSON.stringify(first))
		if not _same_geometry(restored.terrain, first.terrain):
			failures.append("JSON reload rearranged seed %d" % seed_value)
	var invalid: Dictionary = generator.generate(1)
	invalid.route[0].cost = 1000.0
	if validator.validate(invalid).is_empty():
		failures.append("Validator accepted impossible endurance cost")
	var broken: Dictionary = generator.generate(1)
	broken.terrain[2].top[0][1] += 80.0
	if validator.validate(broken).is_empty():
		failures.append("Validator accepted disconnected physical terrain")
	for malformed in [{}, {"version": 1}, {"version": 1, "seed": 1, "decoration_seed": 1, "terrain": null}]:
		if validator.validate(malformed).is_empty():
			failures.append("Validator accepted malformed persisted geometry")
	for representative_seed in [0, 42, 99]:
		await _physical_routes(tree, failures, representative_seed)
	return failures


func _same_geometry(first: Array, second: Array) -> bool:
	if first.size() != second.size():
		return false
	for i in range(first.size()):
		if first[i].region != second[i].region or first[i].polygon.size() != second[i].polygon.size():
			return false
		for j in range(first[i].polygon.size()):
			for coordinate in range(2):
				if absf(float(first[i].polygon[j][coordinate]) - float(second[i].polygon[j][coordinate])) > 0.00001:
					return false
	return true

func _physical_routes(tree: SceneTree, failures: Array[String], seed_value: int) -> void:
	var world = load("res://game/world/world.gd").new()
	tree.root.add_child(world)
	world.build(seed_value)
	var player = load("res://game/player/player_controller.gd").new()
	player.input_enabled = false
	tree.root.add_child(player)
	player.water_query = world.water_at
	player.camera.enabled = false
	await tree.physics_frame
	var generator = load("res://game/world/generation/world_generator.gd").new()
	player.respawn(Vector2(500, generator._floor_at(world.layout, 500) - 24))
	await _advance(tree, player, 220, Vector2.RIGHT)
	if player.position.x < 1200 or player.position.y > 800:
		failures.append("Real controller failed generated surface slope: " + str(player.position))
	var floor_y: float = generator._floor_at(world.layout, 6700)
	player.respawn(Vector2(6520, floor_y - 24))
	player.controls.grip = true
	player.controls.aim = Vector2(1, -0.15).normalized()
	await _advance(tree, player, 110, Vector2.UP)
	await _advance(tree, player, 90, Vector2.RIGHT)
	player.controls.grip = false
	await _advance(tree, player, 30, Vector2.ZERO)
	if player.position.y > floor_y - 175 or player.position.x < 6560:
		failures.append("Real controller failed canopy climb: " + str(player.position))
	floor_y = generator._floor_at(world.layout, 22900)
	player.respawn(Vector2(22760, floor_y - 24))
	player.controls.squeeze = true
	await _advance(tree, player, 100, Vector2.RIGHT)
	player.controls.squeeze = false
	await _advance(tree, player, 15, Vector2.RIGHT)
	if player.shape_mode != "squeeze" or player.position.x < 22840:
		failures.append("Real controller failed generated squeeze clearance: " + str(player.position))
	await _advance(tree, player, 200, Vector2.RIGHT)
	if player.position.x < 23130:
		failures.append("Real controller could not exit squeeze branch")
	var pool: Rect2 = world.waters[1]
	player.respawn(Vector2(pool.position.x + 320, generator._floor_at(world.layout, pool.position.x + 320) - 26))
	await _advance(tree, player, 110, Vector2.UP)
	await _advance(tree, player, 230, Vector2(1, -0.3).normalized())
	if player.position.x < pool.end.x or player.vitals.health < 100:
		failures.append("Real controller failed pool exit: " + str(player.position))
	player.free()
	world.free()
	await tree.physics_frame

func _advance(tree: SceneTree, player: Node2D, frames: int, movement: Vector2) -> void:
	player.controls.move = movement
	for _frame in range(frames):
		await tree.physics_frame
		player.step_motion(1.0 / 60.0)
