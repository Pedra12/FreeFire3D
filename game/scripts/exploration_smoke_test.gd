extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var house_script := load("res://scripts/explorable_house.gd") as Script
	if house_script == null:
		push_error("EXPLORATION_TEST_FAILED: house script missing")
		quit(1)
		return
	var house := Node3D.new()
	house.set_script(house_script)
	root.add_child(house)
	await physics_frame
	await physics_frame

	var state := house.get_world_3d().direct_space_state
	var doorway := PhysicsRayQueryParameters3D.create(Vector3(0, 1.1, -6.0), Vector3(0, 1.1, -3.0))
	var doorway_hit := state.intersect_ray(doorway)
	if not doorway_hit.is_empty():
		push_error("EXPLORATION_TEST_FAILED: front doorway is blocked by %s" % doorway_hit.collider.name)
		quit(1)
		return

	var wall_ray := PhysicsRayQueryParameters3D.create(Vector3(2.0, 1.1, -6.0), Vector3(2.0, 1.1, -3.0))
	if state.intersect_ray(wall_ray).is_empty():
		push_error("EXPLORATION_TEST_FAILED: wall collision missing beside doorway")
		quit(1)
		return

	var climber := CharacterBody3D.new()
	climber.name = "StairTraversalProbe"
	climber.floor_max_angle = 0.9
	climber.floor_snap_length = 0.35
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.30
	capsule.height = 1.72
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = 0.86
	climber.add_child(collider)
	root.add_child(climber)
	climber.global_position = Vector3(3.15, 0.0, 3.1)
	var elapsed := 0.0
	while elapsed < 5.2:
		var dt := 1.0 / 60.0
		if not climber.is_on_floor():
			climber.velocity.y -= 9.8 * dt
		else:
			climber.velocity.y = 0.0
		climber.velocity.x = 0.0
		climber.velocity.z = -2.4
		climber.move_and_slide()
		await physics_frame
		elapsed += dt
	if climber.global_position.y < 2.55 or climber.global_position.z > -1.2:
		push_error("EXPLORATION_TEST_FAILED: stair ramp not traversable pos=%s" % climber.global_position)
		quit(1)
		return

	var upper_floor_ray := PhysicsRayQueryParameters3D.create(Vector3(0.0, 5.0, 0.0), Vector3(0.0, 2.7, 0.0))
	if state.intersect_ray(upper_floor_ray).is_empty():
		push_error("EXPLORATION_TEST_FAILED: upper floor collision missing")
		quit(1)
		return

	print("EXPLORATION_TEST_OK: doorway_clear=true wall_blocked=true stair_ramp_climbed=true second_floor_collision=true final_position=", climber.global_position)
	quit(0)
