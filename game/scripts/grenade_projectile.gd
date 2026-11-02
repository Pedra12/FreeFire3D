extends RigidBody3D

@export var fuse_seconds: float = 2.1
@export var blast_radius: float = 5.5
@export var maximum_damage: float = 95.0
var team_id: int = 0
var source_character: Node3D
var detonated: bool = false

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	mesh.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.20, 0.25, 0.19)
	material.metallic = 0.72
	material.roughness = 0.35
	mesh.material_override = material
	add_child(mesh)
	var shape := CollisionShape3D.new()
	var collision := SphereShape3D.new()
	collision.radius = 0.12
	shape.shape = collision
	add_child(shape)
	await get_tree().create_timer(fuse_seconds).timeout
	if is_inside_tree():
		explode()

func explode() -> void:
	if detonated:
		return
	detonated = true
	var space := get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = blast_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = 1
	query.collide_with_areas = false
	var hits := space.intersect_shape(query, 48)
	var damaged: Dictionary = {}
	for result in hits:
		var target: Object = result.get("collider")
		if not target is Node or not target.is_in_group("damageable"):
			continue
		var id := target.get_instance_id()
		if damaged.has(id):
			continue
		damaged[id] = true
		var target_team := int(target.get("team_id"))
		if target_team == team_id:
			continue
		var distance := (target as Node3D).global_position.distance_to(global_position)
		var falloff := clampf(1.0 - distance / blast_radius, 0.0, 1.0)
		var damage := maximum_damage * falloff
		if damage > 1.0 and target.has_method("apply_damage"):
			target.call("apply_damage", damage, global_position, Vector3.UP, source_character)
	_spawn_blast_visual()
	queue_free()

func _spawn_blast_visual() -> void:
	var effect := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.35
	mesh.height = 0.7
	effect.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.35, 0.08, 0.65)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.2, 0.03)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	effect.material_override = material
	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position
	var tween := effect.create_tween()
	tween.tween_property(effect, "scale", Vector3.ONE * 8.0, 0.24)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.24)
	tween.tween_callback(effect.queue_free)
