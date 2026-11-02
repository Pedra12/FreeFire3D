extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var packed := load("res://scenes/combat_test.tscn") as PackedScene
	if packed == null:
		push_error("COMBAT_TEST: could not load test scene")
		quit(1)
		return

	var test_scene := packed.instantiate()
	root.add_child(test_scene)
	current_scene = test_scene

	for frame in range(6):
		await physics_frame

	var combat := test_scene.get_node("Player/CombatController")
	var target := test_scene.get_node("TrainingTarget")
	var health_before: float = float(target.get("health"))
	combat.call("_fire_once")
	await physics_frame
	await process_frame

	var health_after: float = float(target.get("health"))
	if health_after >= health_before:
		push_error("COMBAT_TEST_FAILED: hitscan did not damage the target")
		quit(1)
		return

	print("COMBAT_TEST_OK: target health ", health_before, " -> ", health_after)
	quit(0)
