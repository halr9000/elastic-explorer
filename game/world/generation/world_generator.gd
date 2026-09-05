extends RefCounted
const VERSION := 1
const MODULE_WIDTH := 1200.0
const MODULE_COUNT := 20

func generate(seed_value: int, decoration_variant: int = 0) -> Dictionary:
	var terrain_rng := RandomNumberGenerator.new()
	terrain_rng.seed = seed_value
	var population_rng := RandomNumberGenerator.new()
	population_rng.seed = seed_value ^ 0x73A28F
	var result := {"version": VERSION, "seed": seed_value, "decoration_seed": seed_value ^ 0x19BCD ^ decoration_variant, "terrain": [], "route": [], "waters": [], "landmarks": [], "creatures": [], "branches": [], "rejections": []}
	var floor_y := 400.0
	for index in range(MODULE_COUNT):
		var x := index * MODULE_WIDTH
		var region := "surface" if index < 7 else ("cave" if index < 13 else "aquatic")
		var next_y := floor_y + terrain_rng.randf_range(-90.0, 90.0)
		if index >= 5 and index < 12:
			next_y = floor_y + terrain_rng.randf_range(40.0, 110.0)
		if index > 15:
			next_y = floor_y - terrain_rng.randf_range(20.0, 75.0)
		var is_pool := index in [13, 15, 17]
		var top: Array = [[x, floor_y], [x + 280.0, floor_y]]
		if is_pool:
			top.append([x + 420.0, floor_y + 170.0])
			top.append([x + 760.0, floor_y + 170.0])
			top.append([x + 940.0, next_y])
			result.waters.append([x + 286.0, minf(floor_y, next_y) - 18.0, 650.0, 220.0])
		else:
			top.append([x + 600.0, (floor_y + next_y) * 0.5 + terrain_rng.randf_range(-35.0, 35.0)])
			top.append([x + 940.0, next_y])
		top.append([x + MODULE_WIDTH, next_y])
		var shape: Array = top.duplicate(true)
		shape.append([x + MODULE_WIDTH, 2100.0])
		shape.append([x, 2100.0])
		result.terrain.append({"top": top, "polygon": shape, "region": region, "index": index})
		result.route.append({"x0": x, "x1": x + MODULE_WIDTH, "clearance": 360.0, "slope": 0.35 if not is_pool else 0.0, "cost": _swim_cost(650.0) if is_pool else 0.0, "rest": true, "mode": "swim" if is_pool else "walk"})
		if index % 2 == 0:
			_add_landmark(result, "checkpoint", "beacon_%02d" % index, Vector2(x + 120.0, floor_y - 30.0), "Hearth %02d" % (index / 2 + 1))
		if index in [1, 3, 5, 8, 11, 14, 16, 18]:
			var kind := "grazer" if index < 6 else ("crawler" if index % 2 == 0 else "spitter")
			result.creatures.append({"id": "fauna_%02d" % index, "kind": kind, "position": [x + 1000.0, next_y - 35.0]})
		if is_pool:
			result.creatures.append({"id": "fish_%02d" % index, "kind": "fish", "position": [x + population_rng.randf_range(460.0, 680.0), floor_y + 90.0]})
		if index in [4, 10, 16]:
			_add_landmark(result, "health", "fruit_%02d" % index, Vector2(x + 1000.0, next_y - 35.0), "Sunfruit")
		if index == 2:
			_add_landmark(result, "heavy", "heavy_tip", Vector2(x + 1060.0, next_y - 32.0), "Basalt heart · heavy tip")
		if index == 9:
			_add_landmark(result, "thorn", "thorn_tip", Vector2(x + 1060.0, next_y - 32.0), "Briar heart · thorn lash")
		floor_y = next_y
	# Artifact branches are inserted only after the continuous route exists.
	var climb_floor := _floor_at(result, 6700.0)
	_add_block(result, Rect2(6540.0, climb_floor - 170.0, 220.0, 170.0), "surface")
	_add_landmark(result, "artifact", "resonator_canopy", Vector2(6650.0, climb_floor - 203.0), "I · The Canopy Bell")
	result.branches.append({"mode": "climb", "distance": 170.0, "clearance": 100.0, "rest": true, "cost": _climb_cost(170.0)})
	# Fully submerged but shallow enough to return to the open surface in one breath.
	var water: Array = result.waters[1]
	_add_landmark(result, "artifact", "resonator_tide", Vector2(float(water[0]) + 320.0, _floor_at(result, float(water[0]) + 320.0) - 32.0), "II · The Drowned Choir")
	result.branches.append({"mode": "swim", "distance": 400.0, "clearance": 100.0, "rest": true, "cost": _swim_cost(400.0)})
	# A low lintel forms a real 24px tunnel. Standing cannot enter; squeeze can.
	var tunnel_floor := _floor_at(result, 22900.0)
	_add_block(result, Rect2(22800.0, tunnel_floor - 140.0, 300.0, 116.0), "aquatic")
	_add_landmark(result, "artifact", "resonator_root", Vector2(22940.0, tunnel_floor - 10.0), "III · The Root Memory")
	result.branches.append({"mode": "squeeze", "distance": 300.0, "clearance": 24.0, "rest": true, "cost": 0.0})
	return result

func _add_landmark(output: Dictionary, kind: String, id: String, point: Vector2, label: String) -> void:
	output.landmarks.append({"id": id, "kind": kind, "position": [point.x, point.y], "label": label})

func _add_block(output: Dictionary, rectangle: Rect2, region: String) -> void:
	var x := rectangle.position.x
	var y := rectangle.position.y
	var w := rectangle.size.x
	var h := rectangle.size.y
	output.terrain.append({"top": [[x, y], [x + w, y]], "polygon": [[x, y], [x + w, y], [x + w, y + h], [x, y + h]], "region": region, "index": output.terrain.size(), "branch": true})

func _floor_at(output: Dictionary, x: float) -> float:
	for module in output.terrain:
		if module.has("branch"):
			continue
		var top: Array = module.top
		for i in range(top.size() - 1):
			if x >= float(top[i][0]) and x <= float(top[i + 1][0]):
				var ratio := inverse_lerp(float(top[i][0]), float(top[i + 1][0]), x)
				return lerpf(float(top[i][1]), float(top[i + 1][1]), ratio)
	return 400.0

func _swim_cost(distance: float) -> float:
	var config = load("res://game/player/movement_config.gd").new()
	return distance / config.swim_speed * config.swim_drain

func _climb_cost(distance: float) -> float:
	var config = load("res://game/player/movement_config.gd").new()
	return distance / config.climb_speed * config.climb_drain

func playground() -> Dictionary:
	var output := {"version": VERSION, "seed": 42, "decoration_seed": 927, "width": 4800.0, "terrain": [], "route": [], "waters": [[1520.0, 380.0, 600.0, 230.0]], "landmarks": [], "creatures": [], "branches": [], "rejections": []}
	var tops: Array = [
		[[0.0,400.0],[300.0,400.0],[650.0,300.0],[900.0,400.0],[1200.0,400.0]],
		[[1200.0,400.0],[1500.0,400.0],[1680.0,600.0],[1970.0,600.0],[2130.0,400.0],[2400.0,400.0]],
		[[2400.0,400.0],[2700.0,400.0],[3100.0,400.0],[3400.0,400.0],[3600.0,400.0]],
		[[3600.0,400.0],[4000.0,400.0],[4400.0,350.0],[4800.0,350.0]]]
	for i in range(tops.size()):
		var polygon: Array = tops[i].duplicate(true)
		polygon.append([float(tops[i][-1][0]), 2100.0])
		polygon.append([float(tops[i][0][0]), 2100.0])
		output.terrain.append({"top": tops[i], "polygon": polygon, "region": "surface" if i < 2 else "cave", "index": i})
	_add_block(output, Rect2(2620.0, 270.0, 260.0, 106.0), "cave")
	_add_block(output, Rect2(3320.0, 230.0, 210.0, 170.0), "cave")
	_add_landmark(output, "checkpoint", "play_start", Vector2(120,370), "Movement garden")
	_add_landmark(output, "checkpoint", "play_pool", Vector2(1320,370), "Swim and surface")
	_add_landmark(output, "checkpoint", "play_climb", Vector2(3120,370), "Grip the wall")
	return output
