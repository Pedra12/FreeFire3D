extends Node3D

@export var bot_scene: PackedScene
@export_range(1, 7, 1) var bot_count: int = 7

# Battlefield-style fixed team deployment: blue west, red east.
const BLUE_SPAWN := Vector3(-30.0, 1.5, 0.0)
const RED_SPAWN := Vector3(30.0, 1.5, 0.0)
const BLUE_OFFSETS: Array[Vector3] = [
	Vector3(-2.5, 0.0, -3.0), Vector3(2.5, 0.0, -3.0),
	Vector3(-2.5, 0.0, 3.0), Vector3(2.5, 0.0, 3.0)
]
const RED_OFFSETS: Array[Vector3] = [
	Vector3(-2.5, 0.0, -3.0), Vector3(2.5, 0.0, -3.0),
	Vector3(-2.5, 0.0, 3.0), Vector3(2.5, 0.0, 3.0)
]

func _ready() -> void:
	if bot_scene == null:
		push_error("BOT_SPAWNER: bot_scene is not assigned")
		return
	call_deferred("_spawn_teams")

func _spawn_teams() -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not is_instance_valid(player):
		push_error("BOT_SPAWNER: player group not found")
		return
	var map_node := get_parent().get_node_or_null("Map")
	var waited := 0
	while map_node != null and not bool(map_node.get("is_ready_for_queries")) and waited < 600:
		await get_tree().physics_frame
		waited += 1

	# Player is the fourth member of blue squad; three blue AI + four red AI.
	player.set("team_id", 0)
	player.global_position = _ground_position(BLUE_SPAWN, player)
	for i in range(bot_count):
		var bot := bot_scene.instantiate() as CharacterBody3D
		if bot == null:
			continue
		var team := 0 if i < 3 else 1
		bot.set("team_id", team)
		var class_id := ["assault", "medic", "support", "recon"][i % 4]
		var class_data: Dictionary = MatchConfig.CLASSES[class_id]
		var weapon_id := StringName(String(class_data["weapon"]))
		get_parent().add_child(bot)
		var mount := bot.get_node_or_null("WeaponMount")
		if mount != null:
			mount.call("equip_weapon", weapon_id)
		match weapon_id:
			&"assault_rifle":
				bot.set("attack_damage", 28.0)
				bot.set("attack_interval", 0.18)
				bot.set("attack_range", 38.0)
			&"smg":
				bot.set("attack_damage", 20.0)
				bot.set("attack_interval", 0.14)
				bot.set("attack_range", 24.0)
			&"shotgun":
				bot.set("attack_damage", 34.0)
				bot.set("attack_interval", 0.9)
				bot.set("attack_range", 12.0)
			&"awm":
				bot.set("attack_damage", 48.0)
				bot.set("attack_interval", 1.25)
				bot.set("attack_range", 52.0)
		print("BOT_CLASS class=", class_id, " weapon=", weapon_id)
		var offset: Vector3 = BLUE_OFFSETS[i] if team == 0 else RED_OFFSETS[i - 3]
		var base: Vector3 = BLUE_SPAWN if team == 0 else RED_SPAWN
		bot.global_position = _ground_position(base + offset, bot)
		print("TEAM_DEPLOY team=", team, " slot=", i, " pos=", bot.global_position)
	print("TEAMS_DEPLOYED blue=4 red=4 loot=0")

func _ground_position(point: Vector3, actor: CharacterBody3D) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 45.0, point + Vector3.DOWN * 100.0)
	query.exclude = [actor.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return point
	return hit.position + Vector3.UP * 0.85
