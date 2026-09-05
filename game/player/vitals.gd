class_name EEVitals
extends RefCounted

signal hurt
signal died

var health: float = 100.0
var endurance: float = 100.0
var invulnerability: float = 0.0
var drowning_time: float = 0.0
var exhaustion_time: float = 0.0
var recently_hurt: float = 0.0
var config: EEMovementConfig = EEMovementConfig.new()

func tick(delta: float, mode: String, resting: bool, submerged: bool) -> void:
	invulnerability = maxf(0.0, invulnerability - delta)
	recently_hurt = maxf(0.0, recently_hurt - delta)
	if resting:
		endurance = minf(config.endurance_max, endurance + config.recovery * delta)
	elif mode == "climb":
		endurance = maxf(0.0, endurance - config.climb_drain * delta)
	elif mode == "swim":
		endurance = maxf(0.0, endurance - config.swim_drain * delta)
	if endurance <= 0.0:
		exhaustion_time += delta
	else:
		exhaustion_time = 0.0
	if submerged and endurance <= 0.0:
		drowning_time += delta
		if drowning_time > 1.2:
			var previous: float = health
			health = maxf(0.0, health - 18.0 * delta)
			recently_hurt = 3.0
			if health <= 0.0 and previous > 0.0:
				died.emit()
	elif resting or mode != "swim":
		drowning_time = 0.0

func spend(amount: float) -> bool:
	if endurance < amount:
		return false
	endurance -= amount
	return true

func damage(amount: float) -> bool:
	if invulnerability > 0.0 or health <= 0.0 or amount <= 0.0:
		return false
	health = maxf(0.0, health - amount)
	invulnerability = 1.0
	recently_hurt = 4.0
	hurt.emit()
	if health <= 0.0:
		died.emit()
	return true

func restore() -> void:
	health = 100.0
	endurance = config.endurance_max
	drowning_time = 0.0
	exhaustion_time = 0.0
	invulnerability = 0.0
