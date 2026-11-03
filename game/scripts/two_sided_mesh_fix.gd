extends Node
## Applies two-sided rendering to imported meshes without mutating shared imported resources.
@export var include_groups: Array[StringName] = [&"player", &"bots"]
@export var scan_interval := 2.0
var _elapsed := 0.0
var _seen: Dictionary = {}

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
	if root is MeshInstance3D:
		_fix_mesh(root as MeshInstance3D)
	for child in root.get_children():
		_scan_tree(child)

func _fix_mesh(mesh_node: MeshInstance3D) -> void:
	var mesh := mesh_node.mesh
	if mesh == null:
		return
	for surface in range(mesh.get_surface_count()):
		var material: Material = mesh_node.get_active_material(surface)
		if material == null:
			material = mesh.surface_get_material(surface)
		if material is StandardMaterial3D:
			var standard := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
			standard.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh_node.set_surface_override_material(surface, standard)
		elif material is BaseMaterial3D:
			var base := (material as BaseMaterial3D).duplicate() as BaseMaterial3D
			base.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh_node.set_surface_override_material(surface, base)
