extends RefCounted

func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	if not ResourceLoader.exists("res://game/player/vitals.gd"):
		failures.append("Shared endurance behavior not implemented")
		return failures
	var script: Script = load("res://game/player/vitals.gd") as Script
	var vitals: RefCounted = script.new() as RefCounted
	vitals.call("tick", 2.0, "climb", false, false)
	if not is_equal_approx(float(vitals.get("endurance")), 64.0):
		failures.append("Climbing must consume shared endurance")
	vitals.call("tick", 2.0, "swim", false, true)
	if not is_equal_approx(float(vitals.get("endurance")), 50.0):
		failures.append("Swimming must continue consuming the same pool")
	vitals.call("tick", 1.0, "swim", true, false)
	if not is_equal_approx(float(vitals.get("endurance")), 80.0):
		failures.append("Safe surface floating must recover endurance")
	vitals.set("endurance", 0.0)
	vitals.call("tick", 0.5, "swim", false, true)
	if float(vitals.get("health")) != 100.0:
		failures.append("Drowning needs warning before health loss")
	vitals.call("tick", 1.2, "swim", false, true)
	if float(vitals.get("health")) >= 100.0:
		failures.append("Exhausted submerged player must lose health after warning")
	vitals.call("restore")
	if float(vitals.get("health")) != 100.0 or float(vitals.get("endurance")) != 100.0:
		failures.append("Checkpoint restore must restore both vitals")
	vitals.call("damage", 15.0)
	vitals.call("damage", 15.0)
	if float(vitals.get("health")) != 85.0:
		failures.append("Contact invulnerability must prevent repeated immediate damage")
	await _motion_regressions(tree, failures)
	return failures

func _terrain(parent: Node2D, position: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.position = position
	body.add_child(collision)
	parent.add_child(body)
	return body

func _step(tree: SceneTree, player: EEPlayer, frames: int) -> void:
	for _frame in range(frames):
		await tree.physics_frame
		player.step_motion(1.0 / 60.0)

func _motion_regressions(tree: SceneTree, failures: Array[String]) -> void:
	var fixture := Node2D.new()
	tree.root.add_child(fixture)
	_terrain(fixture, Vector2(0, 200), Vector2(3000, 30))
	var player := EEPlayer.new()
	player.position = Vector2(0, 162)
	player.input_enabled = false
	player.water_query = func(_point: Vector2) -> Rect2: return Rect2(-1500, 0, 3000, 500)
	fixture.add_child(player)
	player.camera.enabled = false
	player.vitals.endurance = 0
	await _step(tree, player, 180)
	if player.vitals.health >= 100.0 or player.vitals.endurance > 0.0:
		failures.append("Deep underwater floor must not restore endurance or prevent drowning")
	player.vitals.restore()
	player.vitals.endurance = 0
	player.water_query = func(_point: Vector2) -> Rect2: return Rect2(-1500, 150, 3000, 350)
	await _step(tree, player, 60)
	if player.vitals.endurance <= 0.0 or player.vitals.health < 100.0:
		failures.append("Shallow water footing must restore endurance safely")

	player.controls.sample(player)
	player.controls.using_controller = true
	player.controls.aim = Vector2.LEFT
	var original_canvas: Transform2D = tree.root.canvas_transform
	var shifted_canvas := original_canvas
	shifted_canvas.origin += Vector2(10, 0)
	tree.root.canvas_transform = shifted_canvas
	player.controls.sample(player)
	if not player.controls.using_controller or not player.controls.aim.is_equal_approx(Vector2.LEFT):
		failures.append("Camera movement without mouse movement must preserve controller aim")
	tree.root.canvas_transform = original_canvas

	player.water_query = Callable()
	player.controls.move = Vector2.ZERO
	player.controls.jump_pressed = false
	player.controls.jump_released = false
	player.respawn(Vector2(0, 162))
	await _step(tree, player, 5)
	var ground_y: float = player.position.y
	player.controls.jump_pressed = true
	await _step(tree, player, 1)
	player.controls.jump_pressed = false
	var apex_y: float = player.position.y
	for _frame in range(55):
		await _step(tree, player, 1)
		apex_y = minf(apex_y, player.position.y)
	var height: float = ground_y - apex_y
	if height < 85.0 or height > 100.0:
		failures.append("Real jump height must match controller tuning (got %.2f)" % height)
	await _step(tree, player, 15)
	player.controls.roll = true
	player.controls.move = Vector2.RIGHT
	await _step(tree, player, 65)
	if player.mode != "roll" or player.velocity.x <= player.config.walk_speed * 1.5:
		failures.append("Rolling must use roll collider and accelerate beyond walking speed")
	player.controls.roll = false
	player.controls.move = Vector2.ZERO
	player.respawn(Vector2(0, 162))
	await _step(tree, player, 5)
	player.controls.squeeze = true
	await _step(tree, player, 3)
	if player.shape_mode != "squeeze":
		failures.append("Squeeze must compress on clear ground")
	var ceiling := _terrain(fixture, Vector2(0, 130), Vector2(120, 30))
	await _step(tree, player, 2)
	player.controls.squeeze = false
	await _step(tree, player, 3)
	if player.shape_mode != "squeeze":
		failures.append("Releasing squeeze below a low ceiling must keep compressed collision")
	ceiling.queue_free()
	await _step(tree, player, 3)
	if player.shape_mode != "walk":
		failures.append("Player must expand once overhead clearance is restored")
	fixture.queue_free()
	await tree.process_frame
