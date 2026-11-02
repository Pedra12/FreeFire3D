extends SceneTree

func _initialize() -> void:
	call_deferred("_audit")

func _audit() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	if player_scene == null:
		push_error("RIG_AUDIT_FAILED: player scene unavailable")
		quit(1)
		return
	var test_root := Node3D.new()
	root.add_child(test_root)
	var test_hud := Control.new()
	test_hud.name = "MobileHUD"
	test_hud.set_script(load("res://scripts/mobile_hud.gd"))
	test_root.add_child(test_hud)
	var player := player_scene.instantiate()
	test_root.add_child(player)
	await process_frame
	await process_frame

	var model := player.get_node_or_null("VisualRoot/FemalePlayer") as Node3D
	if model == null:
		push_error("RIG_AUDIT_FAILED: exported character instance missing")
		quit(1)
		return
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var anim_nodes := model.find_children("*", "AnimationPlayer", true, false)
	print("RIG_AUDIT skeletons=", skeletons.size(), " meshes=", meshes.size(), " animation_players=", anim_nodes.size())
	if skeletons.is_empty() or meshes.is_empty() or anim_nodes.is_empty():
		push_error("RIG_AUDIT_FAILED: expected Skeleton3D + MeshInstance3D + AnimationPlayer")
		quit(1)
		return

	var skeleton := skeletons[0] as Skeleton3D
	var anim_player := anim_nodes[0] as AnimationPlayer
	print("RIG_BONES count=", skeleton.get_bone_count())
	for i in range(skeleton.get_bone_count()):
		var bone_name := skeleton.get_bone_name(i)
		if "hand" in bone_name.to_lower() or "wrist" in bone_name.to_lower() or "arm" in bone_name.to_lower():
			print("RIG_HAND_BONE=", bone_name)

	var animation_names := anim_player.get_animation_list()
	if model.scene_file_path != "res://assets/characters/olivia_rigged.glb":
		push_error("RIG_AUDIT_FAILED: Olivia is not the selected playable model")
		quit(1)
		return
	for required_clip in [&"Idle_Loop", &"Walk_Loop", &"Sprint_Loop", &"Jump_Start", &"Jump_Loop", &"Pistol_Aim_Neutral", &"Pistol_Shoot", &"Pistol_Reload"]:
		if not anim_player.has_animation(required_clip):
			push_error("RIG_AUDIT_FAILED: missing Olivia animation " + String(required_clip))
			quit(1)
			return
	print("OLIVIA_PLAYER_MODEL_OK required_movement_combat_clips=8")
	print("RIG_ANIMATION_COUNT=", animation_names.size())
	for animation_name in animation_names:
		print("RIG_ANIMATION=", animation_name)
	if animation_names.is_empty():
		push_error("RIG_AUDIT_FAILED: AnimationPlayer has no clips")
		quit(1)
		return

	var weapon_scene := load("res://assets/weapons/awm_free_fire.glb") as PackedScene
	if weapon_scene == null:
		push_error("WEAPON_AUDIT_FAILED: AWM GLB unavailable")
		quit(1)
		return
	var weapon := weapon_scene.instantiate()
	root.add_child(weapon)
	await process_frame
	var weapon_meshes := weapon.find_children("*", "MeshInstance3D", true, false)
	if weapon_meshes.is_empty():
		push_error("WEAPON_AUDIT_FAILED: AWM contains no MeshInstance3D")
		quit(1)
		return
	print("WEAPON_MESH_COUNT=", weapon_meshes.size())
	var mount := player.get_node_or_null("WeaponMount")
	if mount == null or mount.get("mounted_weapon") == null:
		push_error("WEAPON_AUDIT_FAILED: weapon not mounted on rig hand")
		quit(1)
		return
	print("RIG_AND_WEAPON_INTEGRATION_OK: skeleton=", skeleton.get_bone_count(),
		" animations=", animation_names.size(), " weapon_meshes=", weapon_meshes.size())
	print("WEAPON_AUDIT_OK")
	quit(0)
