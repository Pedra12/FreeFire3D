extends Node3D

@export var bot_scene: PackedScene
@export_range(1, 12, 1) var bot_count: int = 4
@export var spawn_radius: float = 18.0

var spawn_offsets: Array[Vector3] = [
	Vector3(10.0, 4.0, -12.0),
	Vector3(-13.0, 4.0, -8.0),
	Vector3(8.0, 4.0, 15.0),
	Vector3(-15.0, 4.0, 13.0),
	Vector3(20.0, 4.0, 2.0),
	Vector3(-21.0, 4.0, -1.0),
	Vector3(2.0, 4.0, -23.0),
	Vector3(-3.0, 4.0, 24.0)
]

func _ready() -> void:
	if bot_scene == null:
		push_error("BOT_SPAWNER: bot_scene is not assigned")
		return
	await get_tree().create_timer(1.2).timeout
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(player):
		push_error("BOT_SPAWNER: player group not found")
		return
	for i in range(bot_count):
		var bot := bot_scene.instantiate() as CharacterBody3D
		if bot == null:
			continue
		get_parent().add_child(bot)
		var offset: Vector3 = spawn_offsets[i % spawn_offsets.size()]
		bot.global_position = player.global_position + offset
	print("BOTS_SPAWNED count=", bot_count)
