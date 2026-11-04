extends Node

signal ammo_changed(current: int, reserve: int)
signal shot_fired(hit: bool)

@export var damage: float = 80.0
@export var headshot_damage: float = 150.0
@export var fire_interval: float = 1.0
@export var magazine_size: int = 5
@export var starting_reserve: int = 20
@export var reload_duration: float = 2.35
@export var max_distance: float = 220.0
@export var aim_fov: float = 42.0
@export var normal_fov: float = 65.0

const WEAPON_CONFIGS := {
	&"awm": {
		"name": "AWM", "ammo": &"ammo_sniper", "magazine": 5,
		"damage": 80.0, "headshot": 150.0, "interval": 1.0,
		"reload": 2.5, "range": 220.0, "aim_fov": 42.0,
		"pellets": 1, "spread": 0.0
	},
	&"assault_rifle": {
		"name": "RIFLE", "ammo": &"ammo_556", "magazine": 30,
		"damage": 28.0, "headshot": 52.0, "interval": 0.105,
		"reload": 2.0, "range": 160.0, "aim_fov": 50.0,
		"pellets": 1, "spread": 0.004
	},
	&"smg": {
		"name": "SMG", "ammo": &"ammo_9mm", "magazine": 32,
		"damage": 20.0, "headshot": 38.0, "interval": 0.075,
		"reload": 1.65, "range": 85.0, "aim_fov": 52.0,
		"pellets": 1, "spread": 0.012
	},
	&"shotgun": {
		"name": "12G", "ammo": &"ammo_12g", "magazine": 6,
		"damage": 9.0, "headshot": 12.0, "interval": 0.82,
		"reload": 2.4, "range": 38.0, "aim_fov": 52.0,
		"pellets": 8, "spread": 0.055
	},
	&"pistol": {
		"name": "PISTOLA", "ammo": &"ammo_9mm", "magazine": 12,
		"damage": 24.0, "headshot": 44.0, "interval": 0.23,
		"reload": 1.45, "range": 75.0, "aim_fov": 54.0,
		"pellets": 1, "spread": 0.008
	}
}

@onready var player: CharacterBody3D = get_parent() as CharacterBody3D
@onready var camera: Camera3D = player.get_node("CameraPivot/Camera3D") as Camera3D
@onready var hud: Control = player.get_node("../MobileHUD") as Control
@onready var inventory: Node = player.get_node_or_null("Inventory")

var current_weapon_id: StringName = &"awm"
var current_weapon_name: String = "AWM"
var current_ammo_type: StringName = &"ammo_sniper"
var pellets_per_shot: int = 1
var spread_amount: float = 0.0
var ammo_in_magazine: int = 5
var reserve_ammo: int = 20
var fire_cooldown: float = 0.0
var reloading: bool = false

func _ready() -> void:
	if inventory != null and inventory.has_signal("inventory_changed"):
		inventory.connect("inventory_changed", _on_inventory_changed)
	equip_weapon(&"awm")
	if is_instance_valid(hud):
		if hud.has_signal("reload_requested"):
			hud.reload_requested.connect(reload)
	camera.fov = normal_fov

func equip_weapon(weapon_id: StringName) -> bool:
	if not WEAPON_CONFIGS.has(weapon_id):
		push_warning("COMBAT: weapon configuration missing: " + String(weapon_id))
		return false
	var config: Dictionary = WEAPON_CONFIGS[weapon_id]
	current_weapon_id = weapon_id
	current_weapon_name = String(config["name"])
	current_ammo_type = config["ammo"]
	magazine_size = int(config["magazine"])
	damage = float(config["damage"])
	headshot_damage = float(config["headshot"])
	fire_interval = float(config["interval"])
	reload_duration = float(config["reload"])
	max_distance = float(config["range"])
	aim_fov = float(config["aim_fov"])
	pellets_per_shot = int(config["pellets"])
	spread_amount = float(config["spread"])
	ammo_in_magazine = magazine_size
	reserve_ammo = int(inventory.call("get_ammo", current_ammo_type)) if inventory != null else 0
	reloading = false
	fire_cooldown = 0.0
	_emit_ammo()
	print("WEAPON_EQUIPPED id=", current_weapon_id, " ammo=", current_ammo_type, " magazine=", magazine_size)
	return true

func _physics_process(delta: float) -> void:
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	var aiming := false
	if is_instance_valid(hud):
		aiming = hud.get("aiming") == true
	camera.fov = lerpf(camera.fov, aim_fov if aiming else normal_fov, 1.0 - exp(-12.0 * delta))
	if reloading or not is_instance_valid(hud):
		return
	if hud.get("firing") == true and fire_cooldown <= 0.0:
		if ammo_in_magazine > 0:
			_fire_once()
		elif reserve_ammo > 0:
			reload()

func reload() -> void:
	if reloading or ammo_in_magazine >= magazine_size or reserve_ammo <= 0:
		return
	reloading = true
	if player.has_method("play_action_animation"):
		player.play_action_animation(&"Pistol_Reload")
	await get_tree().create_timer(reload_duration).timeout
	if not is_inside_tree():
		return
	var needed := magazine_size - ammo_in_magazine
	var loaded := needed
	if inventory != null:
		loaded = int(inventory.call("consume_ammo", needed, current_ammo_type))
	ammo_in_magazine += loaded
	reserve_ammo = int(inventory.call("get_ammo", current_ammo_type)) if inventory != null else maxi(0, reserve_ammo - loaded)
	reloading = false
	_emit_ammo()

func _shoot_animation_for_weapon() -> StringName:\n\tvar choices: Array[StringName] = [&"Rifle_Shoot", &"Assault_Rifle_Shoot", &"Pistol_Shoot"]\n\tmatch current_weapon_id:\n\t\t&"awm": choices = [&"Sniper_Shoot", &"Rifle_Shoot", &"Pistol_Shoot"]\n\t\t&"shotgun": choices = [&"Shotgun_Shoot", &"Rifle_Shoot", &"Pistol_Shoot"]\n\t\t&"smg": choices = [&"SMG_Shoot", &"Rifle_Shoot", &"Pistol_Shoot"]\n\tfor clip in choices:\n\t\tif player.animation_player != null and player.animation_player.has_animation(clip): return clip\n\treturn &"Pistol_Shoot"\n\nfunc _fire_once() -> void:
	fire_cooldown = fire_interval
	ammo_in_magazine -= 1
	if player.has_method("play_action_animation"):
		player.play_action_animation(_shoot_animation_for_weapon())
	_emit_ammo()

	var viewport_size := camera.get_viewport().get_visible_rect().size
	var screen_center := viewport_size * 0.5
	var origin := camera.project_ray_origin(screen_center)
	var base_direction := camera.project_ray_normal(screen_center)
	var confirmed_hit := false
	var eliminated := false
	var headshot := false
	var hit_position := origin + base_direction * max_distance
	var nearest_distance := max_distance
	var damage_by_target: Dictionary = {}

	for pellet_index in range(pellets_per_shot):
		var direction := base_direction
		if spread_amount > 0.0:
			direction = (base_direction + Vector3(
				randf_range(-spread_amount, spread_amount),
				randf_range(-spread_amount, spread_amount),
				randf_range(-spread_amount, spread_amount)
			)).normalized()
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * max_distance)
		query.exclude = [player.get_rid()]
		query.collide_with_areas = false
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var candidate_position: Vector3 = hit.position
		var distance_to_hit := origin.distance_to(candidate_position)
		if distance_to_hit < nearest_distance:
			nearest_distance = distance_to_hit
			hit_position = candidate_position
		var collider: Object = hit.get("collider")
		var damage_target: Object = collider
		if collider is Node and not collider.is_in_group("damageable"):
			var parent := (collider as Node).get_parent()
			if parent != null and parent.is_in_group("damageable"):
				damage_target = parent
		if damage_target is Node and damage_target.is_in_group("damageable") and damage_target.has_method("apply_damage"):
			var target_node := damage_target as Node3D
			var is_headshot := candidate_position.y >= target_node.global_position.y + 1.35
			var applied_damage := headshot_damage if is_headshot else damage
			var before_health := _read_target_health(damage_target)
			var damage_result: Variant = damage_target.call("apply_damage", applied_damage, candidate_position, hit.normal, player)
			var after_health := _read_target_health(damage_target)
			var actual_damage := maxf(0.0, before_health - after_health) if before_health >= 0.0 and after_health >= 0.0 else 0.0
			if actual_damage > 0.01:
				var target_key := damage_target.get_instance_id()
				var damage_data: Dictionary = damage_by_target.get(target_key, {"damage": 0.0, "position": candidate_position, "headshot": false})
				damage_data["damage"] = float(damage_data["damage"]) + actual_damage
				damage_data["position"] = candidate_position
				damage_data["headshot"] = bool(damage_data["headshot"]) or is_headshot
				damage_by_target[target_key] = damage_data
				confirmed_hit = true
				headshot = headshot or is_headshot
				eliminated = eliminated or damage_result == true

	for damage_data in damage_by_target.values():
		_show_damage_number(float(damage_data["damage"]), damage_data["position"], bool(damage_data["headshot"]))
	_show_tracer(origin, hit_position)
	if is_instance_valid(hud):
		hud.call("show_hitmarker", confirmed_hit, eliminated, headshot)
	shot_fired.emit(confirmed_hit)

func _show_tracer(start: Vector3, finish: Vector3) -> void:
	var line := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.82, 0.38, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.48, 0.12, 1.0)
	material.no_depth_test = true
	line.surface_begin(Mesh.PRIMITIVE_LINES, material)
	line.surface_add_vertex(start)
	line.surface_add_vertex(finish)
	line.surface_end()
	var visual := MeshInstance3D.new()
	visual.mesh = line
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.get_tree().current_scene.add_child(visual)
	await get_tree().create_timer(0.055).timeout
	if is_instance_valid(visual):
		visual.queue_free()

func _on_inventory_changed(_snapshot: Dictionary) -> void:
	if inventory == null:
		return
	reserve_ammo = int(inventory.call("get_ammo", current_ammo_type))
	_emit_ammo()

func _read_target_health(target: Node) -> float:
	if not is_instance_valid(target):
		return -1.0
	var direct_health: Variant = target.get("health")
	if direct_health != null:
		return float(direct_health)
	var health_component := target.get_node_or_null("Health")
	if health_component != null:
		return float(health_component.get("current_health"))
	return -1.0

func _show_damage_number(amount: float, at: Vector3, is_headshot: bool) -> void:
	var label := Label3D.new()
	label.text = str(roundi(amount)) + ("!" if is_headshot else "")
	label.font_size = 48 if is_headshot else 42
	label.pixel_size = 0.0035
	label.modulate = Color(1.0, 0.78, 0.22, 1.0) if is_headshot else Color(1.0, 1.0, 1.0, 1.0)
	label.outline_size = 8
	label.outline_modulate = Color(0.025, 0.025, 0.035, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	var scene := get_tree().current_scene
	if scene == null:
		return
	scene.add_child(label)
	label.global_position = at + Vector3.UP * 0.35
	var tween := label.create_tween()
	tween.tween_property(label, "global_position", label.global_position + Vector3.UP * 0.8, 0.62)
	tween.parallel().tween_property(label, "modulate", Color(label.modulate.r, label.modulate.g, label.modulate.b, 0.0), 0.62)
	tween.tween_callback(label.queue_free)

func _emit_ammo() -> void:
	ammo_changed.emit(ammo_in_magazine, reserve_ammo)
	if is_instance_valid(hud) and hud.has_method("set_ammo"):
		hud.call("set_ammo", ammo_in_magazine, reserve_ammo, current_weapon_name)
