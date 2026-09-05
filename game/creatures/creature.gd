class_name EECreature
extends CharacterBody2D
signal died(id: String)

var target: CharacterBody2D
var stable_id: String = ""
var kind: String = "grazer"
var home: Vector2
var health: float = 48.0
var _clock: float = 0.0
var _cooldown: float = 0.0
var _hurt: float = 0.0
var _direction: float = 1.0
var _dead: bool = false
var _spores: Array[Dictionary] = []

func configure(kind_value: String, home_value: Vector2, entity_id: String) -> void:
	kind = kind_value
	home = home_value
	position = home
	stable_id = entity_id
	health = 65.0 if kind == "spitter" else 48.0
	collision_layer = 4
	collision_mask = 1
	if kind in ["crawler", "spitter"]: add_to_group("damageable")
	var collider = CollisionShape2D.new()
	var shape = CapsuleShape2D.new()
	shape.radius = 13.0
	shape.height = 30.0
	collider.shape = shape
	add_child(collider)
	_clock = float(abs(entity_id.hash()) % 100) * 0.1

func _physics_process(delta: float) -> void:
	if _dead: return
	if is_instance_valid(target) and global_position.distance_squared_to(target.global_position) > 1400.0 * 1400.0:
		visible = false
		return
	visible = true
	_clock += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	_hurt = maxf(0.0, _hurt - delta)
	var hostile = kind in ["crawler", "spitter"]
	var to_target = Vector2(9999, 9999)
	if is_instance_valid(target): to_target = target.global_position - global_position
	if kind == "fish":
		position = home + Vector2(sin(_clock * 0.5) * 90.0, sin(_clock * 1.3) * 17.0)
		_direction = signf(cos(_clock * 0.5))
	else:
		velocity.y += 1050.0 * delta
		var desired = sin(_clock * 0.45) * 25.0
		if hostile and to_target.length() < 370.0:
			_direction = signf(to_target.x)
			desired = _direction * (75.0 if kind == "crawler" else 30.0)
			if kind == "spitter" and absf(to_target.x) < 220: desired = 0.0
		elif absf(position.x - home.x) > 95.0:
			desired = signf(home.x - position.x) * 25.0
		if absf(desired) > 1.0: _direction = signf(desired)
		# Probe the next footing; sparse wildlife never marches off a ledge.
		if is_on_floor():
			var probe = global_position + Vector2(_direction * 25, 0)
			var query = PhysicsRayQueryParameters2D.create(probe, probe + Vector2(0, 46), 1)
			if get_world_2d().direct_space_state.intersect_ray(query).is_empty(): desired = 0.0
		velocity.x = move_toward(velocity.x, desired, delta * (80.0 if _hurt > 0 else 300.0))
		move_and_slide()
		if hostile and to_target.length() < 33 and _cooldown <= 0 and target.has_method("take_damage"):
			target.take_damage(12.0, Vector2(_direction * 170, -100))
			_cooldown = 1.2
		if kind == "spitter" and to_target.length() < 340 and to_target.length() > 60 and _cooldown <= 0:
			_spores.append({"position":global_position,"velocity":to_target.normalized()*155.0,"life":2.7})
			_cooldown = 2.1
	_tick_spores(delta)
	queue_redraw()

func _tick_spores(delta: float) -> void:
	for i in range(_spores.size()-1,-1,-1):
		var spore: Dictionary = _spores[i]
		var next: Vector2 = spore.position + spore.velocity * delta
		var query = PhysicsRayQueryParameters2D.create(spore.position, next, 1)
		spore.life -= delta
		if not get_world_2d().direct_space_state.intersect_ray(query).is_empty(): spore.life = 0
		spore.position = next
		if is_instance_valid(target) and next.distance_to(target.global_position) < 20:
			if target.has_method("take_damage"): target.take_damage(9.0, spore.velocity * 0.4)
			spore.life = 0
		if spore.life <= 0: _spores.remove_at(i)

func take_damage(amount: float, impulse: Vector2) -> void:
	if _dead or kind not in ["crawler", "spitter"]: return
	health -= amount
	velocity += impulse
	_hurt = 0.2
	if health <= 0:
		_dead = true
		remove_from_group("damageable")
		died.emit(stable_id)
		queue_free()

func _draw() -> void:
	var ink = Color("233643")
	var color = Color("a9ca85")
	if kind == "crawler": color = Color("de8d70")
	if kind == "spitter": color = Color("af8dcc")
	if kind == "fish": color = Color("66d6cb")
	if _hurt > 0: color = Color("fff1cb")
	var bob = sin(_clock * 4.0) * 1.8
	if kind == "fish":
		draw_colored_polygon(PackedVector2Array([Vector2(-22*_direction,0),Vector2(-35*_direction,-12),Vector2(-31*_direction,11)]),Color("3c8d9c"))
		draw_set_transform(Vector2.ZERO,0,Vector2(1.5,0.65))
		draw_circle(Vector2.ZERO,14,ink)
		draw_circle(Vector2.ZERO,12,color)
		draw_set_transform(Vector2.ZERO)
		draw_line(Vector2(-9,-2),Vector2(7,-2),Color("c5ffe0"),3,true)
	else:
		for i in 4:
			var x = -16.0+i*10.0
			var swing = sin(_clock*7.0+i*PI)*3.0
			draw_polyline(PackedVector2Array([Vector2(x,3),Vector2(x+swing,12),Vector2(x+4+swing,15)]),ink,4,true)
		draw_set_transform(Vector2(0,bob),0,Vector2(1.4,0.8))
		draw_circle(Vector2.ZERO,16,ink)
		draw_circle(Vector2(0,-2),14,color)
		draw_set_transform(Vector2.ZERO)
		for i in 5:
			var x = -15.0+i*7.0
			if kind == "spitter":
				draw_line(Vector2(x,-8),Vector2(x,-23+sin(i)*5),ink,3,true)
				draw_circle(Vector2(x,-23+sin(i)*5),5,Color("ecbeef"))
			elif kind == "grazer":
				draw_colored_polygon(PackedVector2Array([Vector2(x,-9),Vector2(x-5,-24),Vector2(x+5,-17)]),Color("64a977"))
			else:
				draw_line(Vector2(x,-8),Vector2(x-3,-17),Color("f8d598"),4,true)
	draw_circle(Vector2(12*_direction,-3+bob),3,ink)
	draw_circle(Vector2(13*_direction,-4+bob),1,Color("fff9d6"))
	for spore in _spores:
		var p = to_local(spore.position)
		draw_circle(p,7,Color(0.7,0.4,0.8,0.25))
		draw_circle(p,4,Color("e4c581"))
