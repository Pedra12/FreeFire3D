extends StaticBody3D

signal eliminated

@export var max_health: float = 100.0
var health: float = 100.0
var mesh_instance: MeshInstance3D
var base_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("damageable")
	health = max_health
	mesh_instance = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance != null:
		var material := mesh_instance.get_active_material(0)
		if material is StandardMaterial3D:
			base_material = material.duplicate() as StandardMaterial3D
			mesh_instance.set_surface_override_material(0, base_material)

func apply_damage(amount: float, hit_position: Vector3 = Vector3.ZERO, hit_normal: Vector3 = Vector3.UP, source: Node = null) -> bool:
	if health <= 0.0 or amount <= 0.0:
		return false
	if is_instance_valid(source) and source.get("team_id") != null and get("team_id") != null and int(source.get("team_id")) == int(get("team_id")):
		return false
	health = maxf(0.0, health - amount)
	if mesh_instance != null and base_material != null:
		var flash := base_material.duplicate() as StandardMaterial3D
		flash.albedo_color = Color(1.0, 0.22, 0.12, 1.0)
		mesh_instance.set_surface_override_material(0, flash)
		await get_tree().create_timer(0.08).timeout
		if is_instance_valid(mesh_instance) and health > 0.0:
			mesh_instance.set_surface_override_material(0, base_material)
	if health <= 0.0:
		eliminated.emit()
		queue_free()
		return true
	return false
