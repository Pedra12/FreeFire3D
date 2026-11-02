extends Node

signal ammo_changed(current: int, reserve: int)
signal shot_fired(hit: bool)

@export var damage: float = 68.0
@export var headshot_damage: float = 120.0
@export var fire_interval: float = 0.92
@export var magazine_size: int = 5
@export var starting_reserve: int = 30
@export var reload_duration: float = 2.35
@export var max_distance: float = 220.0
@export var aim_fov: float = 48.0
@export var normal_fov: float = 65.0

@onready var player: CharacterBody3D = get_parent() as CharacterBody3D
@onready var camera: Camera3D = player.get_node("CameraPivot/Camera3D") as Camera3D
@onready var hud: Control = player.get_node("../MobileHUD") as Control
@onready var inventory: Node = player.get_node_or_null("Inventory")

var ammo_in_magazine: int = 5
var reserve_ammo: int = 30
var fire_cooldown: float = 0.0
var reloading: bool = false

func _ready() -> void:
	ammo_in_magazine = magazine_size
	if inventory != null:
		reserve_ammo = int(inventory.get("ammo_762"))
	if is_instance_valid(hud):
		if hud.has_signal("reload_requested"):
			hud.reload_requested.connect(reload)
		if hud.has_method("set_ammo"):
			hud.set_ammo(ammo_in_magazine, reserve_ammo)
	camera.fov = normal_fov

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
		loaded = int(inventory.call("consume_ammo", needed))
	ammo_in_magazine += loaded
	reserve_ammo = int(inventory.get("ammo_762")) if inventory != null else maxi(0, reserve_ammo - loaded)
	reloading = false
	_emit_ammo()

func _fire_once() -> void:
	fire_cooldown = fire_interval
	ammo_in_magazine -= 1
	if player.has_method("play_action_animation"):
		player.play_action_animation(&"Pistol_Shoot")
	_emit_ammo()
	var viewport_size := camera.get_viewport().get_visible_rect().size
	var screen_center := viewport_size * 0.5
	var origin := camera.project_ray_origin(screen_center)
	var direction := camera.project_ray_normal(screen_center)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * max_distance)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	var confirmed_hit := false
	var eliminated := false
	var headshot := false
	var hit_position := origin + direction * 65.0
	if not hit.is_empty():
		hit_position = hit.position
		var collider: Object = hit.get("collider")
		var damage_target: Object = collider
		if collider is Node and not collider.is_in_group("damageable"):
			var parent := (collider as Node).get_parent()
			if parent != null and parent.is_in_group("damageable"):
				damage_target = parent
		if damage_target is Node and damage_target.is_in_group("damageable") and damage_target.has_method("apply_damage"):
			var target_node := damage_target as Node3D
			headshot = hit_position.y >= target_node.global_position.y + 1.35
			var applied_damage := headshot_damage if headshot else damage
			eliminated = bool(damage_target.call("apply_damage", applied_damage, hit_position, hit.normal, player))
			confirmed_hit = true
		_show_tracer(origin, hit_position)
	else:
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

func _emit_ammo() -> void:
	ammo_changed.emit(ammo_in_magazine, reserve_ammo)
	if is_instance_valid(hud) and hud.has_method("set_ammo"):
		hud.set_ammo(ammo_in_magazine, reserve_ammo)
