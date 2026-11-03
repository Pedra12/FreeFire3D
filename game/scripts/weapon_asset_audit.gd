extends SceneTree

const WEAPON_PATHS := {
	&"awm": "res://assets/weapons/awm_free_fire.glb",
	&"assault_rifle": "res://assets/weapons/assault_rifle.glb",
	&"smg": "res://assets/weapons/smg.glb",
	&"shotgun": "res://assets/weapons/shotgun.glb",
	&"pistol": "res://assets/weapons/pistol.glb"
}

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
	await create_timer(0.15).timeout

	var model := player.get_node_or_null("VisualRoot/Olivia") as Node3D
	if model == null or model.scene_file_path != "res://assets/characters/olivia_rigged.glb":
		push_error("RIG_AUDIT_FAILED: Olivia is not the selected playable model")
		quit(1)
		return
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var anim_nodes := model.find_children("*", "AnimationPlayer", true, false)
	print("RIG_AUDIT skeletons=", skeletons.size(), " meshes=", meshes.size(), " animation_players=", anim_nodes.size())
	if skeletons.size() != 1 or meshes.size() < 5 or anim_nodes.is_empty():
		push_error("RIG_AUDIT_FAILED: Olivia skeleton, skinned meshes or AnimationPlayer missing")
		quit(1)
		return

	var skeleton := skeletons[0] as Skeleton3D
	var anim_player := anim_nodes[0] as AnimationPlayer
	print("RIG_BONES count=", skeleton.get_bone_count())
	if skeleton.get_bone_count() < 40:
		push_error("RIG_AUDIT_FAILED: Olivia skeleton has too few bones")
		quit(1)
		return
	var animation_names := anim_player.get_animation_list()
	var required_groups := [
		[&"Idle_Loop", &"Idle"],
		[&"Walk_Loop", &"Walk"],
		[&"Sprint_Loop", &"Sprint"],
		[&"Jump_Start"],
		[&"Jump_Loop", &"Jump"],
		[&"Pistol_Aim_Neutral"],
		[&"Pistol_Shoot"],
		[&"Pistol_Reload"]
	]
	for aliases in required_groups:
		var found := false
		for clip in aliases:
			if anim_player.has_animation(clip):
				found = true
				break
		if not found:
			push_error("RIG_AUDIT_FAILED: required movement or combat animation missing: " + str(aliases))
			quit(1)
			return
	print("OLIVIA_PLAYER_MODEL_OK bones=", skeleton.get_bone_count(), " meshes=", meshes.size(), " clips=", animation_names.size())

	for weapon_id in WEAPON_PATHS:
		var weapon_scene := load(WEAPON_PATHS[weapon_id]) as PackedScene
		if weapon_scene == null:
			push_error("WEAPON_AUDIT_FAILED: missing " + String(weapon_id) + " at " + WEAPON_PATHS[weapon_id])
			quit(1)
			return
		var weapon := weapon_scene.instantiate() as Node3D
		root.add_child(weapon)
		await process_frame
		var weapon_meshes := weapon.find_children("*", "MeshInstance3D", true, false)
		if weapon_meshes.is_empty():
			push_error("WEAPON_AUDIT_FAILED: " + String(weapon_id) + " contains no mesh")
			quit(1)
			return
		print("WEAPON_MODEL_OK id=", weapon_id, " meshes=", weapon_meshes.size())
		weapon.queue_free()

	var mount := player.get_node_or_null("WeaponMount")
	var combat := player.get_node_or_null("CombatController")
	if mount == null or combat == null:
		push_error("WEAPON_AUDIT_FAILED: player mount or combat controller missing")
		quit(1)
		return
	for weapon_id in [&"awm", &"assault_rifle", &"smg", &"shotgun", &"pistol"]:
		if not bool(mount.call("equip_weapon", weapon_id)):
			push_error("WEAPON_AUDIT_FAILED: cannot mount " + String(weapon_id))
			quit(1)
			return
		if not bool(combat.call("equip_weapon", weapon_id)):
			push_error("WEAPON_AUDIT_FAILED: cannot configure combat for " + String(weapon_id))
			quit(1)
			return
		await create_timer(0.12).timeout
		if mount.get("current_weapon_id") != weapon_id or mount.get("mounted_weapon") == null:
			push_error("WEAPON_AUDIT_FAILED: mount did not finish equipping " + String(weapon_id))
			quit(1)
			return
		print("WEAPON_EQUIP_OK id=", weapon_id, " magazine=", combat.get("magazine_size"))
	var bot_scene := load("res://scenes/bot.tscn") as PackedScene
	if bot_scene == null:
		push_error("WEAPON_AUDIT_FAILED: bot scene unavailable")
		quit(1)
		return
	var bot := bot_scene.instantiate()
	test_root.add_child(bot)
	await process_frame
	var bot_mount := bot.get_node_or_null("WeaponMount")
	if bot_mount == null:
		push_error("WEAPON_AUDIT_FAILED: bot weapon mount missing")
		quit(1)
		return
	for bot_weapon_id in WEAPON_PATHS:
		if not bool(bot_mount.call("equip_weapon", bot_weapon_id)):
			push_error("WEAPON_AUDIT_FAILED: bot cannot equip " + String(bot_weapon_id))
			quit(1)
			return
		await create_timer(0.12).timeout
		if bot_mount.get("mounted_weapon") == null or bot_mount.get("weapon_attachment") == null:
			push_error("WEAPON_AUDIT_FAILED: bot weapon not visibly mounted: " + String(bot_weapon_id))
			quit(1)
			return
		print("BOT_WEAPON_MOUNT_OK weapon=", bot_weapon_id)
	print("RIG_AND_WEAPON_INTEGRATION_OK: Olivia skeleton=", skeleton.get_bone_count(),
		" animations=", animation_names.size(), " weapon_classes=", WEAPON_PATHS.size())
	print("WEAPON_AUDIT_OK")
	quit(0)
