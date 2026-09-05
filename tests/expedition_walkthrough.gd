extends SceneTree
## Scripted route through the real controller; no teleports or direct reward grants.
## This proves traversal, not human pacing or controller comfort.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: EEGame = EEGame.new()
	game.test_mode = true
	root.add_child(game)
	game.start_expedition(42)
	var player: EEPlayer = game.player
	player.input_enabled = false
	var frame: int = 0
	var deaths: Array[int] = [0]
	player.died.connect(func() -> void: deaths[0] += 1)
	var previous_x: float = player.position.x
	var stuck: int = 0
	while not game.completed and frame < 22000:
		await physics_frame
		var target: EELandmark = game.markers[0]
		if game.resonator_count() < 3:
			for marker: EELandmark in game.markers:
				if marker.kind == "artifact" and not marker.activated:
					target = marker
					break
		var offset: Vector2 = target.global_position - player.global_position
		var direction: float = signf(offset.x)
		player.controls.move = Vector2(direction, 0)
		player.controls.aim = Vector2(direction, -0.15).normalized()
		player.controls.grip = false
		player.controls.squeeze = player.position.x > 22720
		player.controls.jump_pressed = false
		player.controls.attack = true
		# Grip either side of the canopy plinth, then pull onto its roof.
		if player.position.x > 6500 and player.position.x < 6800:
			var generator: RefCounted = load("res://game/world/generation/world_generator.gd").new()
			var floor_y: float = generator.call("_floor_at", game.world.layout, 6700.0)
			if player.position.y > floor_y - 202.0:
				player.controls.grip = true
				player.controls.move = Vector2.UP
			else:
				player.controls.grip = true
				player.controls.move = Vector2(direction, 0)
		if player.water.has_area():
			player.controls.move = Vector2(direction, -0.3).normalized()
			if target.stable_id == "resonator_tide" and absf(offset.x) < 330:
				player.controls.move = offset.normalized()
			if player.vitals.endurance < 28:
				player.controls.move = Vector2.UP if player.position.y > player.water.position.y + 18 else Vector2.ZERO
		game._update_proximity()
		if is_instance_valid(game.nearest):
			var nearby: EELandmark = game.nearest
			if nearby == target or (nearby.kind in ["health", "heavy", "thorn"] and not nearby.activated):
				game.activate_landmark(nearby)
		player.step_motion(1.0 / 60.0)
		if absf(player.position.x - previous_x) < 0.05 and not player.controls.grip:
			stuck += 1
		else:
			stuck = 0
		if stuck > 60:
			player.controls.jump_pressed = true
			player.step_motion(1.0 / 60.0)
			stuck = 0
		previous_x = player.position.x
		frame += 1
		if frame % 3000 == 0:
			print("ROUTE: frame=", frame, " position=", player.position, " artifacts=", game.resonator_count(), " health=", player.vitals.health)
	print("WALKTHROUGH: complete=", game.completed, " simulation_seconds=", float(frame) / 60.0, " deaths=", deaths[0], " final=", player.position)
	var success: bool = game.completed
	game.audio.stop_all()
	game.queue_free()
	await process_frame
	# This harness normally runs uncapped; allow the mixer real time to finish.
	OS.delay_msec(200)
	await process_frame
	quit(0 if success else 1)
