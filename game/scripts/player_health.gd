extends Node

signal health_changed(current: float, maximum: float)
signal eliminated

@export var maximum_health: float = 100.0
var current_health: float = 100.0

func _ready() -> void:
	current_health = maximum_health
	health_changed.emit(current_health, maximum_health)
	var owner_node := get_parent()
	var hud := owner_node.get_node_or_null("../MobileHUD") as Control
	if hud != null:
		health_changed.connect(hud.set_health)
		hud.set_health(current_health, maximum_health)

func apply_damage(amount: float) -> void:
	if current_health <= 0.0:
		return
	current_health = maxf(0.0, current_health - amount)
	health_changed.emit(current_health, maximum_health)
	if current_health <= 0.0:
		eliminated.emit()

func heal(amount: float) -> void:
	current_health = minf(maximum_health, current_health + amount)
	health_changed.emit(current_health, maximum_health)
