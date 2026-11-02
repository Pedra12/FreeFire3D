extends Node

signal health_changed(current: float, maximum: float)
signal eliminated(killer_team: int)

@export var maximum_health: float = 100.0
var current_health: float = 100.0
var is_eliminated: bool = false

func _ready() -> void:
	current_health = maximum_health
	add_to_group("player_health")
	health_changed.emit(current_health, maximum_health)
	var owner_node := get_parent()
	var hud := owner_node.get_node_or_null("../MobileHUD") as Control
	if hud != null:
		health_changed.connect(hud.set_health)
		hud.set_health(current_health, maximum_health)

func apply_damage(amount: float, source: Node = null) -> bool:
	if is_eliminated or current_health <= 0.0 or amount <= 0.0:
		return false
	var owner_node := get_parent()
	if is_instance_valid(source) and source.get("team_id") != null and int(source.get("team_id")) == int(owner_node.get("team_id")):
		return false
	var inventory := owner_node.get_node_or_null("Inventory")
	var final_damage := amount
	if inventory != null and inventory.has_method("absorb_damage"):
		final_damage = float(inventory.call("absorb_damage", amount))
	current_health = maxf(0.0, current_health - final_damage)
	health_changed.emit(current_health, maximum_health)
	if current_health <= 0.0:
		is_eliminated = true
		var killer_team := int(source.get("team_id")) if is_instance_valid(source) and source.get("team_id") != null else -1
		eliminated.emit(killer_team)
		return true
	return false

func heal(amount: float) -> void:
	if is_eliminated or amount <= 0.0:
		return
	current_health = minf(maximum_health, current_health + amount)
	health_changed.emit(current_health, maximum_health)
