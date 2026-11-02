extends Area3D

@export var item_type: StringName = &"ammo_sniper"
@export var amount: int = 15
@export var display_name: String = "MUNIÇÃO SNIPER"
@export var item_color: Color = Color(0.95, 0.72, 0.22, 1.0)

const WEAPON_MODELS := {
	&"weapon_awm": "res://assets/weapons/awm_free_fire.glb",
	&"weapon_assault_rifle": "res://assets/weapons/assault_rifle.glb",
	&"weapon_smg": "res://assets/weapons/smg.glb",
	&"weapon_shotgun": "res://assets/weapons/shotgun.glb",
	&"weapon_pistol": "res://assets/weapons/pistol.glb"
}

var visual: MeshInstance3D
var weapon_visual: Node3D
var collected: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	var shape := SphereShape3D.new()
	shape.radius = 1.25
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)

	if WEAPON_MODELS.has(item_type):
		_create_weapon_visual()
	else:
		_create_item_visual()

	var label := Label3D.new()
	label.text = display_name
	label.font_size = 30
	label.pixel_size = 0.004
	label.position = Vector3(0.0, 0.88, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	var light := OmniLight3D.new()
	light.light_color = item_color
	light.light_energy = 0.35
	light.omni_range = 2.0
	light.position.y = 0.35
	add_child(light)
	body_entered.connect(_on_body_entered)

func _create_weapon_visual() -> void:
	var model_path: String = WEAPON_MODELS[item_type]
	if not FileAccess.file_exists(model_path):
		push_warning("LOOT: missing weapon model " + model_path)
		_create_item_visual()
		return
	var packed := load(model_path) as PackedScene
	if packed == null:
		_create_item_visual()
		return
	weapon_visual = packed.instantiate() as Node3D
	if weapon_visual == null:
		_create_item_visual()
		return
	add_child(weapon_visual)
	var largest_dimension := 0.0
	for item in weapon_visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := item as MeshInstance3D
		if mesh.mesh != null:
			var bounds := mesh.get_aabb().size
			largest_dimension = maxf(largest_dimension, maxf(bounds.x, maxf(bounds.y, bounds.z)))
	if largest_dimension > 0.000001:
		weapon_visual.scale = Vector3.ONE * (0.72 / largest_dimension)
	weapon_visual.position.y = 0.18
	weapon_visual.rotation.y = deg_to_rad(35.0)

func _create_item_visual() -> void:
	var mesh: Mesh
	if String(item_type).begins_with("ammo_"):
		var ammo_mesh := CylinderMesh.new()
		ammo_mesh.top_radius = 0.15
		ammo_mesh.bottom_radius = 0.15
		ammo_mesh.height = 0.20
		mesh = ammo_mesh
	elif item_type == &"frag_grenade":
		var grenade_mesh := SphereMesh.new()
		grenade_mesh.radius = 0.16
		grenade_mesh.height = 0.32
		mesh = grenade_mesh
	elif item_type == &"helmet":
		var helmet_mesh := SphereMesh.new()
		helmet_mesh.radius = 0.19
		helmet_mesh.height = 0.22
		mesh = helmet_mesh
	else:
		var box := BoxMesh.new()
		box.size = Vector3(0.34, 0.24, 0.34)
		mesh = box
	visual = MeshInstance3D.new()
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = item_color
	material.metallic = 0.18
	material.roughness = 0.32
	material.emission_enabled = true
	material.emission = item_color * 0.22
	visual.material_override = material
	visual.position.y = 0.38
	add_child(visual)

func _process(delta: float) -> void:
	if is_instance_valid(weapon_visual):
		weapon_visual.rotate_y(delta * 0.8)
	if is_instance_valid(visual):
		visual.rotate_y(delta * 1.2)
		visual.position.y = 0.38 + sin(Time.get_ticks_msec() * 0.003) * 0.055

func _on_body_entered(body: Node3D) -> void:
	if collected or not body.is_in_group("player"):
		return
	var hud := body.get_node_or_null("../MobileHUD")
	if WEAPON_MODELS.has(item_type):
		var weapon_id := StringName(String(item_type).trim_prefix("weapon_"))
		var mount := body.get_node_or_null("WeaponMount")
		var combat := body.get_node_or_null("CombatController")
		if mount == null or combat == null:
			return
		if not bool(mount.call("equip_weapon", weapon_id)):
			return
		if not bool(combat.call("equip_weapon", weapon_id)):
			return
		collected = true
		if hud != null and hud.has_method("show_toast"):
			hud.call("show_toast", "Arma equipada: " + display_name)
		queue_free()
		return

	var inventory := body.get_node_or_null("Inventory")
	if inventory == null or not inventory.has_method("add_item"):
		return
	if not inventory.call("add_item", item_type, amount):
		return
	collected = true
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", "Coletado: " + display_name)
	queue_free()
