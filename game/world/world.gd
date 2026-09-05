class_name EEWorld
extends Node2D
const Generator = preload("res://game/world/generation/world_generator.gd")
const Validator = preload("res://game/world/generation/route_validator.gd")
const TerrainArt = preload("res://game/environment/terrain_art.gd")
const Backdrop = preload("res://game/environment/backdrop.gd")
var layout: Dictionary = {}
var bounds := Rect2(0.0, -1000.0, 24000.0, 3100.0)
var spawn_point := Vector2(120.0, 365.0)
var checkpoints: Array[Vector2] = []
var landmarks: Array[Dictionary] = []
var creature_spawns: Array[Dictionary] = []
var waters: Array[Rect2] = []
var chunks: Array[Node2D] = []
var backdrop: Node2D
var view_position := Vector2.ZERO
var clock := 0.0
var reduced_effects := false
var modulation: CanvasModulate

func build(seed_value: int, saved_layout: Dictionary = {}) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	chunks.clear()
	checkpoints.clear()
	landmarks.clear()
	creature_spawns.clear()
	waters.clear()
	modulation = CanvasModulate.new()
	modulation.color = Color(0.78, 0.88, 0.92)
	add_child(modulation)
	layout = saved_layout.duplicate(true) if not saved_layout.is_empty() else Generator.new().generate(seed_value)
	if saved_layout.is_empty():
		var failures: Array[String] = Validator.new().validate(layout)
		if not failures.is_empty():
			layout = Generator.new().generate(0)
			layout.rejections.append({"seed": seed_value, "reasons": failures})
	backdrop = Backdrop.new()
	backdrop.z_index = -20
	add_child(backdrop)
	for module in layout.terrain:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionPolygon2D.new()
		collision.polygon = _points(module.polygon)
		body.add_child(collision)
		add_child(body)
		var art := TerrainArt.new()
		art.configure(module, int(layout.decoration_seed))
		add_child(art)
		chunks.append(art)
		if module.region != "surface" and not module.has("branch"):
			var top: Array = module.top
			var roof_y := minf(float(top[0][1]), float(top[-1][1])) - 430.0
			var roof := StaticBody2D.new()
			roof.collision_layer = 1
			roof.collision_mask = 0
			var roof_shape := CollisionShape2D.new()
			var rectangle := RectangleShape2D.new()
			rectangle.size = Vector2(1200.0, 240.0)
			roof_shape.shape = rectangle
			roof_shape.position = Vector2(float(top[0][0]) + 600.0, roof_y - 120.0)
			roof.add_child(roof_shape)
			add_child(roof)
			art.roof_y = roof_y
	for water in layout.waters:
		waters.append(Rect2(float(water[0]), float(water[1]), float(water[2]), float(water[3])))
	for entry in layout.landmarks:
		var item: Dictionary = entry.duplicate(true)
		item.position = Vector2(float(entry.position[0]), float(entry.position[1]))
		landmarks.append(item)
		if item.kind == "checkpoint":
			checkpoints.append(item.position)
	for entry in layout.creatures:
		var item: Dictionary = entry.duplicate(true)
		item.position = Vector2(float(entry.position[0]), float(entry.position[1]))
		creature_spawns.append(item)
	spawn_point = checkpoints[0] if not checkpoints.is_empty() else Vector2(120.0, 365.0)
	# End caps prevent falling outside the finite expedition.
	bounds.size.x = float(layout.get("width", 24000.0))
	for x in [-40.0, bounds.size.x + 40.0]:
		var cap := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(80.0, 4000.0)
		shape.shape = rectangle
		shape.position = Vector2(x, 700.0)
		cap.add_child(shape)
		add_child(cap)
	queue_redraw()

func build_playground() -> void:
	build(42, Generator.new().playground())

func water_at(point: Vector2) -> Rect2:
	for water in waters:
		if water.has_point(point):
			return water
	return Rect2()

func update_view(camera_position: Vector2, time: float) -> void:
	view_position = camera_position
	clock = time
	for chunk in chunks:
		chunk.visible = absf(chunk.center_x - camera_position.x) < 1800.0
		for light: Node in chunk.get_children():
			if light is PointLight2D:
				light.enabled = not reduced_effects
	var underground: float = smoothstep(8000, 9200, camera_position.x)
	modulation.color = Color(0.78, 0.88, 0.92).lerp(Color(0.54, 0.62, 0.8), underground)
	if is_instance_valid(backdrop):
		backdrop.view_position = camera_position
		backdrop.clock = time
		backdrop.reduced_effects = reduced_effects
		backdrop.queue_redraw()
	queue_redraw()

func _points(source: Array) -> PackedVector2Array:
	var output := PackedVector2Array()
	for point in source:
		output.append(Vector2(float(point[0]), float(point[1])))
	return output

func _draw() -> void:
	for water in waters:
		if absf(water.get_center().x - view_position.x) > 1600.0:
			continue
		draw_rect(water, Color(0.04, 0.54, 0.64, 0.37))
		for stripe in range(8):
			var rect := Rect2(water.position + Vector2(0, stripe * 27.0), Vector2(water.size.x, 27.0))
			draw_rect(rect, Color(0.025, 0.20, 0.32, stripe * 0.035))
		var surface := PackedVector2Array()
		for i in range(66):
			var x := water.position.x + water.size.x * i / 65.0
			surface.append(Vector2(x, water.position.y + sin(x * 0.032 + clock * 1.7) * 2.0))
		draw_polyline(surface, Color(0.46, 1.0, 0.87, 0.8), 2.0)
		for i in range(10):
			var x := water.position.x + fmod(i * 73.0 + clock * 10.0, water.size.x)
			draw_line(Vector2(x, water.position.y + 4.0), Vector2(x + 13.0, water.position.y + 4.0), Color(0.68, 1.0, 0.85, 0.4), 1.0)
