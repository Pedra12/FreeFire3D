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
	await create_timer(5.0).timeout

	var safe_ground := scene.get_node_or_null("SafeGround") as StaticBody3D
	if safe_ground == null or safe_ground.get_node_or_null("CollisionShape3D") == null:
		push_error("MAIN_GAMEPLAY_TEST_FAILED: safe ground collider missing")
		quit(1)
		return

	var player := scene.get_node("Player") as CharacterBody3D
	if player.global_position.y > 4.0 or not player.is_on_floor():
		push_error("MAIN_GAMEPLAY_TEST_FAILED: player did not settle on ground y=%.2f grounded=%s" % [player.global_position.y, player.is_on_floor()])
		quit(1)
		return

	var map_node := scene.get_node_or_null("Map") as Node3D
	if map_node == null or not map_node.scene_file_path.ends_with("river_side.glb"):
		push_error("MAIN_GAMEPLAY_TEST_FAILED: main scene is not using River Side")
		quit(1)
		return
	if not bool(map_node.get("is_ready_for_queries")):
		push_error("MAIN_GAMEPLAY_TEST_FAILED: map collisions were not completed")
		quit(1)
		return
	var map_meshes := map_node.find_children("*", "MeshInstance3D", true, false)
	if map_meshes.size() < 400:
		push_error("MAIN_GAMEPLAY_TEST_FAILED: River Side geometry incomplete, meshes=%d" % map_meshes.size())
		quit(1)
		return

	var bots := get_nodes_in_group("bots")
	if bots.size() != 7:
		push_error("MAIN_GAMEPLAY_TEST_FAILED: expected 7 bots for 4v4, found %d" % bots.size())
		quit(1)
		return
	var allies := 0
	var enemies := 0
	for bot in bots:
		if int(bot.get("team_id")) == 0:
			allies += 1
		elif int(bot.get("team_id")) == 1:
			enemies += 1
	if allies != 3 or enemies != 4:
		push_error("MAIN_GAMEPLAY_TEST_FAILED: team composition allies=%d enemies=%d" % [allies, enemies])
		quit(1)
		return

	var health := player.get_node_or_null("Health")
	var inventory := player.get_node_or_null("Inventory")
	var weapon_mount := player.get_node_or_null("WeaponMount")
	var hud := scene.get_node_or_null("MobileHUD")
	if health == null or inventory == null or hud == null or weapon_mount == null:
		push_error("MAIN_GAMEPLAY_TEST_FAILED: player health, inventory, weapon mount or HUD missing")
		quit(1)
		return
	if weapon_mount.get("mounted_weapon") == null:
		push_error("MAIN_GAMEPLAY_TEST_FAILED: player AWM not attached to hand")
		quit(1)
		return
	if int(inventory.get("ammo_sniper")) != 20 or int(inventory.get("ammo_556")) != 120 or int(inventory.get("ammo_9mm")) != 90 or int(inventory.get("ammo_12g")) != 24 or int(inventory.get("medkits")) != 2 or int(inventory.get("grenades")) != 1:
		push_error("MAIN_GAMEPLAY_TEST_FAILED: inventory starting loadout invalid")
		quit(1)
		return

	var bot_weapons := 0
	for bot in bots:
		var bot_mount := bot.get_node_or_null("WeaponMount")
		if bot_mount != null and bot_mount.get("mounted_weapon") != null:
			bot_weapons += 1
	if bot_weapons != 7:
		push_error("MAIN_GAMEPLAY_TEST_FAILED: weapon mounts on bots %d/7" % bot_weapons)
		quit(1)
		return

	var loot_nodes := scene.get_node("LootSpawner").get_children()
	if loot_nodes.size() < 14:
		push_error("MAIN_GAMEPLAY_TEST_FAILED: too few loot pickups spawned: %d" % loot_nodes.size())
		quit(1)
		return
	var weapon_loot_count := 0
	for loot in loot_nodes:
		if String(loot.get("item_type")).begins_with("weapon_"):
			weapon_loot_count += 1
			if loot.get("weapon_visual") == null:
				push_error("MAIN_GAMEPLAY_TEST_FAILED: 3D weapon loot visual missing for " + String(loot.get("item_type")))
				quit(1)
				return
	if weapon_loot_count != 4:
		push_error("MAIN_GAMEPLAY_TEST_FAILED: expected 4 weapon loot models, found %d" % weapon_loot_count)
		quit(1)
		return

	var allied_bot: Node = null
	var enemy_bot: Node = null
	for bot in bots:
		if int(bot.get("team_id")) == 0 and allied_bot == null:
			allied_bot = bot
		if int(bot.get("team_id")) == 1 and enemy_bot == null:
			enemy_bot = bot
	var before_friendly := float(health.get("current_health"))
	player.call("apply_damage", 10.0, player.global_position, Vector3.UP, allied_bot)
	if absf(float(health.get("current_health")) - before_friendly) > 0.01:
		push_error("MAIN_GAMEPLAY_TEST_FAILED: friendly fire was not blocked")
		quit(1)
		return
	enemy_bot.call("apply_damage", 20.0, enemy_bot.global_position, Vector3.UP, player)
	if float(enemy_bot.get("health")) >= 100.0:
		push_error("MAIN_GAMEPLAY_TEST_FAILED: enemy damage path failed")
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

	print("MAIN_GAMEPLAY_TEST_OK: map=RiverSide meshes=", map_meshes.size(), " bots=7 teams=3+4 loot=", loot_nodes.size(), " weapon_loot=", weapon_loot_count, " player_inventory=OK weapon_classes=5 friendly_fire=OFF")
	quit(0)
