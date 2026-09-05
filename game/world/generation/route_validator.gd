extends RefCounted
## Structural validation precedes traversal validation, including for untrusted saves.

func validate(layout: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	if layout.get("version") != 1 or not _number(layout.get("seed")) or not _number(layout.get("decoration_seed")):
		return ["Unsupported or missing generation identity"]
	for key in ["terrain", "route", "waters", "landmarks", "creatures", "branches"]:
		if not layout.get(key) is Array:
			return ["Missing or malformed layout array: " + key]
	if layout.terrain.is_empty() or layout.route.is_empty():
		return ["Empty terrain or route"]
	for module in layout.terrain:
		if not module is Dictionary or not module.get("top") is Array or not module.get("polygon") is Array:
			return ["Malformed terrain module"]
		if module.top.size() < 2 or module.polygon.size() < 3 or not _number(module.get("index")) or module.get("region") not in ["surface", "cave", "aquatic"]:
			return ["Malformed terrain module fields"]
		for point in module.top + module.polygon:
			if not _point(point):
				return ["Malformed terrain coordinate"]
	for water in layout.waters:
		if not water is Array or water.size() != 4:
			return ["Malformed water volume"]
		for coordinate in water:
			if not _number(coordinate):
				return ["Malformed water coordinate"]
		if float(water[2]) <= 0 or float(water[3]) <= 0:
			return ["Invalid water dimensions"]
	for entity in layout.landmarks + layout.creatures:
		if not entity is Dictionary or not _point(entity.get("position")) or not entity.get("id") is String or not entity.get("kind") is String:
			return ["Malformed entity socket"]
	var config = load("res://game/player/movement_config.gd").new()
	var budget: float = config.endurance_max * 0.65
	var endurance := 0.0
	var previous_end := 0.0
	for edge in layout.route:
		if not edge is Dictionary:
			return ["Malformed route edge"]
		for key in ["x0", "x1", "clearance", "slope", "cost"]:
			if not _number(edge.get(key)):
				return ["Malformed route requirement"]
		if not edge.get("rest") is bool:
			return ["Missing route rest location"]
		if absf(float(edge.x0) - previous_end) > 0.1 or float(edge.x1) <= float(edge.x0):
			failures.append("Disconnected route")
		previous_end = float(edge.x1)
		if float(edge.clearance) < config.upright_height + 16.0:
			failures.append("Upright clearance below conservative bounds")
		if float(edge.slope) > 0.45:
			failures.append("Slope exceeds conservative walking limit")
		endurance += float(edge.cost)
		if endurance > budget or float(edge.cost) < 0.0:
			failures.append("Successive exertion exceeds safe endurance")
		if bool(edge.rest):
			endurance = 0.0
	if previous_end < 20000.0:
		failures.append("Incomplete finite route")
	for branch in layout.branches:
		if not branch is Dictionary or not _number(branch.get("distance")) or not _number(branch.get("clearance")) or not _number(branch.get("cost")):
			return ["Malformed artifact branch"]
		if float(branch.cost) > budget:
			failures.append("Branch exceeds safe endurance")
		if branch.get("mode") == "climb" and float(branch.distance) / config.climb_speed * config.climb_drain > budget:
			failures.append("Climb exceeds controller capabilities")
		if branch.get("mode") == "swim" and float(branch.distance) / config.swim_speed * config.swim_drain > budget:
			failures.append("Swim exceeds controller capabilities")
		if branch.get("mode") == "squeeze" and float(branch.clearance) < config.squeeze_height + 6.0:
			failures.append("Tunnel is too narrow")
	# Check the physical floor chain, not just its abstract route edge labels.
	var floor_end := Vector2.ZERO
	var floor_started := false
	for module in layout.terrain:
		if module.get("branch", false):
			continue
		var first := Vector2(float(module.top[0][0]), float(module.top[0][1]))
		if floor_started and floor_end.distance_to(first) > 0.01:
			failures.append("Physical terrain seam is disconnected")
		if not floor_started and absf(first.x) > 0.01:
			failures.append("Spawn terrain is missing")
		floor_started = true
		floor_end = Vector2(float(module.top[-1][0]), float(module.top[-1][1]))
		for i in range(module.top.size() - 1):
			var a := Vector2(float(module.top[i][0]), float(module.top[i][1]))
			var b := Vector2(float(module.top[i + 1][0]), float(module.top[i + 1][1]))
			if b.x <= a.x:
				failures.append("Floor doubles back")
				continue
			if absf(b.y - a.y) / (b.x - a.x) > 0.45:
				var midpoint := a.lerp(b, 0.5) - Vector2(0, 20)
				var swimmable := false
				for water in layout.waters:
					if Rect2(float(water[0]), float(water[1]), float(water[2]), float(water[3])).has_point(midpoint):
						swimmable = true
				if not swimmable:
					failures.append("Steep route slope has no water support")
	var artifact_count := 0
	var checkpoint_count := 0
	for landmark in layout.landmarks:
		if landmark.kind == "artifact":
			artifact_count += 1
		if landmark.kind == "checkpoint":
			checkpoint_count += 1
			for water in layout.waters:
				if Rect2(float(water[0]), float(water[1]), float(water[2]), float(water[3])).has_point(Vector2(float(landmark.position[0]), float(landmark.position[1]))):
					failures.append("Checkpoint underwater")
	if artifact_count != 3 or checkpoint_count < 2:
		failures.append("Missing expedition landmarks")
	return failures

func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func _point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _number(value[0]) and _number(value[1])
