extends RefCounted

func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	if not ResourceLoader.exists("res://game/main.gd"):
		failures.append("Playable expedition integration not implemented")
		return failures
	var script: Script = load("res://game/main.gd") as Script
	if not script.can_instantiate():
		failures.append("Main game cannot instantiate")
		return failures
	var game: Node2D = script.new() as Node2D
	game.set("test_mode", true)
	game.set("save_service", EESaveService.new("user://test_integration_" + str(Time.get_ticks_usec())))
	tree.root.add_child(game)
	await tree.process_frame
	if str(game.get("ui").menu_state) != "title":
		failures.append("Game must open on start menu")
	game.call("start_expedition", 8127, {}, false)
	await tree.physics_frame
	await tree.physics_frame
	var player: EEPlayer = game.get("player") as EEPlayer
	player.input_enabled = false
	if player.attack_controller == null:
		failures.append("Player must have functional weapon controller")
	game.call("set_paused", true)
	var endurance: float = player.vitals.endurance
	await tree.process_frame
	if not tree.paused or player.vitals.endurance != endurance:
		failures.append("Pause must freeze world and vitals")
	game.call("set_paused", false)
	var landmarks: Array = game.get("markers")
	for marker: EELandmark in landmarks:
		if marker.kind in ["artifact", "heavy", "thorn"]:
			game.call("activate_landmark", marker)
	if int(game.call("resonator_count")) != 3:
		failures.append("All three resonators must activate and persist")
	var checkpoint_marker: EELandmark = landmarks[0] as EELandmark
	game.call("activate_landmark", checkpoint_marker)
	if not bool(game.get("completed")):
		failures.append("Returning to starting beacon with resonators must complete expedition")
	var state: Dictionary = game.call("snapshot")
	if state.collected.size() < 5 or state.player.weapon != "thorn":
		failures.append("Save snapshot must include rewards and active weapon")
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	game.call("_unhandled_input", wheel)
	if player.attack_controller.get("weapon") != "club":
		failures.append("Wheel up must wrap to first acquired weapon")
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	game.call("_unhandled_input", wheel)
	if player.attack_controller.get("weapon") != "thorn":
		failures.append("Wheel down must wrap to last acquired weapon")
	game.call("set_paused", true)
	game.call("_unhandled_input", wheel)
	if player.attack_controller.get("weapon") != "thorn":
		failures.append("Wheel must not change weapons while paused")
	game.call("set_paused", false)
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_Q
	game.call("_unhandled_input", key)
	if player.attack_controller.get("weapon") != "thorn":
		failures.append("Q must no longer switch weapons")
	var button := InputEventJoypadButton.new()
	button.pressed = true
	button.button_index = JOY_BUTTON_Y
	game.call("_unhandled_input", button)
	if player.attack_controller.get("weapon") != "club":
		failures.append("Y must still cycle acquired weapons")
	var service: EESaveService = game.get("save_service") as EESaveService
	if service.save_game(state) != OK:
		failures.append("Integrated world snapshot must save: " + service.last_error)
	var restored: Dictionary = service.load_game()
	if restored.is_empty():
		failures.append("Integrated world snapshot must load")
	else:
		game.call("start_expedition", 8127, restored, false)
		if int(game.call("resonator_count")) != 3 or not bool(game.get("completed")):
			failures.append("Continue must preserve activated artifacts and completion")
	var squeezed: Dictionary = state.duplicate(true)
	var generator = load("res://game/world/generation/world_generator.gd").new()
	var floor_y: float = generator._floor_at(squeezed.layout, 22900.0)
	squeezed.player.position = [22900.0, floor_y - 8.0]
	squeezed.player.shape_mode = "squeeze"
	game.call("start_expedition", 8127, squeezed, false)
	await tree.physics_frame
	await tree.physics_frame
	await tree.physics_frame
	player = game.get("player") as EEPlayer
	player.input_enabled = false
	if player.shape_mode != "squeeze" or absf(player.global_position.x - 22900.0) > 2.0:
		failures.append("Continue must safely restore compressed tunnel position")
	var overlap := PhysicsShapeQueryParameters2D.new()
	overlap.shape = player.collider.shape
	overlap.transform = player.global_transform
	overlap.collision_mask = 1
	overlap.exclude = [player.get_rid()]
	if not player.get_world_2d().direct_space_state.intersect_shape(overlap).is_empty(): failures.append("Restored player must not overlap terrain")
	tree.paused = false
	# Let the queued pickup voices start/finish before destroying the owning scene.
	await tree.create_timer(0.6).timeout
	game.queue_free()
	await tree.process_frame
	# Audio playback objects retire on the mixer thread after node teardown.
	await tree.create_timer(0.2).timeout
	for suffix: String in [".json", ".bak", ".tmp"]:
		if FileAccess.file_exists(service.base_path + suffix):
			var error: Error = DirAccess.remove_absolute(service.base_path + suffix)
			if error != OK:
				failures.append("Could not clean test-owned save")
	return failures
