extends SceneTree

func _initialize() -> void:
	call_deferred("_audit")

func _audit() -> void:
	var packed := load("res://assets/maps/clocktower.glb") as PackedScene
	if packed == null:
		push_error("CLOCKTOWER_AUDIT_FAILED: map GLB did not import")
		quit(1)
		return
	var holder := Node3D.new()
	root.add_child(holder)
	var map := packed.instantiate() as Node3D
	holder.add_child(map)
	await process_frame
	var meshes := map.find_children("*", "MeshInstance3D", true, false)
	var textured := 0
	var colliders := 0
	var min_point := Vector3(INF, INF, INF)
	var max_point := Vector3(-INF, -INF, -INF)
	for item in meshes:
		var mesh_node := item as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		var bounds: AABB = mesh_node.get_transformed_aabb()
		min_point = min_point.min(bounds.position)
		max_point = max_point.max(bounds.end)
		for surface in range(mesh_node.mesh.get_surface_count()):
			var mat := mesh_node.get_active_material(surface)
			if mat is StandardMaterial3D and (mat as StandardMaterial3D).albedo_texture != null:
				textured += 1
		var before := mesh_node.get_child_count()
		mesh_node.create_trimesh_collision()
		if mesh_node.get_child_count() > before:
			colliders += 1
	var dimensions := max_point - min_point
	print("CLOCKTOWER_GEOMETRY meshes=", meshes.size(), " dimensions=", dimensions,
		" textured_surfaces=", textured, " colliders=", colliders)
	if meshes.size() < 30 or textured < 5 or colliders < 30:
		push_error("CLOCKTOWER_AUDIT_FAILED: mesh, texture or collision count below target")
		quit(2)
		return
	if dimensions.x < 70.0 or dimensions.x > 100.0 or dimensions.y < 20.0 or dimensions.y > 35.0 or dimensions.z < 95.0 or dimensions.z > 130.0:
		push_error("CLOCKTOWER_AUDIT_FAILED: unexpected orientation or map scale")
		quit(3)
		return
	await physics_frame
	await physics_frame
	var report_path := "res://assets/maps/clocktower.glb.json"
	if not FileAccess.file_exists(report_path):
		push_error("CLOCKTOWER_AUDIT_FAILED: conversion report missing")
		quit(4)
		return
	var report: Variant = JSON.parse_string(FileAccess.get_file_as_string(report_path))
	if not report is Dictionary:
		push_error("CLOCKTOWER_AUDIT_FAILED: conversion report invalid")
		quit(4)
		return
	var space := holder.get_world_3d().direct_space_state
	var prefixes := [
		"Zone_A_House_Medium_B_LOD0_0",
		"Zone_A_House_Medium_A_LOD0_0",
		"Zone_A_House_Huge_A_LOD0_0",
		"Zone_A_House_Big_B_LOD0_1",
		"mansion_LOD0_0",
		"Tower_01_LOD0_0"
	]
	var floor_hits := 0
	for prefix in prefixes:
		var selected: Dictionary = {}
		for object_data in report.get("objects", []):
			if String(object_data.get("name", "")).begins_with(prefix):
				selected = object_data
				break
		if selected.is_empty():
			print("CLOCKTOWER_INTERIOR_OBJECT_MISSING ", prefix)
			continue
		var center_data: Array = selected.get("center", [0.0, 0.0, 0.0])
		var minimum_data: Array = selected.get("bounds_min", [0.0, 0.0, 0.0])
		var center := Vector3(float(center_data[0]), float(center_data[2]), float(center_data[1]))
		var floor_y := float(minimum_data[2])
		var found := false
		for dx in [-2.0, 0.0, 2.0]:
			for dz in [-2.0, 0.0, 2.0]:
				var query := PhysicsRayQueryParameters3D.create(
					Vector3(center.x + dx, floor_y + 1.4, center.z + dz),
					Vector3(center.x + dx, floor_y - 0.35, center.z + dz))
				var hit := space.intersect_ray(query)
				if not hit.is_empty() and absf(float(hit.position.y) - floor_y) <= 0.55:
					found = true
					break
			if found:
				break
		if found:
			floor_hits += 1
			print("CLOCKTOWER_INTERIOR_OK ", prefix)
		else:
			print("CLOCKTOWER_INTERIOR_NEEDS_FLOOR_REVIEW ", prefix)
	print("CLOCKTOWER_INTERIOR_FLOORS accessible=", floor_hits, "/", prefixes.size())
	if floor_hits < 3:
		push_error("CLOCKTOWER_AUDIT_FAILED: fewer than three accessible building floors")
		quit(5)
		return
	print("CLOCKTOWER_MAP_AUDIT_OK meshes=", meshes.size(), " textures=", textured,
		" colliders=", colliders, " accessible_interiors=", floor_hits)
	quit(0)
