extends Node3D

## Builds static triangle-mesh collision for the imported Bermuda geometry.
## This keeps the original terrain relief and all building shapes intact.
@export var generate_collisions: bool = true

func _ready() -> void:
	if generate_collisions:
		call_deferred("_generate_map_collisions")

func _generate_map_collisions() -> void:
	var mesh_nodes := find_children("*", "MeshInstance3D", true, false)
	var generated := 0
	var skipped := 0

	for mesh_node in mesh_nodes:
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			skipped += 1
			continue
		if mesh_instance.mesh.get_surface_count() == 0:
			skipped += 1
			continue

		# Concave static collision follows the source mesh rather than flattening
		# the terrain into a box or plane. Suitable for static environment geometry.
		mesh_instance.create_trimesh_collision()
		generated += 1

	print("BERMUDA_COLLISIONS generated=", generated,
		" skipped=", skipped,
		" mesh_nodes=", mesh_nodes.size())
