extends Node
## Normalizes imported mesh surfaces for reliable mobile and headless rendering.
## Never mutates shared imported materials: every override is a local duplicate.
@export var include_groups: Array[StringName] = [&"player", &"bots"]
@export var scan_interval := 2.0
var _elapsed := 0.0
var _seen: Dictionary = {}
var _fixed_surfaces := 0
var _fallback_surfaces := 0

func _ready() -> void:
	_scan_tree(get_tree().current_scene)
	get_tree().node_added.connect(_on_node_added)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= scan_interval:
		_elapsed = 0.0
		_scan_tree(get_tree().current_scene)

func _on_node_added(node: Node) -> void:
	call_deferred("_scan_tree", node)

func _scan_tree(root: Node) -> void:
	if not is_instance_valid(root):
		return
	var before_fixed := _fixed_surfaces
	var before_fallback := _fallback_surfaces
	if root is MeshInstance3D:
		_fix_mesh(root as MeshInstance3D)
	for child in root.get_children():
		_scan_tree(child)
	if _fixed_surfaces > before_fixed or _fallback_surfaces > before_fallback:
		print("TWO_SIDED_MATERIALS_OK fixed=", _fixed_surfaces, " fallback=", _fallback_surfaces)

func _fix_mesh(mesh_node: MeshInstance3D) -> void:
	if not is_instance_valid(mesh_node) or mesh_node.mesh == null:
		return
	var mesh_id := mesh_node.get_instance_id()
	if _seen.has(mesh_id):
		return
	var mesh := mesh_node.mesh
	for surface in range(mesh.get_surface_count()):
		var material: Material = mesh_node.get_active_material(surface)
		if material == null:
			material = mesh.surface_get_material(surface)
		var safe_material: BaseMaterial3D
		if material is BaseMaterial3D:
			safe_material = (material as BaseMaterial3D).duplicate() as BaseMaterial3D
		elif material is Material:
			# Preserve custom imported shaders instead of replacing them.
			continue
		else:
			# A null surface material can trigger RenderingServer errors in the
			# headless/mobile renderer. Give only that empty surface a neutral fallback.
			var fallback := StandardMaterial3D.new()
			fallback.albedo_color = Color(0.72, 0.72, 0.72, 1.0)
			fallback.roughness = 0.88
			safe_material = fallback
			_fallback_surfaces += 1
		safe_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh_node.set_surface_override_material(surface, safe_material)
		_fixed_surfaces += 1
	_seen[mesh_id] = true
