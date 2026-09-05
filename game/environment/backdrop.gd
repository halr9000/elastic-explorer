extends Node2D
var view_position := Vector2.ZERO
var clock := 0.0
var reduced_effects := false

func _draw() -> void:
	var view := view_position
	var left := view.x - 1450.0
	var upper := view.y - 850.0
	var cave_mix := smoothstep(7800.0, 9000.0, view.x)
	var water_mix := smoothstep(15100.0, 16400.0, view.x)
	var high := Color("172f47").lerp(Color("0c172d"), cave_mix).lerp(Color("102a3d"), water_mix)
	var low := Color("87b4a0").lerp(Color("32405a"), cave_mix).lerp(Color("286a70"), water_mix)
	for i in range(128):
		draw_rect(Rect2(left, upper + i * 14.0, 2900.0, 15.0), high.lerp(low, i / 127.0))
	if cave_mix < 0.99:
		var sun := Vector2(view.x + 400.0 - fmod(view.x * 0.03, 800.0), view.y - 225.0)
		for i in range(8, 0, -1):
			draw_circle(sun, 25.0 + i * 13.0, Color(0.87, 0.94, 0.70, 0.012 * (1.0 - cave_mix)))
		draw_circle(sun, 27.0, Color(0.82, 0.92, 0.74, 0.65 * (1.0 - cave_mix)))
	for layer in range(3):
		var speed := 0.12 + layer * 0.14
		var ridge := PackedVector2Array()
		var base_y := view.y + 80.0 + layer * 75.0
		for i in range(65):
			var x := left + i * 46.0
			var phase := (x - view.x + view.x * speed) * (0.0023 + layer * 0.0006)
			var y := base_y + sin(phase) * 130.0 + sin(phase * 2.9) * 31.0
			ridge.append(Vector2(x, y))
		ridge.append(Vector2(left + 3000.0, upper + 1900.0))
		ridge.append(Vector2(left, upper + 1900.0))
		var tone := Color("4c777a").darkened(layer * 0.15).lerp(Color("1c2d47").lightened(layer * 0.025), cave_mix)
		draw_colored_polygon(ridge, tone)
	# Large silhouetted trunks give scale; their seed is world-indexed, never frame-indexed.
	for layer in range(2):
		var spacing := 310.0 if layer == 0 else 470.0
		var parallax := 0.22 if layer == 0 else 0.48
		var offset := view.x * parallax
		var base_index := int(floor(offset / spacing))
		for j in range(-5, 6):
			var idx := base_index + j
			var x := view.x + idx * spacing - offset
			var rng := RandomNumberGenerator.new()
			rng.seed = idx * 719 + layer * 3459 + 9201
			var height := rng.randf_range(280.0, 520.0)
			var origin := Vector2(x, view.y + 290.0 + layer * 80.0)
			var tone := Color("31585e") if layer == 0 else Color("25454c")
			tone = tone.lerp(Color("14263a"), cave_mix)
			if cave_mix < 0.5:
				var tip := origin - Vector2(rng.randf_range(-60, 60), height)
				draw_line(origin, tip, tone, 15.0 + layer * 7.0)
				for k in range(5):
					var joint := origin.lerp(tip, 0.38 + k * 0.12)
					var sign_value := -1.0 if k % 2 == 0 else 1.0
					var end := joint + Vector2(sign_value * 90.0, -40.0)
					draw_line(joint, end, tone, 7.0)
					_crown(end, Vector2(67, 28), tone, float(idx + k))
					_crown(end + Vector2(sign_value * 30.0, -10), Vector2(46,21), tone, float(idx-k))
			else:
				draw_colored_polygon(PackedVector2Array([origin + Vector2(-95, 200), origin + Vector2(-70, -height * 0.4), origin + Vector2(-16, -height), origin + Vector2(40, -height * 0.7), origin + Vector2(85, 200)]), tone)
	# Quiet diagonal shafts and floating motes; reduced effects retains all navigation art.
	if not reduced_effects:
		for i in range(5):
			var x := left + fposmod(i * 487.0 - view.x * 0.12, 2900.0)
			draw_colored_polygon(PackedVector2Array([Vector2(x, upper), Vector2(x + 32, upper), Vector2(x - 240, upper + 1400), Vector2(x - 370, upper + 1400)]), Color(0.64, 0.89, 0.72, 0.025))
		for i in range(42):
			var x := left + fposmod(i * 179.3 + sin(clock * 0.21 + i) * 28.0 - view.x * 0.08, 2900.0)
			var y := upper + fposmod(i * 87.9 - clock * (3.0 + i % 4), 1600.0)
			var alpha := 0.15 + 0.15 * sin(clock + i)
			draw_circle(Vector2(x, y), 1.7, Color(0.74, 0.95, 0.67, alpha))

func _crown(center: Vector2, size_value: Vector2, color: Color, phase: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(32):
		var angle: float = float(i) * TAU / 32.0
		var radius: float = 0.86 + sin(angle * 7 + phase) * 0.13 + sin(angle * 13) * 0.08
		points.append(center + Vector2.from_angle(angle) * size_value * radius)
	draw_colored_polygon(points, color)
