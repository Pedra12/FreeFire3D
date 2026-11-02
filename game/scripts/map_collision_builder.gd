extends Node3D

signal collisions_ready(generated: int, skipped: int)

## Builds collision from imported world meshes without creating colliders
## for sky, cloud cards, or water surfaces.
@export var generate_collisions: bool = true
@export var skip_material_tokens: PackedStringArray = PackedStringArray(["cloud", "wave", "water", "sky"])
var is_ready_for_queries: bool = false

func _ready() -> void:
	_apply_ground_pbr()
	if generate_collisions:
		call_deferred("_generate_map_collisions")
	else:
		is_ready_for_queries = true

func _apply_ground_pbr() -> void:
	var material := load("res://assets/textures/pbr/ground_material.tres") as StandardMaterial3D
	if material == null:
		print("PBR_GROUND_SKIPPED: material resource unavailable")
		return
	var ground := find_child("Object_15", true, false) as MeshInstance3D
	if ground == null or ground.mesh == null:
		push_warning("PBR_GROUND: terrain mesh Object_15 not found")
		return
	ground.material_override = material.duplicate() as StandardMaterial3D
	print("PBR_GROUND_APPLIED: ", ground.name, " mesh=", ground.mesh.resource_name)

func _should_skip(mesh_instance: MeshInstance3D) -> bool:
	var mesh := mesh_instance.mesh
	if mesh == null:
		return true
	var searchable := mesh_instance.name.to_lower()
	for surface in range(mesh.get_surface_count()):
		var material := mesh.surface_get_material(surface)
		if material != null:
			searchable += " " + material.resource_name.to_lower()
			searchable += " " + material.resource_path.to_lower()
	for token in skip_material_tokens:
		if searchable.contains(token):
			return true
	return false

func _is_vaultable(mesh_instance: MeshInstance3D) -> bool:
	var searchable := mesh_instance.name.to_lower()
	var mesh := mesh_instance.mesh
	if mesh == null:
		return false
	for surface in range(mesh.get_surface_count()):
		var material := mesh.surface_get_material(surface)
		if material != null:
			searchable += " " + material.resource_name.to_lower()
			searchable += " " + material.resource_path.to_lower()
	if searchable.contains("vaultable") or searchable.contains("window") or searchable.contains("sill") or searchable.contains("fence") or searchable.contains("barrier"):
		return true
	var transformed_bounds: AABB = mesh_instance.get_transformed_aabb()
	var dimensions: Vector3 = transformed_bounds.size
	var horizontal_span: float = maxf(dimensions.x, dimensions.z)
	return dimensions.y >= 0.35 and dimensions.y <= 1.45 and horizontal_span >= 0.35 and horizontal_span <= 6.0

func _generate_map_collisions() -> void:
	var mesh_nodes := find_children("*", "MeshInstance3D", true, false)
	var generated := 0
	var skipped := 0
	for mesh_node in mesh_nodes:
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance == null or _should_skip(mesh_instance):
			skipped += 1
			continue
		var first_new_child := mesh_instance.get_child_count()
		mesh_instance.create_trimesh_collision()
		if _is_vaultable(mesh_instance):
			for child_index in range(first_new_child, mesh_instance.get_child_count()):
				var collider := mesh_instance.get_child(child_index)
				if collider is StaticBody3D:
					collider.add_to_group("vaultable")
		generated += 1
	is_ready_for_queries = true
	collisions_ready.emit(generated, skipped)
	print("WORLD_COLLISIONS generated=", generated,
		" skipped=", skipped, " mesh_nodes=", mesh_nodes.size())
