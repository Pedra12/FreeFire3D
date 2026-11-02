extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("MAIN_GAMEPLAY_TEST_FAILED: main scene unavailable")
		quit(1)
		return

	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(2.4).timeout

	var safe_ground := scene.get_node_or_null("SafeGround") as StaticBody3D
	if safe_ground == null or safe_ground.get_node_or_null("CollisionShape3D") == null:
		push_error("MAIN_GAMEPLAY_TEST_FAILED: safe ground collider missing")
		quit(1)
		return

	var player_spawn := scene.get_node("Player") as CharacterBody3D
	if player_spawn.global_position.y > 4.0 or not player_spawn.is_on_floor():
		push_error("MAIN_GAMEPLAY_TEST_FAILED: player did not settle on ground y=%.2f grounded=%s" % [player_spawn.global_position.y, player_spawn.is_on_floor()])
		quit(1)
		return

	var map_node := scene.get_node_or_null("Map") as Node3D
	if map_node == null or not map_node.scene_file_path.ends_with("river_side.glb"):
		push_error("MAIN_GAMEPLAY_TEST_FAILED: main scene is not using River Side")
		quit(1)
		return
	var map_meshes := map_node.find_children("*", "MeshInstance3D", true, false)
	if map_meshes.size() < 400:
		push_error("MAIN_GAMEPLAY_TEST_FAILED: River Side geometry incomplete, meshes=%d" % map_meshes.size())
		quit(1)
		return

	var bots := get_nodes_in_group("bots")
	if bots.size() != 4:
		push_error("MAIN_GAMEPLAY_TEST_FAILED: expected 4 bots, found %d" % bots.size())
		quit(1)
		return

	var player := scene.get_node("Player")
	var health := player.get_node_or_null("Health")
	var weapon_mount := player.get_node_or_null("WeaponMount")
	var hud := scene.get_node_or_null("MobileHUD")
	if health == null or hud == null or weapon_mount == null:
		push_error("MAIN_GAMEPLAY_TEST_FAILED: player health, weapon mount or HUD missing")
		quit(1)
		return

	if weapon_mount.get("mounted_weapon") == null:
		push_error("MAIN_GAMEPLAY_TEST_FAILED: player AWM not attached to hand")
		quit(1)
		return

	health.call("apply_damage", 10.0)
	await process_frame
	var hud_health := float(hud.get("health_current"))
	var actual_health := float(health.get("current_health"))
	if absf(hud_health - actual_health) > 0.1 or hud_health >= 100.0:
		push_error("MAIN_GAMEPLAY_TEST_FAILED: HUD/health mismatch HUD=%.1f health=%.1f" % [hud_health, actual_health])
		quit(1)
		return

	var bot_weapons := 0
	for bot in bots:
		var bot_mount := bot.get_node_or_null("WeaponMount")
		if bot_mount != null and bot_mount.get("mounted_weapon") != null:
			bot_weapons += 1
	if bot_weapons != bots.size():
		push_error("MAIN_GAMEPLAY_TEST_FAILED: weapon mounts on bots %d/%d" % [bot_weapons, bots.size()])
		quit(1)
		return

	print("MAIN_GAMEPLAY_TEST_OK: map=RiverSide meshes=", map_meshes.size(), " bots=", bots.size(), " player_health=", hud_health, " bot_attack_verified=", hud_health < 90.0, " weapons=", bot_weapons + 1)
	quit(0)
