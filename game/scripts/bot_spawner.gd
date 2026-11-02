extends Node3D

@export var bot_scene: PackedScene
@export_range(1, 12, 1) var bot_count: int = 7

var team_zero_offsets: Array[Vector3] = [
	Vector3(5.0, 4.0, 5.0),
	Vector3(-5.0, 4.0, 5.0),
	Vector3(0.0, 4.0, 8.0)
]
var team_one_offsets: Array[Vector3] = [
	Vector3(18.0, 4.0, -20.0),
	Vector3(-18.0, 4.0, -20.0),
	Vector3(20.0, 4.0, 18.0),
	Vector3(-20.0, 4.0, 18.0)
]

func _ready() -> void:
	if bot_scene == null:
		push_error("BOT_SPAWNER: bot_scene is not assigned")
		return
	call_deferred("_spawn_teams")

func _spawn_teams() -> void:
	await get_tree().create_timer(1.2).timeout
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(player):
		push_error("BOT_SPAWNER: player group not found")
		return
	for i in range(bot_count):
		var bot := bot_scene.instantiate() as CharacterBody3D
		if bot == null:
			continue
		var team := 0 if i < 3 else 1
		bot.set("team_id", team)
		get_parent().add_child(bot)
		var offset: Vector3
		if team == 0:
			offset = team_zero_offsets[i % team_zero_offsets.size()]
		else:
			offset = team_one_offsets[(i - 3) % team_one_offsets.size()]
		bot.global_position = player.global_position + offset
	print("BOTS_SPAWNED total=", bot_count, " allies=3 enemies=4")
