class_name EEAttackController
extends Node2D
signal hit_landed
signal attack_started

var weapon: String = "club"
var phase: float = -1.0
var tip: Vector2 = Vector2.ZERO
var body: CharacterBody2D
var _aim: Vector2 = Vector2.RIGHT
var _hit_ids: Dictionary = {}
var _cooldown: float = 0.0
var _gripping: bool = false
var _swing_weapon: String = "club"
const WEAPONS = {"club":{"reach":90.0,"damage":24.0,"duration":0.38},"heavy":{"reach":78.0,"damage":45.0,"duration":0.58},"thorn":{"reach":124.0,"damage":18.0,"duration":0.31}}

func setup(value: CharacterBody2D) -> void:
	body = value

func tick(delta: float, aim: Vector2, requested: bool, gripping: bool) -> void:
	if not is_instance_valid(body): return
	_cooldown = maxf(0.0, _cooldown - delta)
	_gripping = gripping
	var data: Dictionary = WEAPONS.get(_swing_weapon, WEAPONS.club)
	if requested and phase < 0.0 and _cooldown <= 0.0:
		_aim = aim.normalized() if aim.length_squared() > 0.01 else _aim
		phase = 0.0
		_swing_weapon = weapon
		data = WEAPONS.get(_swing_weapon, WEAPONS.club)
		_hit_ids.clear()
		attack_started.emit()
	if phase >= 0.0:
		phase += delta / float(data.duration)
		var extension = sin(clampf((phase - 0.15) / 0.7, 0.0, 1.0) * PI)
		tip = _aim.rotated(lerpf(-0.85, 0.85, clampf(phase, 0.0, 1.0))) * float(data.reach) * maxf(0.2, extension)
		if phase >= 0.23 and phase <= 0.78: _resolve_hits(data)
		if phase >= 1.0:
			phase = -1.0
			_cooldown = 0.12
	queue_redraw()

func _resolve_hits(data: Dictionary) -> void:
	for enemy in get_tree().get_nodes_in_group("damageable"):
		if not is_instance_valid(enemy) or not enemy is Node2D or not enemy.has_method("take_damage"): continue
		if _hit_ids.has(enemy.get_instance_id()): continue
		var offset: Vector2 = enemy.global_position - body.global_position
		if offset.length() > float(data.reach) + 14.0 or offset.normalized().dot(_aim) < 0.5: continue
		var query = PhysicsRayQueryParameters2D.create(body.global_position, enemy.global_position, 1)
		query.exclude = [body.get_rid()]
		if not body.get_world_2d().direct_space_state.intersect_ray(query).is_empty(): continue
		_hit_ids[enemy.get_instance_id()] = true
		enemy.take_damage(float(data.damage), _aim * (280.0 if _swing_weapon == "heavy" else 175.0) + Vector2.UP * 70.0)
		hit_landed.emit()

func _draw() -> void:
	if phase < 0.0: return
	var start = Vector2(0, 7 if _gripping else -3)
	var elbow = tip * 0.5 + _aim.orthogonal() * sin(phase * PI) * 15.0
	draw_polyline(PackedVector2Array([start, elbow, tip]), Color("422e55"), 12.0, true)
	draw_polyline(PackedVector2Array([start, elbow, tip]), Color("ecac80"), 7.0, true)
	var radius = 13.0 if _swing_weapon == "heavy" else 9.0
	draw_circle(tip, radius, Color("73506c"))
	draw_circle(tip + Vector2(-2,-3), radius * 0.63, Color("f6c99b"))
	if _swing_weapon == "thorn":
		for i in 5:
			var axis = Vector2.from_angle(i * TAU / 5.0 + phase * 4.0)
			draw_colored_polygon(PackedVector2Array([tip + axis.rotated(-0.4)*7,tip+axis*19,tip+axis.rotated(0.4)*7]),Color("f5f1c6"))
