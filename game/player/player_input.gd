class_name EEPlayerInput
extends RefCounted

var move: Vector2 = Vector2.ZERO
var aim: Vector2 = Vector2.RIGHT
var jump_pressed: bool = false
var jump_released: bool = false
var grip: bool = false
var roll: bool = false
var squeeze: bool = false
var attack: bool = false
var using_controller: bool = false
var last_mouse: Vector2 = Vector2.ZERO

static func install_actions() -> void:
	key_action("move_left", KEY_A)
	key_action("move_right", KEY_D)
	key_action("move_up", KEY_W)
	key_action("move_down", KEY_S)
	key_action("jump", KEY_SPACE)
	key_action("roll", KEY_SHIFT)
	key_action("squeeze", KEY_CTRL)
	key_action("interact", KEY_E)
	key_action("pause", KEY_ESCAPE)
	key_action("cycle_weapon", KEY_Q)
	mouse_action("attack", MOUSE_BUTTON_LEFT)
	mouse_action("grip", MOUSE_BUTTON_RIGHT)
	joy_button("jump", JOY_BUTTON_A)
	joy_button("roll", JOY_BUTTON_RIGHT_SHOULDER)
	joy_button("squeeze", JOY_BUTTON_LEFT_SHOULDER)
	joy_button("interact", JOY_BUTTON_X)
	joy_button("pause", JOY_BUTTON_START)
	joy_button("cycle_weapon", JOY_BUTTON_Y)
	joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	joy_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	joy_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	joy_axis("aim_left", JOY_AXIS_RIGHT_X, -1.0)
	joy_axis("aim_right", JOY_AXIS_RIGHT_X, 1.0)
	joy_axis("aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	joy_axis("aim_down", JOY_AXIS_RIGHT_Y, 1.0)
	joy_axis("attack", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	joy_axis("grip", JOY_AXIS_TRIGGER_LEFT, 1.0)

static func ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.22)

static func key_action(action: String, key: Key) -> void:
	ensure_action(action)
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

static func mouse_action(action: String, button: MouseButton) -> void:
	ensure_action(action)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

static func joy_button(action: String, button: JoyButton) -> void:
	ensure_action(action)
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

static func joy_axis(action: String, axis: JoyAxis, value: float) -> void:
	ensure_action(action)
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

func sample(body: Node2D) -> void:
	move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var stick: Vector2 = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	var mouse: Vector2 = body.get_global_mouse_position()
	# Camera motion changes world coordinates without indicating mouse input.
	var screen_mouse: Vector2 = body.get_viewport().get_mouse_position()
	if stick.length() > 0.2:
		aim = stick.normalized()
		using_controller = true
	elif screen_mouse.distance_to(last_mouse) > 0.5:
		aim = body.global_position.direction_to(mouse)
		using_controller = false
	elif not using_controller:
		aim = body.global_position.direction_to(mouse)
	last_mouse = screen_mouse
	if aim.length_squared() < 0.1:
		aim = Vector2.RIGHT
	jump_pressed = Input.is_action_just_pressed("jump")
	jump_released = Input.is_action_just_released("jump")
	grip = Input.is_action_pressed("grip")
	roll = Input.is_action_pressed("roll")
	squeeze = Input.is_action_pressed("squeeze")
	attack = Input.is_action_pressed("attack")
