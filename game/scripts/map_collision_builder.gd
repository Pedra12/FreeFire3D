extends Node3D

signal collisions_ready(generated: int, skipped: int)

## Builds collision from imported world meshes without creating colliders
## for sky, cloud cards, or water surfaces.
@export var generate_collisions: bool = true
@export var skip_material_tokens: PackedStringArray = PackedStringArray(["cloud", "wave", "water", "sky"])
var is_ready_for_queries: bool = false

func _ready() -> void:
	if generate_collisions:
		call_deferred("_generate_map_collisions")
	else:
		is_ready_for_queries = true

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
		if mesh_instance.name.to_lower().contains("vaultable"):
			for child_index in range(first_new_child, mesh_instance.get_child_count()):
				var collider := mesh_instance.get_child(child_index)
				if collider is StaticBody3D:
					collider.add_to_group("vaultable")
		generated += 1
	is_ready_for_queries = true
	collisions_ready.emit(generated, skipped)
	print("WORLD_COLLISIONS generated=", generated,
		" skipped=", skipped, " mesh_nodes=", mesh_nodes.size())
