extends SceneTree

func _initialize() -> void:
	call_deferred("_audit")

func _audit() -> void:
	var packed := load("res://assets/characters/olivia_rigged.glb") as PackedScene
	if packed == null:
		push_error("OLIVIA_RIG_GODOT_FAILED: rigged GLB not imported")
		quit(1)
		return
	var model := packed.instantiate()
	root.add_child(model)
	await process_frame
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	var skinned_meshes := 0
	var mesh_count := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		mesh_count += 1
		if (node as MeshInstance3D).skin != null:
			skinned_meshes += 1
	var bones := 0
	for skeleton in skeletons:
		bones += (skeleton as Skeleton3D).get_bone_count()
	var animation_count := 0
	for player in players:
		animation_count += (player as AnimationPlayer).get_animation_list().size()
	print("OLIVIA_RIG_GODOT_OK skeletons=", skeletons.size(), " bones=", bones, " skinned_meshes=", skinned_meshes, "/", mesh_count, " animations=", animation_count)
	if skeletons.size() != 1 or bones < 40 or skinned_meshes < 5 or animation_count < 20:
		push_error("OLIVIA_RIG_GODOT_FAILED: incomplete skeleton, weights or animation import")
		quit(2)
		return
	quit(0)
