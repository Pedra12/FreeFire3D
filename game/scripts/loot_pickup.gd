extends Area3D

@export var item_type: StringName = &"ammo_762"
@export var amount: int = 15
@export var display_name: String = "MUNIÇÃO 7.62"
@export var item_color: Color = Color(0.95, 0.72, 0.22, 1.0)

var visual: MeshInstance3D
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
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.34, 0.24, 0.34)
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
	var label := Label3D.new()
	label.text = display_name
	label.font_size = 30
	label.pixel_size = 0.004
	label.position = Vector3(0.0, 0.78, 0.0)
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

func _process(delta: float) -> void:
	if is_instance_valid(visual):
		visual.rotate_y(delta * 1.2)
		visual.position.y = 0.38 + sin(Time.get_ticks_msec() * 0.003) * 0.055

func _on_body_entered(body: Node3D) -> void:
	if collected or not body.is_in_group("player"):
		return
	var inventory := body.get_node_or_null("Inventory")
	if inventory == null or not inventory.has_method("add_item"):
		return
	if not inventory.call("add_item", item_type, amount):
		return
	collected = true
	var hud := body.get_node_or_null("../MobileHUD")
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", "Coletado: " + display_name)
	queue_free()
