class_name EEGame
extends Node2D

var world: EEWorld
var player: EEPlayer
var ui: EEGameUI
var audio: EEAudio
var markers: Array[EELandmark] = []
var save_service: EESaveService = EESaveService.new()
var seed_value: int = 473821
var checkpoint: Vector2 = Vector2.ZERO
var collected: Array[String] = []
var defeated: Array[String] = []
var discoveries: Array[String] = []
var upgrades: Array[String] = ["club"]
var completed: bool = false
var playing: bool = false
var playground: bool = false
var test_mode: bool = false
var elapsed: float = 0.0
var frame_count: int = 0
var nearest: EELandmark
var recovery_data: Dictionary = {}
var hit_stop_until: int = 0
var screenshot_path: String = ""
var capture_x: float = -1.0
var quit_after_capture: bool = false
var capture_started: bool = false
var process_samples: Array[float] = []
var last_frame_usec: int = 0
var autosave_elapsed: float = 0.0
var last_region: String = ""
var demo_mode: bool = false
var restore_generation: int = 0
var quitting: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EEPlayerInput.install_actions()
	get_tree().auto_accept_quit = false
	audio = EEAudio.new()
	add_child(audio)
	var atmosphere: CanvasLayer = CanvasLayer.new()
	atmosphere.layer = 2
	add_child(atmosphere)
	var grade: ColorRect = ColorRect.new()
	grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://game/environment/atmosphere.gdshader") as Shader
	grade.material = material
	atmosphere.add_child(grade)
	ui = EEGameUI.new()
	add_child(ui)
	ui.new_world_requested.connect(_new_world)
	ui.continue_requested.connect(_continue_world)
	ui.resume_requested.connect(func() -> void: set_paused(false))
	ui.title_requested.connect(_save_to_title)
	ui.quit_requested.connect(_quit)
	ui.playground_requested.connect(func() -> void: start_expedition(42, {}, true))
	ui.recover_requested.connect(_recover)
	ui.settings_changed.connect(_settings_changed)
	_load_settings()
	_build_world(seed_value, {}, false)
	position_for_capture(620)
	player.camera.position_smoothing_enabled = false
	player.camera.zoom = Vector2.ONE
	player.input_enabled = false
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.update_view(player.global_position, 4.0)
	ui.show_title(save_service.exists())
	if test_mode:
		return
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for argument: String in args:
		if argument.begins_with("--capture="):
			screenshot_path = argument.trim_prefix("--capture=")
		elif argument.begins_with("--capture-x="):
			capture_x = argument.trim_prefix("--capture-x=").to_float()
	demo_mode = "--demo" in args
	quit_after_capture = "--smoke" in args
	if "--autostart" in args or demo_mode:
		# Automated captures never write to a real expedition save.
		save_service = EESaveService.new("user://capture_sandbox")
		start_expedition(seed_value)
		if capture_x >= 0.0:
			position_for_capture(capture_x)

func _build_world(world_seed: int, layout: Dictionary, is_playground: bool) -> void:
	if is_instance_valid(world):
		world.process_mode = Node.PROCESS_MODE_DISABLED
		remove_child(world)
		world.queue_free()
	markers.clear()
	nearest = null
	world = EEWorld.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	if is_playground:
		world.build_playground()
	else:
		world.build(world_seed, layout)
	player = EEPlayer.new()
	player.position = world.spawn_point
	player.water_query = world.water_at
	world.add_child(player)
	player.camera.limit_left = 0
	player.camera.limit_right = int(world.bounds.end.x)
	player.camera.limit_bottom = int(world.bounds.end.y)
	var attack: EEAttackController = EEAttackController.new()
	player.add_child(attack)
	attack.setup(player)
	attack.visible = false
	player.attack_controller = attack
	attack.hit_landed.connect(_impact)
	player.jumped.connect(audio.play_jump)
	player.died.connect(_on_death)
	for data: Dictionary in world.landmarks:
		var marker: EELandmark = EELandmark.new()
		marker.configure(data)
		marker.activated = marker.stable_id in collected
		world.add_child(marker)
		markers.append(marker)
	for data: Dictionary in world.creature_spawns:
		if str(data.id) in defeated:
			continue
		var creature: EECreature = EECreature.new()
		creature.configure(str(data.kind), data.position, str(data.id))
		creature.target = player
		creature.died.connect(_creature_died)
		world.add_child(creature)
	world.reduced_effects = ui.reduced
	player.camera_shake_enabled = ui.shake

func start_expedition(new_seed: int, saved: Dictionary = {}, is_playground: bool = false) -> void:
	restore_generation += 1
	get_tree().paused = false
	Engine.time_scale = 1.0
	hit_stop_until = 0
	seed_value = new_seed
	playground = is_playground
	collected = _strings(saved.get("collected", []))
	defeated = _strings(saved.get("defeated", []))
	discoveries = _strings(saved.get("discoveries", []))
	upgrades = ["club"]
	if "heavy_tip" in collected:
		upgrades.append("heavy")
	if "thorn_tip" in collected:
		upgrades.append("thorn")
	completed = bool(saved.get("completed", false))
	elapsed = float(saved.get("elapsed", 0.0))
	autosave_elapsed = 0.0
	_build_world(new_seed, saved.get("layout", {}), is_playground)
	checkpoint = world.spawn_point
	if saved.has("checkpoint"):
		var candidate: Vector2 = _vector(saved.checkpoint, checkpoint)
		for known: Vector2 in world.checkpoints:
			if candidate.distance_to(known) < 1.0:
				checkpoint = known
				break
	player.respawn(checkpoint)
	if not saved.is_empty():
		var stats: Dictionary = saved.get("player", {})
		_restore_placement(stats, restore_generation)
		player.vitals.health = maxf(1.0, float(stats.get("health", 100)))
		player.vitals.endurance = clampf(float(stats.get("endurance", 100)), 0, 100)
		player.attack_controller.set("weapon", str(stats.get("weapon", "club")))
	playing = true
	ui.show_play()
	world.update_view(player.global_position, elapsed)
	if is_playground:
		ui.toast("Movement clearing · slopes → pool → squeeze tunnel → climbing wall", 7)
	elif saved.is_empty():
		ui.toast("Three old voices sleep beneath the roots. Wake them, then return to this hearth.", 7)
	else:
		ui.toast("The world remembers you.")

func _new_world() -> void:
	if save_service.exists():
		var archive_error: Error = _archive_current_world()
		if archive_error != OK:
			ui.toast("Could not archive the existing world. It has been preserved.", 8)
			return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	start_expedition(rng.randi_range(1, 99999999))
	save_progress()

func _archive_current_world() -> Error:
	var stamp: String = ".archived." + str(int(Time.get_unix_time_from_system())) + "." + str(Time.get_ticks_usec())
	# Copy both originals first. Failure leaves the old playable save untouched.
	for suffix: String in [".json", ".bak"]:
		var source: String = save_service.base_path + suffix
		if FileAccess.file_exists(source):
			var error: Error = DirAccess.copy_absolute(source, save_service.base_path + stamp + suffix)
			if error != OK:
				return error
	for suffix: String in [".json", ".bak"]:
		var source: String = save_service.base_path + suffix
		if FileAccess.file_exists(source):
			var error: Error = DirAccess.remove_absolute(source)
			if error != OK:
				return error
	return OK

func _continue_world() -> void:
	var state: Dictionary = save_service.load_game()
	if state.is_empty():
		ui.toast(save_service.last_error, 8)
		return
	if save_service.recovered_backup:
		recovery_data = state
		ui.show_recovery(save_service.last_error)
		return
	start_expedition(int(state.seed), state)

func _recover() -> void:
	if recovery_data.is_empty():
		return
	if FileAccess.file_exists(save_service.base_path + ".json"):
		var error: Error = save_service.archive_invalid_primary()
		if error != OK:
			ui.toast(save_service.last_error, 8)
			return
	start_expedition(int(recovery_data.seed), recovery_data)
	save_progress()
	ui.toast("Backup restored. The damaged original has been preserved.", 6)
	recovery_data.clear()

func snapshot() -> Dictionary:
	return {"version": 1, "seed": seed_value, "layout": world.layout,
		"checkpoint": [checkpoint.x, checkpoint.y],
		"player": {"health": player.vitals.health, "endurance": player.vitals.endurance,
			"shape_mode": player.shape_mode,
			"weapon": str(player.attack_controller.get("weapon")), "position": [player.global_position.x, player.global_position.y]},
		"collected": collected.duplicate(), "defeated": defeated.duplicate(),
		"discoveries": discoveries.duplicate(), "completed": completed, "elapsed": elapsed}

func save_progress() -> bool:
	if playground or test_mode or demo_mode or not screenshot_path.is_empty():
		return true
	var error: Error = save_service.save_game(snapshot())
	if error != OK:
		ui.toast("Save failed: " + save_service.last_error, 8)
		return false
	autosave_elapsed = 0.0
	return true

func set_paused(value: bool) -> void:
	if not playing:
		return
	get_tree().paused = value
	Engine.time_scale = 1.0
	hit_stop_until = 0
	if value:
		ui.show_pause()
	else:
		ui.show_play()

func _save_to_title() -> void:
	if not save_progress():
		return
	playing = false
	get_tree().paused = false
	world.process_mode = Node.PROCESS_MODE_DISABLED
	ui.show_title(save_service.exists())

func _quit() -> void:
	if playing and not save_progress():
		return
	_shutdown(0)

func _shutdown(exit_code: int) -> void:
	if quitting:
		return
	quitting = true
	Engine.time_scale = 1.0
	get_tree().paused = false
	world.process_mode = Node.PROCESS_MODE_DISABLED
	playing = false
	audio.stop_all()
	# Let the audio mixer retire playback resources before the process exits.
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(exit_code)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(ui):
		_quit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and playing:
		if ui.menu_state == "settings":
			ui.show_pause()
		else:
			set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and playing and not get_tree().paused and is_instance_valid(nearest):
		activate_landmark(nearest)
	elif event.is_action_pressed("cycle_weapon") and playing and not get_tree().paused:
		var index: int = upgrades.find(str(player.attack_controller.get("weapon")))
		player.attack_controller.set("weapon", upgrades[(index + 1) % upgrades.size()])

func activate_landmark(marker: EELandmark) -> void:
	if marker.kind == "checkpoint":
		checkpoint = marker.global_position
		player.vitals.restore()
		marker.activated = true
		if resonator_count() == 3 and marker == markers[0]:
			completed = true
			ui.toast("The roots answer. The three voices are one again.\nExpedition complete — this world remains yours to explore.", 12)
		else:
			ui.toast("Hearth awakened · health and endurance restored")
	elif marker.stable_id in collected:
		return
	else:
		collected.append(marker.stable_id)
		marker.activated = true
		if marker.kind in ["heavy", "thorn"]:
			if not marker.kind in upgrades:
				upgrades.append(marker.kind)
			player.attack_controller.set("weapon", marker.kind)
			ui.toast(marker.label + "\nQ / Y cycles your acquired forms", 5)
		elif marker.kind == "health":
			player.vitals.health = minf(100, player.vitals.health + 35)
			ui.toast("Sunfruit · warmth returns")
		else:
			ui.toast(marker.label + " awakens. " + ("Return to the first hearth." if resonator_count() == 3 else "Another voice stirs deeper in the world."), 6)
	audio.play_pickup()
	save_progress()

func resonator_count() -> int:
	var count: int = 0
	for id: String in collected:
		if id.begins_with("resonator_"):
			count += 1
	return count

func _creature_died(id: String) -> void:
	if not id in defeated:
		defeated.append(id)
	save_progress()

func _impact() -> void:
	audio.play_slap()
	player.shake_amount = 3.5
	if not test_mode:
		hit_stop_until = Time.get_ticks_usec() + 45000
		Engine.time_scale = 0.12

func _on_death() -> void:
	_on_death_deferred.call_deferred()

func _on_death_deferred() -> void:
	ui.toast("The hearth remembers your shape.", 4)
	player.respawn(checkpoint)
	save_progress()

func _process(delta: float) -> void:
	frame_count += 1
	var now_usec: int = Time.get_ticks_usec()
	if frame_count > 120 and last_frame_usec > 0:
		process_samples.append(float(now_usec - last_frame_usec) / 1000.0)
	last_frame_usec = now_usec
	if hit_stop_until > 0 and Time.get_ticks_usec() >= hit_stop_until:
		Engine.time_scale = 1.0
		hit_stop_until = 0
	if playing and not get_tree().paused:
		elapsed += delta
		autosave_elapsed += delta
		world.update_view(player.global_position, elapsed)
		if player.global_position.y > world.bounds.end.y - 70:
			_on_death_deferred()
		_update_proximity()
		var region: String = _region_at(player.global_position.x)
		if not region in discoveries:
			discoveries.append(region)
			if not last_region.is_empty():
				ui.toast(region, 4)
			last_region = region
		ui.update_hud(player, region, resonator_count(), _objective_direction(), _prompt())
		if autosave_elapsed > 35.0 and player.is_on_floor() and player.mode != "swim":
			save_progress()
			# Do not retry a filesystem failure every frame.
			autosave_elapsed = 0.0
	elif is_instance_valid(world) and not playing:
		world.update_view(player.global_position, float(Time.get_ticks_msec()) / 1000.0)
	if not test_mode and frame_count == 300 and not screenshot_path.is_empty() and not capture_started:
		_capture()
	if not test_mode and quit_after_capture and screenshot_path.is_empty() and frame_count > 240:
		if not quitting:
			print("SMOKE PASS: ", frame_count, " frames, player=", player.global_position)
			_shutdown(0)

func _update_proximity() -> void:
	nearest = null
	var best: float = 80.0
	for marker: EELandmark in markers:
		marker.near_player = false
		marker.visible = absf(marker.global_position.x - player.global_position.x) < 1500
		if marker.activated and marker.kind != "checkpoint":
			continue
		var distance: float = marker.global_position.distance_to(player.global_position)
		if distance < best:
			var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(player.global_position, marker.global_position, 1)
			if world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
				best = distance
				nearest = marker
	if nearest != null:
		nearest.near_player = true

func _prompt() -> String:
	if nearest != null:
		return ("X  ·  " if player.controls.using_controller else "E  ·  ") + nearest.label
	if playground:
		if player.global_position.x < 1200:
			return "Jump: Space / A   ·   Roll downhill: Shift / RB"
		if player.global_position.x < 2350:
			return "Swim: WASD / left stick   ·   Burst: Space / A   ·   Rest at the surface"
		if player.global_position.x < 3000:
			return "Hold Ctrl / LB to squeeze beneath the lintel"
		return "Aim at the wall + hold RMB / LT to grip. Move upward to climb."
	if elapsed < 22:
		return "Move: WASD / left stick   ·   Jump: Space / A   ·   Grip: RMB / LT   ·   Pause: Esc"
	return ""

func _objective_direction() -> String:
	if playground:
		return "MOVEMENT CLEARING"
	if completed:
		return "THE ROOTS REMEMBER"
	var target: EELandmark
	if resonator_count() == 3:
		target = markers[0]
	else:
		for marker: EELandmark in markers:
			if marker.kind == "artifact" and not marker.activated:
				target = marker
				break
	if target == null:
		return "Explore the reach"
	var distance: float = player.global_position.distance_to(target.global_position)
	return ("← " if target.global_position.x < player.global_position.x else "→ ") + ("Return to the first hearth" if resonator_count() == 3 else "Follow the distant song") + "  ·  %dm" % int(distance / 40.0)

func _region_at(x: float) -> String:
	if playground:
		return "The movement clearing"
	if x < 8400:
		return "The Verdant Reach"
	if x < 15600:
		return "The Hollow Orchard"
	return "The Drowned Roots"

func _settings_changed(master: float, effects: float, ambience: float, shake: bool, reduced: bool) -> void:
	audio.set_levels(master, effects, ambience)
	if is_instance_valid(player):
		player.camera_shake_enabled = shake
	if is_instance_valid(world):
		world.reduced_effects = reduced
	if test_mode:
		return
	var settings: ConfigFile = ConfigFile.new()
	settings.set_value("audio", "master", master)
	settings.set_value("audio", "effects", effects)
	settings.set_value("audio", "ambience", ambience)
	settings.set_value("display", "shake", shake)
	settings.set_value("display", "reduced", reduced)
	var error: Error = settings.save("user://settings.cfg")
	if error != OK:
		ui.toast("Settings could not be saved.")

func _load_settings() -> void:
	var settings: ConfigFile = ConfigFile.new()
	var error: Error = settings.load("user://settings.cfg")
	if error == OK:
		ui.master_level = clampf(float(settings.get_value("audio", "master", 0.75)), 0, 1)
		ui.effects_level = clampf(float(settings.get_value("audio", "effects", 0.8)), 0, 1)
		ui.ambience_level = clampf(float(settings.get_value("audio", "ambience", 0.35)), 0, 1)
		ui.shake = bool(settings.get_value("display", "shake", true))
		ui.reduced = bool(settings.get_value("display", "reduced", false))
	elif error != ERR_FILE_NOT_FOUND:
		ui.toast("Could not read settings; using defaults.")
	audio.set_levels(ui.master_level, ui.effects_level, ui.ambience_level)

func _strings(source: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in source:
		if value is String and not value in result:
			result.append(value)
	return result

func _vector(source: Variant, fallback: Vector2) -> Vector2:
	if not source is Array or source.size() != 2 or not (source[0] is float or source[0] is int) or not (source[1] is float or source[1] is int):
		return fallback
	var result: Vector2 = Vector2(float(source[0]), float(source[1]))
	return result if result.is_finite() else fallback

func _restore_placement(stats: Dictionary, generation: int) -> void:
	# New static bodies must register before querying; stale continuations cannot move a newer player.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if generation != restore_generation or not is_instance_valid(player) or not is_instance_valid(world):
		return
	var candidate: Vector2 = _vector(stats.get("position", []), checkpoint)
	if not world.bounds.has_point(candidate): return
	var stance: String = str(stats.get("shape_mode", "walk"))
	var shape: Shape2D = player.upright_shape
	if stance == "squeeze": shape = player.squeeze_shape
	elif stance == "roll": shape = player.roll_shape
	else: stance = "walk"
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, candidate)
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	query.margin = 0.0
	if not world.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty(): return
	player.global_position = candidate
	player.collider.shape = shape
	player.shape_mode = stance
	player.mode = stance
	player.velocity = Vector2.ZERO
	player.camera.reset_smoothing()

func position_for_capture(x: float) -> void:
	for module: Dictionary in world.layout.terrain:
		if module.has("branch"):
			continue
		var top: Array = module.top
		for index: int in range(top.size() - 1):
			if x >= float(top[index][0]) and x <= float(top[index + 1][0]):
				var y: float = lerpf(float(top[index][1]), float(top[index + 1][1]), inverse_lerp(float(top[index][0]), float(top[index + 1][0]), x))
				player.respawn(Vector2(x, y - 30))
				return

func _capture() -> void:
	capture_started = true
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	var error: Error = picture.save_png(screenshot_path)
	print("CAPTURE: ", screenshot_path, " error=", error)
	if not process_samples.is_empty():
		process_samples.sort()
		print("PERFORMANCE: samples=", process_samples.size(), " median_frame_ms=", process_samples[process_samples.size() / 2], " p95_frame_ms=", process_samples[int(process_samples.size() * 0.95)], " fps=", Engine.get_frames_per_second())
	if quit_after_capture:
		_shutdown(0 if error == OK else 1)

func _exit_tree() -> void:
	Engine.time_scale = 1.0
