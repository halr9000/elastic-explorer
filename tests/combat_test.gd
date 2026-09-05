extends RefCounted

class Dummy:
	extends CharacterBody2D
	var hits: int = 0
	var damage_total: float = 0.0
	func take_damage(amount: float, _impulse: Vector2) -> void:
		hits += 1
		damage_total += amount

func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	if not ResourceLoader.exists("res://game/combat/attack_controller.gd"):
		return ["Directional attack controller must exist"]
	var body = CharacterBody2D.new()
	tree.root.add_child(body)
	var attack = load("res://game/combat/attack_controller.gd").new()
	body.add_child(attack)
	attack.setup(body)
	var enemy = Dummy.new()
	tree.root.add_child(enemy)
	enemy.add_to_group("damageable")
	enemy.position = Vector2(60, 0)
	attack.tick(0.0, Vector2.RIGHT, true, true)
	for i in 40: attack.tick(0.01, Vector2.RIGHT, false, true)
	if enemy.hits != 1: failures.append("One target must receive exactly one hit per swing while gripping")
	enemy.hits = 0
	enemy.position = Vector2(-60, 0)
	for i in 70: attack.tick(0.01, Vector2.RIGHT, false, false)
	attack.tick(0.0, Vector2.RIGHT, true, false)
	for i in 60: attack.tick(0.01, Vector2.RIGHT, false, false)
	if enemy.hits != 0: failures.append("Attack must not hit targets behind aim")
	enemy.position = Vector2(60, 0)
	var wall = StaticBody2D.new()
	wall.collision_layer = 1
	var collider = CollisionShape2D.new()
	var rectangle = RectangleShape2D.new()
	rectangle.size = Vector2(10, 200)
	collider.shape = rectangle
	wall.add_child(collider)
	wall.position = Vector2(30,0)
	tree.root.add_child(wall)
	await tree.physics_frame
	await tree.physics_frame
	for i in 70: attack.tick(0.01, Vector2.RIGHT, false, false)
	attack.tick(0.0, Vector2.RIGHT, true, false)
	for i in 60: attack.tick(0.01, Vector2.RIGHT, false, false)
	if enemy.hits != 0: failures.append("Terrain must occlude melee damage")
	wall.free()
	await tree.physics_frame
	await tree.physics_frame
	enemy.damage_total = 0
	attack.weapon = "heavy"
	for i in 70: attack.tick(0.01, Vector2.RIGHT, false, false)
	attack.tick(0.0, Vector2.RIGHT, true, false)
	attack.weapon = "thorn"
	for i in 70: attack.tick(0.01, Vector2.RIGHT, false, false)
	if enemy.damage_total != 45.0: failures.append("Heavy weapon must use its distinct damage")
	var wildlife_script = load("res://game/creatures/creature.gd")
	for creature_kind in ["grazer", "fish", "crawler", "spitter"]:
		var creature = wildlife_script.new()
		creature.configure(creature_kind, Vector2.ZERO, creature_kind)
		tree.root.add_child(creature)
		if creature.is_in_group("damageable") != (creature_kind in ["crawler", "spitter"]): failures.append("Only hostile wildlife is damageable")
		if creature_kind in ["crawler", "spitter"]:
			var deaths: Array[String] = []
			creature.died.connect(func(id: String): deaths.append(id))
			creature.take_damage(100.0, Vector2.ZERO)
			if deaths != [creature_kind]: failures.append("Hostile death must emit stable persistent ID")
			creature.take_damage(100.0, Vector2.ZERO)
			if deaths.size() != 1: failures.append("Death must emit once")
		else:
			creature.take_damage(100.0, Vector2.ZERO)
			if creature.health <= 0: failures.append("Benign wildlife must remain unharmed")
		creature.free()
	var audio = load("res://game/audio/audio.gd").new()
	tree.root.add_child(audio)
	audio.set_levels(0, 0, 0)
	audio.play_slap()
	audio.play_pickup()
	audio.play_jump()
	audio.free()
	await tree.create_timer(0.15).timeout
	enemy.free()
	body.free()
	return failures
