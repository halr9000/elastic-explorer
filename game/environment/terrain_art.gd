extends Node2D
## Original vector vegetation with deliberately coarse, repeated pigment marks.
var data: Dictionary
var decoration_seed := 0
var center_x := 0.0
var roof_y := INF
var reduced_effects: bool = false
var leaf_meshes: Array[ArrayMesh] = []

func configure(module: Dictionary, seed_value: int) -> void:
	data = module
	decoration_seed = seed_value + int(module.index) * 7139
	center_x = (float(module.top[0][0]) + float(module.top[-1][0])) * 0.5

func _ready() -> void:
	var occluder: LightOccluder2D = LightOccluder2D.new()
	var occluder_polygon: OccluderPolygon2D = OccluderPolygon2D.new()
	var outline: PackedVector2Array = PackedVector2Array()
	for coordinate: Array in data.polygon:
		outline.append(Vector2(float(coordinate[0]), float(coordinate[1])))
	occluder_polygon.polygon = outline
	occluder.occluder = occluder_polygon
	add_child(occluder)
	if data.region == "surface" or data.has("branch"):
		return
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.55, 1.0, 0.86, 0.5))
	gradient.set_color(1, Color(0.12, 0.48, 0.76, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	for fraction in [0.25, 0.75]:
		var lamp := PointLight2D.new()
		lamp.texture = texture
		lamp.texture_scale = 2.0
		lamp.energy = 0.55
		lamp.position = Vector2(float(data.top[0][0]) + 1200.0 * float(fraction), float(data.top[0][1]) - 35.0)
		add_child(lamp)

func _draw() -> void:
	leaf_meshes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = decoration_seed
	var surface: bool = data.region == "surface"
	var aquatic: bool = data.region == "aquatic"
	var stone := Color("293943") if surface else Color("232639")
	var edge := Color("a3c76d") if surface else (Color("55aaad") if aquatic else Color("8a8daa"))
	var polygon := PackedVector2Array()
	var top := PackedVector2Array()
	for point in data.polygon:
		polygon.append(Vector2(float(point[0]), float(point[1])))
	for point in data.top:
		top.append(Vector2(float(point[0]), float(point[1])))
	draw_colored_polygon(polygon, stone)
	# Darken strata with depth, so illuminated edges read against substantial rock.
	for layer: int in range(18):
		var strata: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in top:
			strata.append(point + Vector2(0, 24 + layer * 23))
		for index: int in range(top.size() - 1, -1, -1):
			strata.append(top[index] + Vector2(0, 49 + layer * 23))
		if not data.has("branch"):
			draw_colored_polygon(strata, Color(0.025, 0.03, 0.05, minf(0.7, layer * 0.052)))
	# Sedimentary facets remain bounded to this module and use the actual floor.
	for i in range(150 if not data.has("branch") else 15):
		var x := rng.randf_range(top[0].x, top[-1].x)
		var ground := _height(top, x)
		var depth := rng.randf_range(12.0, 410.0 if not data.has("branch") else 60.0)
		var w := rng.randf_range(4.0, 40.0)
		var tone := stone.lightened(rng.randf_range(0.01, 0.13))
		draw_rect(Rect2(x, ground + depth, w, rng.randf_range(2.0, 7.0)), tone)
	for layer in range(3):
		var line := PackedVector2Array()
		for point in top:
			line.append(point + Vector2(0, 6.0 + layer * 5.0))
		draw_polyline(line, edge.darkened(0.3 + layer * 0.16), 6.0)
	draw_polyline(top, edge, 4.0)
	if not data.has("branch"):
		for i in range(54):
			var x := top[0].x + rng.randf_range(7.0, 1193.0)
			var y := _height(top, x)
			var h := rng.randf_range(10.0, 34.0)
			if surface:
				_grass(Vector2(x, y), h, rng, edge)
			elif i % 3 == 0:
				_mushroom(Vector2(x, y), h, Color("66e7c2") if aquatic else Color("cea8dc"))
		for i in range(5):
			var x := top[0].x + 80.0 + i * 245.0 + rng.randf_range(-45.0, 45.0)
			var y := _height(top, x)
			if surface:
				_tree(Vector2(x, y), rng.randf_range(155.0, 320.0), rng)
			elif i % 2 == 0:
				_crystal(Vector2(x, y), rng.randf_range(25.0, 54.0), Color("398d9e") if aquatic else Color("756d9b"))
		if int(data.index) % 3 == 1:
			_ruin(Vector2(top[0].x + 800.0, _height(top, top[0].x + 800.0)), edge)
	if roof_y < INF:
		draw_rect(Rect2(top[0].x, roof_y - 250.0, 1200.0, 250.0), Color("182539"))
		for i in range(35):
			var x := top[0].x + i * 35.0
			var length := rng.randf_range(12.0, 65.0)
			draw_colored_polygon(PackedVector2Array([Vector2(x, roof_y), Vector2(x + 28.0, roof_y), Vector2(x + 15.0, roof_y + length)]), Color("304457"))
		for i in range(12):
			var x := top[0].x + rng.randf_range(0.0, 1200.0)
			var length := rng.randf_range(30.0, 135.0)
			draw_line(Vector2(x, roof_y), Vector2(x + 7.0, roof_y + length), Color("356664"), 2.0)
			for j in range(5):
				var p := Vector2(x + 7.0, roof_y + length * j / 5.0)
				draw_circle(p, 3.0, Color("5eab96"))

func _height(top: PackedVector2Array, x: float) -> float:
	for i in range(top.size() - 1):
		if x >= top[i].x and x <= top[i + 1].x:
			return lerpf(top[i].y, top[i + 1].y, inverse_lerp(top[i].x, top[i + 1].x, x))
	return top[0].y

func _grass(origin: Vector2, height: float, rng: RandomNumberGenerator, color: Color) -> void:
	for blade in range(5):
		var tip := origin + Vector2((blade - 2) * 5.0, -height * rng.randf_range(0.5, 1.0))
		draw_line(origin, tip, color.darkened(rng.randf_range(0.0, 0.3)), 2.0)
	if rng.randf() < 0.22:
		draw_circle(origin + Vector2(0, -height), 3.0, Color("eccc83"))

func _tree(origin: Vector2, height: float, rng: RandomNumberGenerator) -> void:
	# Branch fans and small leaf strokes make airy crowns, rather than round blobs.
	var leaf_vertices: PackedVector3Array = PackedVector3Array()
	var leaf_colors: PackedColorArray = PackedColorArray()
	var lean := rng.randf_range(-28.0, 28.0)
	var tip := origin + Vector2(lean, -height)
	var trunk: PackedVector2Array = PackedVector2Array([origin + Vector2(-12,0), origin.lerp(tip,0.4)+Vector2(-7,0), tip + Vector2(-3,0), tip + Vector2(3,0), origin.lerp(tip,0.4)+Vector2(5,0), origin + Vector2(17,0)])
	draw_colored_polygon(trunk, Color("274b4c"))
	draw_polyline(PackedVector2Array([origin + Vector2(5,0), origin.lerp(tip,0.4) + Vector2(3,0), tip]), Color("668276"), 2)
	for root_index: int in range(3):
		draw_line(origin + Vector2(root_index*6 - 5,-7), origin + Vector2((root_index-1)*28,2), Color("36554e"), 4)
	for i in range(7):
		var joint := origin.lerp(tip, 0.36 + i * 0.095)
		var sign_value := -1.0 if i % 2 == 0 else 1.0
		var end := joint + Vector2(sign_value * height * (0.3 - i * 0.013), -height * 0.17)
		var bend: Vector2 = joint.lerp(end,0.45) + Vector2(0, 12)
		draw_polyline(PackedVector2Array([joint,bend,end]), Color("4d7063"), 3.0)
		for twig_index: int in range(4):
			var twig: Vector2 = bend.lerp(end, float(twig_index) / 4.0)
			var twig_end: Vector2 = twig + Vector2(sign_value * rng.randf_range(10,35), -rng.randf_range(14,38))
			draw_line(twig, twig_end, Color("4e7963"), 1.5)
			for leaf: int in range(15):
				var center: Vector2 = twig_end + Vector2(rng.randf_range(-23,23),rng.randf_range(-12,10))
				var size_value: Vector2 = Vector2(rng.randf_range(5,13),rng.randf_range(2,5))
				var color: Color = Color("477b64").lerp(Color("9cba72"), rng.randf() * 0.75)
				var corners: PackedVector2Array = PackedVector2Array([center-size_value,center+Vector2(size_value.x,-size_value.y*0.4),center+size_value,center+Vector2(-size_value.x,size_value.y*0.4)])
				for corner_index: int in [0, 1, 2, 0, 2, 3]:
					var point: Vector2 = corners[corner_index]
					leaf_vertices.append(Vector3(point.x, point.y, 0))
					leaf_colors.append(color)
		if i % 3 == 0:
			var vine_length: float = rng.randf_range(40,110)
			draw_line(end,end+Vector2(-5,vine_length),Color("557863"),1)
			for leaf: int in range(6):
				var p: Vector2 = end + Vector2(-5, vine_length * leaf / 6)
				draw_line(p,p+Vector2(7,-5),Color("83ac74"),3)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = leaf_vertices
	arrays[Mesh.ARRAY_COLOR] = leaf_colors
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	leaf_meshes.append(mesh)
	draw_mesh(mesh, null)

func _mushroom(origin: Vector2, height: float, color: Color) -> void:
	draw_line(origin, origin + Vector2(0, -height), color.darkened(0.4), 3.0)
	var tip := origin + Vector2(0, -height)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(-height * 0.45, 3), tip + Vector2(-5, -7), tip + Vector2(5, -7), tip + Vector2(height * 0.45, 3)]), color)
	draw_line(tip + Vector2(-height * 0.4, 3), tip + Vector2(height * 0.4, 3), color.lightened(0.4), 2.0)

func _crystal(origin: Vector2, height: float, color: Color) -> void:
	for i in range(3):
		var base := origin + Vector2(i * 12.0 - 12.0, 0)
		var tip := base + Vector2(i * 6.0 - 6.0, -height * (0.6 if i != 1 else 1.0))
		draw_colored_polygon(PackedVector2Array([base - Vector2(9, 0), tip, base + Vector2(9, 0)]), color)
		draw_line(tip, base, color.lightened(0.25), 2.0)

func _ruin(origin: Vector2, color: Color) -> void:
	for side in [-1.0, 1.0]:
		var x: float = origin.x + side * 43.0
		draw_rect(Rect2(x - 12.0, origin.y - 98.0, 24.0, 98.0), Color("3b545c"))
		for i in range(4):
			draw_line(Vector2(x - 12.0, origin.y - i * 24.0), Vector2(x + 12.0, origin.y - i * 24.0), Color("1c3745"), 3.0)
	draw_line(origin + Vector2(-57, -101), origin + Vector2(56, -101), Color("638681"), 14.0)
	draw_circle(origin + Vector2(0, -99), 5.0, color.lightened(0.2))
