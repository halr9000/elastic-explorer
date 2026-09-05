class_name EELandmark
extends Node2D

var stable_id: String = ""
var kind: String = "checkpoint"
var label: String = ""
var activated: bool = false
var near_player: bool = false
var clock: float = 0.0

func configure(data: Dictionary) -> void:
	stable_id = str(data.get("id", ""))
	kind = str(data.get("kind", "checkpoint"))
	label = str(data.get("label", kind.capitalize()))
	position = data.get("position", Vector2.ZERO)

func _ready() -> void:
	if kind == "artifact" or kind == "checkpoint":
		var gradient: Gradient = Gradient.new()
		gradient.set_color(0, Color(0.4, 1.0, 0.8, 0.6) if kind == "checkpoint" else Color(1, 0.55, 0.3, 0.6))
		gradient.set_color(1, Color(0, 0, 0, 0))
		var texture: GradientTexture2D = GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 256
		texture.height = 256
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(0.5, 0)
		var light: PointLight2D = PointLight2D.new()
		light.texture = texture
		light.position.y = -35
		light.energy = 0.9
		add_child(light)

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	var glow: Color = Color("a7f4d0") if kind == "checkpoint" else Color("ffd39c")
	var bob: float = sin(clock * 2.0) * 3.0
	if kind == "checkpoint":
		draw_colored_polygon(PackedVector2Array([Vector2(-24, 12), Vector2(-14, -30), Vector2(12, -32), Vector2(24, 12)]), Color("253e50"))
		draw_line(Vector2(-10, -24), Vector2(-3, 5), Color("58868b"), 3, true)
		draw_circle(Vector2(0, -40 + bob), 10, Color("264d58"))
		draw_arc(Vector2(0, -40 + bob), 8, clock, clock + 5.0, 20, glow, 2, true)
		draw_circle(Vector2(0, -40 + bob), 3, glow)
	elif kind == "artifact":
		var center: Vector2 = Vector2(0, -42 + bob)
		draw_colored_polygon(PackedVector2Array([Vector2(-30, 10), Vector2(-23, -16), Vector2(20, -16), Vector2(30, 10)]), Color("3c4356"))
		for index: int in range(3):
			var angle: float = clock * 0.4 + float(index) * TAU / 3
			var offset: Vector2 = Vector2.from_angle(angle) * 25
			draw_line(center + offset, center + offset.rotated(0.7), glow, 3, true)
		draw_colored_polygon(PackedVector2Array([center + Vector2(0, -18), center + Vector2(12, 0), center + Vector2(0, 18), center + Vector2(-12, 0)]), Color("b5ffe1") if activated else Color("f0b983"))
		draw_line(center + Vector2(0,-10), center + Vector2(0,10), Color("fff5d0"), 2, true)
	else:
		if activated:
			return
		var center: Vector2 = Vector2(0, -18 + bob)
		draw_arc(center, 17, clock, clock + 4.5, 20, glow * Color(1,1,1,0.4), 1, true)
		draw_circle(center, 8, Color("e1a9dd") if kind == "thorn" else glow)
		if kind == "thorn":
			for index: int in range(5):
				var axis: Vector2 = Vector2.from_angle(float(index) * TAU / 5 + clock)
				draw_line(center + axis * 6, center + axis * 14, Color("f4ddef"), 3, true)
		elif kind == "health":
			draw_line(center - Vector2(4,0), center + Vector2(4,0), Color("3c6f69"), 3)
			draw_line(center - Vector2(0,4), center + Vector2(0,4), Color("3c6f69"), 3)
	if near_player:
		draw_arc(Vector2(0, -25), 39, 0, TAU, 40, Color(0.8, 1, 0.85, 0.22), 1, true)
