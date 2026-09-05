class_name EEVitalMeter
extends Control

var value: float = 100.0:
	set(new_value):
		value = clampf(new_value, 0, 100)
		queue_redraw()
var color: Color = Color.WHITE

func _draw() -> void:
	draw_rect(Rect2(0, 0, size.x, 4), Color(0.04, 0.09, 0.12, 0.65))
	draw_rect(Rect2(0, 0, size.x * value / 100.0, 4), color)
	for index: int in range(1, 5):
		draw_line(Vector2(size.x * index / 5.0, 0), Vector2(size.x * index / 5.0, 4), Color(0.06,0.1,0.12,0.4), 1)
