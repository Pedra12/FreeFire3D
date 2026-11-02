extends Node3D

@export var loot_scene: PackedScene
@export var max_loot: int = 14

var loot_points: Array[Dictionary] = [
	{"p": Vector3(-13.0, 0.0, -10.0), "t": &"ammo_762", "a": 15, "n": "MUNIÇÃO 7.62", "c": Color(0.95, 0.72, 0.22)},
	{"p": Vector3(-8.0, 0.0, -7.0), "t": &"medkit", "a": 1, "n": "KIT MÉDICO", "c": Color(0.20, 0.88, 0.42)},
	{"p": Vector3(10.0, 0.0, -12.0), "t": &"frag_grenade", "a": 1, "n": "GRANADA", "c": Color(0.94, 0.30, 0.16)},
	{"p": Vector3(14.0, 0.0, -5.0), "t": &"armor", "a": 1, "n": "COLETE", "c": Color(0.18, 0.58, 0.95)},
	{"p": Vector3(-15.0, 0.0, 9.0), "t": &"helmet", "a": 1, "n": "CAPACETE", "c": Color(0.58, 0.72, 0.96)},
	{"p": Vector3(-5.0, 0.0, 14.0), "t": &"backpack", "a": 1, "n": "MOCHILA", "c": Color(0.72, 0.42, 0.20)},
	{"p": Vector3(7.0, 0.0, 13.0), "t": &"ammo_762", "a": 15, "n": "MUNIÇÃO 7.62", "c": Color(0.95, 0.72, 0.22)},
	{"p": Vector3(18.0, 0.0, 12.0), "t": &"medkit", "a": 1, "n": "KIT MÉDICO", "c": Color(0.20, 0.88, 0.42)},
	{"p": Vector3(-20.0, 0.0, -2.0), "t": &"frag_grenade", "a": 1, "n": "GRANADA", "c": Color(0.94, 0.30, 0.16)},
	{"p": Vector3(1.0, 0.0, -19.0), "t": &"armor", "a": 1, "n": "COLETE", "c": Color(0.18, 0.58, 0.95)},
	{"p": Vector3(21.0, 0.0, 3.0), "t": &"ammo_762", "a": 15, "n": "MUNIÇÃO 7.62", "c": Color(0.95, 0.72, 0.22)},
	{"p": Vector3(-2.0, 0.0, 21.0), "t": &"helmet", "a": 1, "n": "CAPACETE", "c": Color(0.58, 0.72, 0.96)},
	{"p": Vector3(4.0, 0.0, 4.0), "t": &"medkit", "a": 1, "n": "KIT MÉDICO", "c": Color(0.20, 0.88, 0.42)},
	{"p": Vector3(-22.0, 0.0, 16.0), "t": &"ammo_762", "a": 15, "n": "MUNIÇÃO 7.62", "c": Color(0.95, 0.72, 0.22)}
]

func _ready() -> void:
	if loot_scene == null:
		push_error("LOOT_SPAWNER: loot_scene não foi atribuída")
		return
	call_deferred("_spawn_loot")

func _spawn_loot() -> void:
	var map_node := get_parent().get_node_or_null("Map")
	var waited := 0
	while map_node != null and not bool(map_node.get("is_ready_for_queries")) and waited < 600:
		await get_tree().physics_frame
		waited += 1
	var count := mini(max_loot, loot_points.size())
	var created := 0
	for i in range(count):
		var entry: Dictionary = loot_points[i]
		var point: Vector3 = entry["p"]
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 35.0, point + Vector3.DOWN * 55.0)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var pickup := loot_scene.instantiate() as Area3D
		if pickup == null:
			continue
		pickup.set("item_type", entry["t"])
		pickup.set("amount", entry["a"])
		pickup.set("display_name", entry["n"])
		pickup.set("item_color", entry["c"])
		add_child(pickup)
		pickup.global_position = hit.position + Vector3.UP * 0.05
		created += 1
	print("LOOT_SPAWNED count=", created, " requested=", count, " waited_frames=", waited)
