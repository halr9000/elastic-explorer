class_name EEGripSolver
extends RefCounted

var anchored: bool = false
var anchor: Vector2 = Vector2.ZERO
var normal: Vector2 = Vector2.ZERO

func find_grip(body: CharacterBody2D, aim: Vector2, reach: float) -> bool:
	# First honor aim; a small fan makes rough terrain forgiving without distant grabs.
	for angle: float in [0.0, -0.22, 0.22, -0.48, 0.48]:
		var direction: Vector2 = aim.rotated(angle)
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			body.global_position, body.global_position + direction * reach, 1, [body.get_rid()])
		var hit: Dictionary = body.get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			anchor = hit["position"]
			normal = hit["normal"]
			anchored = true
			return true
	return false

func release() -> void:
	anchored = false
