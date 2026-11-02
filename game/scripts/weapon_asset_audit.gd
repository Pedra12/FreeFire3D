extends SceneTree

func _initialize() -> void:
	call_deferred("_audit")

func _audit() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	if player_scene == null:
		push_error("WEAPON_AUDIT: player scene unavailable")
		quit(1)
		return
	var test_root := Node3D.new()
	root.add_child(test_root)
	var test_hud := Control.new()
	test_hud.name = "MobileHUD"
	test_root.add_child(test_hud)
	var player := player_scene.instantiate()
	test_root.add_child(player)
	await process_frame
	await process_frame
	var model := player.get_node("VisualRoot/FemalePlayer")
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	print("PLAYER_SKELETON_COUNT=", skeletons.size())
	for skeleton in skeletons:
		var sk := skeleton as Skeleton3D
		print("SKELETON_BONE_COUNT=", sk.get_bone_count())
		for i in range(sk.get_bone_count()):
			var bone_name := sk.get_bone_name(i)
			if "hand" in bone_name.to_lower() or "wrist" in bone_name.to_lower() or "arm" in bone_name.to_lower():
				print("HAND_BONE_CANDIDATE=", bone_name)
	var weapon_scene := load("res://assets/weapons/awm_free_fire.glb") as PackedScene
	if weapon_scene == null:
		push_error("WEAPON_AUDIT: AWM GLB unavailable")
		quit(1)
		return
	var weapon := weapon_scene.instantiate()
	root.add_child(weapon)
	await process_frame
	var meshes := weapon.find_children("*", "MeshInstance3D", true, false)
	print("WEAPON_MESH_COUNT=", meshes.size())
	for mesh_node in meshes:
		var mesh := mesh_node as MeshInstance3D
		print("WEAPON_MESH_AABB=", mesh.name, " ", mesh.get_aabb())
	print("WEAPON_AUDIT_OK")
	quit(0)
