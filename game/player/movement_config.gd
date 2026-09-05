class_name EEMovementConfig
extends Resource

@export var walk_speed: float = 235.0
@export var jump_speed: float = 450.0
@export var gravity: float = 1100.0
@export var grip_reach: float = 125.0
@export var climb_speed: float = 115.0
@export var swim_speed: float = 150.0
@export var climb_drain: float = 18.0
@export var swim_drain: float = 7.0
@export var endurance_max: float = 100.0
@export var recovery: float = 30.0
@export var capsule_radius: float = 12.0
@export var upright_height: float = 44.0
@export var squeeze_height: float = 14.0

func max_jump_height() -> float:
	return jump_speed * jump_speed / (2.0 * gravity)

func max_jump_distance() -> float:
	return walk_speed * jump_speed * 2.0 / gravity

func max_climb_height() -> float:
	return climb_speed * endurance_max / climb_drain

func max_swim_distance() -> float:
	return swim_speed * endurance_max / swim_drain
