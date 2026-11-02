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

	var bots := get_nodes_in_group("bots")
	if bots.size() != 4:
		push_error("MAIN_GAMEPLAY_TEST_FAILED: expected 4 bots, found %d" % bots.size())
		quit(1)
		return

	var player := scene.get_node("Player")
	var health := player.get_node_or_null("Health")
	var hud := scene.get_node_or_null("MobileHUD")
	if health == null or hud == null:
		push_error("MAIN_GAMEPLAY_TEST_FAILED: player health or HUD missing")
		quit(1)
		return

	health.call("apply_damage", 10.0)
	await process_frame
	var hud_health := float(hud.get("health_current"))
	if absf(hud_health - 90.0) > 0.1:
		push_error("MAIN_GAMEPLAY_TEST_FAILED: HUD health did not update, got %.1f" % hud_health)
		quit(1)
		return

	print("MAIN_GAMEPLAY_TEST_OK: bots=", bots.size(), " player_health=", hud_health)
	quit(0)
