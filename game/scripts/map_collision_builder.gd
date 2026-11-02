extends Node3D

## Builds collision from the imported world meshes without creating colliders
## for sky, cloud cards, or water surfaces.
@export var generate_collisions: bool = true
@export var skip_material_tokens: PackedStringArray = PackedStringArray(["cloud", "wave", "water", "sky"])

func _ready() -> void:
	if generate_collisions:
		call_deferred("_generate_map_collisions")

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
		mesh_instance.create_trimesh_collision()
		generated += 1
	print("WORLD_COLLISIONS generated=", generated,
		" skipped=", skipped, " mesh_nodes=", mesh_nodes.size())
