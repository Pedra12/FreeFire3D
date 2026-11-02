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

func _load_pbr_texture(maps: Dictionary, map_name: String) -> Texture2D:
	var entry: Dictionary = maps.get(map_name, {})
	var file_path := String(entry.get("file", ""))
	if file_path.is_empty():
		return null
	if file_path.begins_with("game/"):
		file_path = "res://" + file_path.substr(5)
	var texture := load(file_path) as Texture2D
	if texture == null:
		push_warning("PBR_GROUND: texture not imported: " + file_path)
	return texture

func _apply_ground_pbr() -> void:
	const MANIFEST_PATH := "res://assets/textures/pbr/manifest.json"
	if not FileAccess.file_exists(MANIFEST_PATH):
		print("PBR_GROUND_SKIPPED: no material manifest")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		push_warning("PBR_GROUND: invalid texture manifest")
		return
	var assets: Dictionary = parsed.get("assets", {})
	var ground_data: Dictionary = assets.get("ground", {})
	var maps: Dictionary = ground_data.get("maps", {})
	var albedo := _load_pbr_texture(maps, "basecolor")
	if albedo == null:
		push_warning("PBR_GROUND: 2K base color missing")
		return
	var ground := find_child("Object_15", true, false) as MeshInstance3D
	if ground == null or ground.mesh == null:
		push_warning("PBR_GROUND: terrain mesh Object_15 not found")
		return
	var material := StandardMaterial3D.new()
	material.albedo_texture = albedo
	material.roughness = 0.92
	material.metallic = 0.0
	material.uv1_scale = Vector3(22.0, 22.0, 1.0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var normal := _load_pbr_texture(maps, "normal")
	if normal != null:
		material.normal_enabled = true
		material.normal_texture = normal
		material.normal_scale = 0.72
	var roughness := _load_pbr_texture(maps, "roughness")
	if roughness != null:
		material.roughness_texture = roughness
	var ao := _load_pbr_texture(maps, "ao")
	if ao != null:
		material.ao_enabled = true
		material.ao_texture = ao
	ground.material_override = material
	print("PBR_GROUND_APPLIED: ", ground_data.get("name", "ground"), " maps=", maps.keys())

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
