extends SceneTree

func _initialize() -> void:
	call_deferred("_audit")

func _audit() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("SCALE_AUDIT: main scene could not be loaded")
		quit(2)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var map_node := scene.get_node("Map") as Node3D
	var player_node := scene.get_node("Player") as Node3D
	var model_node := player_node.get_node("VisualRoot/FemalePlayer") as Node3D
	var map_bounds := _combined_bounds(map_node)
	var model_bounds := _combined_bounds(model_node)
	print("SCALE_AUDIT map_scale=", map_node.scale,
		" map_size=", map_bounds.size,
		" model_size=", model_bounds.size,
		" player_scale=", player_node.scale,
		" model_local_scale=", model_node.scale)
	quit()

func _combined_bounds(root_node: Node3D) -> AABB:
	var found := false
	var combined := AABB()
	for child in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := child as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			continue
		var world_bounds: AABB = mesh_node.global_transform * mesh_node.get_aabb()
		var local_bounds: AABB = root_node.global_transform.affine_inverse() * world_bounds
		if not found:
			combined = local_bounds
			found = true
		else:
			combined = combined.merge(local_bounds)
	return combined
