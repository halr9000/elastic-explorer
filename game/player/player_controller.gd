class_name EEPlayer
extends CharacterBody2D

signal jumped
signal damaged
signal died

var config: EEMovementConfig = EEMovementConfig.new()
var vitals: EEVitals = EEVitals.new()
var controls: EEPlayerInput = EEPlayerInput.new()
var grip_solver: EEGripSolver = EEGripSolver.new()
var rig: EELimbRig
var collider: CollisionShape2D
var camera: Camera2D
var attack_controller: Node2D
var water_query: Callable
var mode: String = "walk"
var water: Rect2 = Rect2()
var coyote: float = 0.0
var jump_buffer: float = 0.0
var burst_time: float = 0.0
var grip_cooldown: float = 0.0
var shape_mode: String = "walk"
var input_enabled: bool = true
var shake_amount: float = 0.0
var camera_shake_enabled: bool = true
var screen_time: float = 0.0
var upright_shape: CapsuleShape2D
var roll_shape: CircleShape2D
var squeeze_shape: RectangleShape2D

func _ready() -> void:
	EEPlayerInput.install_actions()
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 12.0
	floor_max_angle = deg_to_rad(52)
	wall_min_slide_angle = 0.0
	vitals.config = config
	vitals.died.connect(func() -> void: died.emit())
	vitals.hurt.connect(func() -> void: damaged.emit())
	upright_shape = CapsuleShape2D.new()
	upright_shape.radius = config.capsule_radius
	upright_shape.height = config.upright_height
	roll_shape = CircleShape2D.new()
	roll_shape.radius = 15.0
	squeeze_shape = RectangleShape2D.new()
	squeeze_shape.size = Vector2(40, config.squeeze_height)
	collider = CollisionShape2D.new()
	collider.shape = upright_shape
	add_child(collider)
	rig = EELimbRig.new()
	add_child(rig)
	camera = Camera2D.new()
	camera.position = Vector2(0, -65)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.zoom = Vector2(1.25, 1.25)
	add_child(camera)
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(0.63, 1.0, 0.78, 0.8))
	gradient.set_color(1, Color(0.3, 0.8, 0.7, 0.0))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0)
	var light: PointLight2D = PointLight2D.new()
	light.texture = texture
	light.energy = 0.65
	light.texture_scale = 1.6
	light.shadow_enabled = true
	add_child(light)

func _physics_process(delta: float) -> void:
	if not input_enabled or vitals.health <= 0.0:
		return
	controls.sample(self)
	step_motion(delta)

func step_motion(delta: float) -> void:
	screen_time += delta
	grip_cooldown = maxf(0, grip_cooldown - delta)
	coyote = 0.12 if is_on_floor() else maxf(0, coyote - delta)
	jump_buffer = 0.14 if controls.jump_pressed else maxf(0, jump_buffer - delta)
	burst_time = maxf(0, burst_time - delta)
	water = water_query.call(global_position) if water_query.is_valid() else Rect2()
	var swimming: bool = water.has_area() and global_position.y > water.position.y + 3.0
	var resting_surface: bool = swimming and global_position.y < water.position.y + 22.0 and controls.move.length() < 0.15
	var submerged: bool = swimming and global_position.y > water.position.y + 23.0
	if not controls.grip or grip_cooldown > 0.0:
		grip_solver.release()
	elif vitals.endurance > 0.0:
		if not grip_solver.anchored or global_position.distance_to(grip_solver.anchor) > config.grip_reach * 0.83:
			grip_solver.find_grip(self, controls.aim, config.grip_reach)
	if grip_solver.anchored and global_position.distance_to(grip_solver.anchor) > config.grip_reach + 15.0:
		grip_solver.release()
	if grip_solver.anchored and vitals.endurance <= 0.0 and vitals.exhaustion_time > 0.45:
		grip_solver.release()
		grip_cooldown = 0.65
	var wanted_shape: String = "squeeze" if controls.squeeze else ("roll" if controls.roll and not swimming else "walk")
	change_shape(wanted_shape)
	if grip_solver.anchored:
		mode = "climb"
		var toward: Vector2 = global_position.direction_to(grip_solver.anchor)
		velocity = controls.move * config.climb_speed
		if controls.move.length() < 0.1 and global_position.distance_to(grip_solver.anchor) > 45.0:
			velocity = toward * config.climb_speed * 0.7
		# Re-anchor toward climbing movement to climb a continuous wall beyond one reach.
		if controls.move.length() > 0.1:
			grip_solver.find_grip(self, (controls.aim + controls.move * 0.6).normalized(), config.grip_reach)
		if jump_buffer > 0.0:
			velocity = Vector2(controls.move.x * config.walk_speed, -config.jump_speed * 0.9)
			if is_on_wall():
				velocity.x += grip_solver.normal.x * 160.0
			grip_solver.release()
			grip_cooldown = 0.22
			jump_buffer = 0.0
			jumped.emit()
	elif swimming:
		mode = "swim"
		if controls.jump_pressed and vitals.spend(16.0):
			burst_time = 0.32
			jumped.emit()
		var desired: Vector2 = controls.move * config.swim_speed * (1.8 if burst_time > 0.0 else 1.0)
		if controls.move.length() < 0.1:
			desired.y = -35.0 if vitals.endurance > 0.0 else 85.0
		if vitals.endurance <= 0.0:
			desired.x *= 0.5
			desired.y = maxf(desired.y, 85.0)
		velocity = velocity.move_toward(desired, 700.0 * delta)
		if controls.move.y < -0.1 and global_position.y < water.position.y + 20.0 and vitals.endurance > 0.0:
			velocity.y = -config.jump_speed * 0.8
	else:
		mode = shape_mode
		var top_speed: float = config.walk_speed
		var acceleration: float = 1800.0 if is_on_floor() else 1000.0
		if mode == "squeeze":
			top_speed *= 0.48
		elif mode == "roll":
			top_speed *= 1.85
			acceleration = 430.0
			if is_on_floor():
				velocity.x += get_floor_normal().x * 850.0 * delta
		velocity.x = move_toward(velocity.x, controls.move.x * top_speed, acceleration * delta)
		velocity.y = minf(velocity.y + config.gravity * delta, 800.0)
		if jump_buffer > 0.0 and coyote > 0.0:
			velocity.y = -config.jump_speed * (0.65 if mode == "squeeze" else 1.0)
			jump_buffer = 0.0
			coyote = 0.0
			jumped.emit()
		if controls.jump_released and velocity.y < -160.0:
			velocity.y *= 0.48
	var before_y: float = velocity.y
	move_and_slide()
	if is_on_floor() and before_y > 720.0 and not swimming:
		take_damage(12, Vector2.ZERO)
	var resting: bool = (is_on_floor() and not submerged and mode != "climb") or resting_surface
	vitals.tick(delta, mode, resting, submerged)
	if attack_controller != null:
		attack_controller.call("tick", delta, controls.aim, controls.attack, grip_solver.anchored)
		var phase_value: Variant = attack_controller.get("phase")
		rig.attack_phase = float(phase_value)
		rig.attack_tip = attack_controller.get("tip")
		rig.weapon = str(attack_controller.get("weapon"))
	rig.mode = mode
	rig.motion = velocity
	rig.aim = controls.aim
	rig.has_anchor = grip_solver.anchored
	rig.anchor = to_local(grip_solver.anchor)
	rig.endurance = vitals.endurance
	rig.hurt_time = vitals.invulnerability
	camera.position = camera.position.lerp(Vector2(controls.aim.x * 65, -65 + controls.aim.y * 30), delta * 2.0)
	shake_amount = move_toward(shake_amount, 0, delta * 20)
	camera.offset = Vector2(sin(screen_time * 93), cos(screen_time * 107)) * shake_amount if camera_shake_enabled else Vector2.ZERO

func change_shape(wanted: String) -> bool:
	if wanted == shape_mode:
		return true
	var next: Shape2D = upright_shape
	var old_height: float = 44.0 if shape_mode == "walk" else (30.0 if shape_mode == "roll" else 14.0)
	var next_height: float = 44.0
	if wanted == "squeeze":
		next = squeeze_shape
		next_height = 14.0
	elif wanted == "roll":
		next = roll_shape
		next_height = 30.0
	var shift: Vector2 = Vector2(0, (old_height - next_height) * 0.5) if is_on_floor() else Vector2.ZERO
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = next
	query.transform = Transform2D(0, global_position + shift + Vector2(0, -0.1))
	query.collision_mask = 1
	query.exclude = [get_rid()]
	query.margin = 0.0
	if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	global_position += shift
	collider.shape = next
	shape_mode = wanted
	return true

func take_damage(amount: float, impulse: Vector2) -> void:
	if vitals.damage(amount):
		velocity += impulse
		shake_amount = 6.0

func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	vitals.restore()
	vitals.invulnerability = 2.0
	grip_solver.release()
	grip_cooldown = 0.0
	shape_mode = "walk"
	collider.shape = upright_shape
	mode = "walk"
	camera.reset_smoothing()
