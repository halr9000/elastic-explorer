class_name EELimbRig
extends Node2D

var mode: String = "walk"
var aim: Vector2 = Vector2.RIGHT
var motion: Vector2 = Vector2.ZERO
var anchor: Vector2 = Vector2.ZERO
var has_anchor: bool = false
var attack_phase: float = -1.0
var attack_tip: Vector2 = Vector2.ZERO
var weapon: String = "club"
var endurance: float = 100.0
var hurt_time: float = 0.0
var clock: float = 0.0
var distance: float = 0.0
var feet: Array[Vector2] = [Vector2(-12, 20), Vector2(12, 20), Vector2(-21, -7), Vector2(21, -7)]
var tint: Color = Color("baffc9")

func _process(delta: float) -> void:
	clock += delta
	distance += motion.x * delta * 0.065
	queue_redraw()

func _draw() -> void:
	var outline: Color = Color("133c48")
	var body_color: Color = tint
	if hurt_time > 0.0 and fmod(clock * 15.0, 2.0) < 1.0:
		body_color = Color("fff4cd")
	if mode == "roll":
		draw_circle(Vector2.ZERO, 17.0, outline)
		draw_circle(Vector2.ZERO, 14.0, body_color)
		for index: int in range(4):
			var start: float = distance + float(index) * TAU / 4.0
			draw_arc(Vector2.ZERO, 9.0, start, start + 1.0, 10, Color("56b7a9"), 3.0, true)
	else:
		var sway: float = sin(clock * 2.5) * 1.5
		var speed_mix: float = clampf(absf(motion.x) / 150.0, 0.0, 1.0)
		var pose: Array[Vector2] = []
		if mode == "squeeze":
			pose = [Vector2(-25, 4), Vector2(25, 4), Vector2(-27, -4), Vector2(27, -4)]
		elif mode == "swim":
			for index: int in range(4):
				var angle: float = float(index) * TAU / 4.0 + clock * 1.5
				pose.append(Vector2.from_angle(angle) * (24.0 + sin(clock * 5.0 + index) * 7.0))
		else:
			pose = [Vector2(-12 + sin(distance) * 16 * speed_mix, 20 - maxf(0, cos(distance)) * 13 * speed_mix),
				Vector2(12 - sin(distance) * 16 * speed_mix, 20 - maxf(0, -cos(distance)) * 13 * speed_mix),
				Vector2(-23 - sway, -10 + sin(distance) * 8 * speed_mix),
				Vector2(23 + sway, -10 - sin(distance) * 8 * speed_mix)]
		if has_anchor:
			pose[2] = anchor
			pose[3] = Vector2(20, -25 + sin(clock * 8.0) * 4.0)
		elif mode != "squeeze" and mode != "swim":
			pose[3] = aim * 28.0 + Vector2(0, sway)
		if attack_phase >= 0.0:
			pose[3] = attack_tip
		for index: int in range(4):
			var endpoint: Vector2 = pose[index]
			var bend: Vector2 = endpoint * 0.5 + endpoint.orthogonal().normalized() * sin(clock * 3 + index) * 7.0
			var curve: PackedVector2Array = PackedVector2Array()
			for step: int in range(13):
				var t: float = float(step) / 12.0
				curve.append((1 - t) * (1 - t) * Vector2.ZERO + 2 * (1 - t) * t * bend + t * t * endpoint)
			draw_polyline(curve, outline, 12.0, true)
			draw_polyline(curve, body_color, 8.0, true)
			draw_circle(endpoint, 5.5, body_color)
			if index == 3 and attack_phase >= 0.0:
				var swelling: float = sin(attack_phase * PI)
				var radius: float = 7.0 + swelling * (14.0 if weapon == "heavy" else 9.0)
				draw_circle(endpoint, radius + 2.0, outline)
				draw_circle(endpoint, radius, Color("ffcc8e") if weapon == "heavy" else Color("ebffa7"))
				if weapon == "thorn":
					for thorn: int in range(7):
						var direction: Vector2 = Vector2.from_angle(float(thorn) * TAU / 7.0)
						draw_line(endpoint + direction * radius, endpoint + direction * (radius + 8), Color("f5edda"), 3, true)
		# Small junction is deliberately subordinate to the four equal limbs.
		draw_circle(Vector2.ZERO, 8.0, body_color)
		draw_circle(Vector2(-2, -2), 3.0, Color("edffe3"))
	if has_anchor:
		draw_arc(anchor, 10.0, clock, clock + TAU * 0.8, 20, Color("e4ffc5"), 1.5, true)
