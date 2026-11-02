extends CharacterBody3D

@export var walk_speed: float = 4.8
@export var sprint_speed: float = 7.2
@export var jump_velocity: float = 5.2
@export var turn_speed: float = 11.0
@export var camera_distance: float = 3.4
@export var camera_height: float = 1.65
@export var team_id: int = 0

@onready var visual: Node3D = $VisualRoot
@onready var model: Node3D = $VisualRoot/Olivia
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var hud: Control = get_node("../MobileHUD") as Control
@onready var inventory: Node = get_node_or_null("Inventory")

var animation_player: AnimationPlayer
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var camera_yaw: float = 0.0
var camera_pitch: float = -0.06
var camera_touch_id: int = -1
var mouse_look: bool = false
var jump_was_down: bool = false
var current_animation: StringName = &""
var action_animation_locked: bool = false
var footstep_clock: float = 0.0
var last_grounded: bool = true
var vault_cooldown: float = 0.0

func _ready() -> void:
	add_to_group("player")
	add_to_group("combatants")
	add_to_group("damageable")
	if inventory != null and inventory.has_signal("inventory_changed"):
		inventory.inventory_changed.connect(_on_inventory_changed)
	if is_instance_valid(hud):
		if hud.has_signal("grenade_requested"):
			hud.grenade_requested.connect(throw_grenade)
		if hud.has_signal("medkit_requested"):
			hud.medkit_requested.connect(use_medkit)
	var animation_nodes := model.find_children("*", "AnimationPlayer", true, false)
	if not animation_nodes.is_empty():
		animation_player = animation_nodes[0] as AnimationPlayer
	if animation_player != null:
		animation_player.animation_finished.connect(_on_animation_finished)
	camera.current = true
	camera_pivot.position = Vector3(0.0, camera_height, 0.0)
	camera.position = Vector3(0.0, 0.0, camera_distance)
	camera.fov = 65.0
	camera_pivot.rotation.y = camera_yaw
	camera_pivot.rotation.x = camera_pitch
	await _find_ground_and_place()
	_play_first_available([&"Idle_Rifle", &"Idle", &"idle"])
	_on_inventory_changed(inventory.call("get_snapshot") if inventory != null else {})

func _find_ground_and_place() -> void:
	var map_node := get_parent().get_node_or_null("Map")
	var waited := 0
	while map_node != null and not bool(map_node.get("is_ready_for_queries")) and waited < 600:
		await get_tree().physics_frame
		waited += 1
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 35.0, global_position + Vector3.DOWN * 100.0)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position + Vector3.UP * 0.70
	else:
		global_position = Vector3(0.0, 5.0, 0.0)

func _unhandled_input(event: InputEvent) -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x > screen.x * 0.48 and (not is_instance_valid(hud) or not hud.call("is_touch_on_control", event.position)):
			camera_touch_id = event.index
		elif not event.pressed and event.index == camera_touch_id:
			camera_touch_id = -1
	elif event is InputEventScreenDrag and event.index == camera_touch_id:
		_rotate_camera(event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_look = event.pressed and (not is_instance_valid(hud) or not hud.call("is_touch_on_control", event.position))
	elif event is InputEventMouseMotion and mouse_look:
		_rotate_camera(event.relative)
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

func _rotate_camera(delta: Vector2) -> void:
	camera_yaw -= delta.x * 0.006
	camera_pitch = clampf(camera_pitch - delta.y * 0.0035, -0.45, 0.42)

func _physics_process(delta: float) -> void:
	vault_cooldown = maxf(0.0, vault_cooldown - delta)
	var move_input: Vector2 = Vector2.ZERO
	if is_instance_valid(hud):
		move_input = hud.get_move_vector()
	if move_input.length() > 1.0:
		move_input = move_input.normalized()

	var basis: Basis = camera_pivot.global_transform.basis
	var forward: Vector3 = -basis.z
	var right: Vector3 = basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	var direction: Vector3 = (right * move_input.x + forward * -move_input.y).normalized()

	var aiming: bool = false
	var jump_now: bool = false
	if is_instance_valid(hud):
		aiming = hud.get("aiming") == true
		jump_now = hud.get("jump_pressed") == true
	var sprinting: bool = move_input.length() > 0.72 and not aiming
	var target_speed: float = sprint_speed if sprinting else walk_speed

	if direction.length() > 0.01:
		velocity.x = direction.x * target_speed
		velocity.z = direction.z * target_speed
		var facing_direction := forward if aiming else direction
		var target_angle: float = atan2(facing_direction.x, facing_direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_angle, turn_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * 7.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed * 7.0 * delta)
		if aiming:
			var aim_angle := atan2(forward.x, forward.z)
			visual.rotation.y = lerp_angle(visual.rotation.y, aim_angle, turn_speed * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif jump_now and not jump_was_down:
		if not _try_window_vault(forward):
			velocity.y = jump_velocity
			_play_first_available([&"Jump_Start", &"Jump", &"jump"])
	jump_was_down = jump_now
	move_and_slide()

	if direction.length() > 0.08 and is_on_floor():
		footstep_clock -= delta
		if footstep_clock <= 0.0:
			_play_footstep()
			footstep_clock = 0.34 if sprinting else 0.48
	else:
		footstep_clock = minf(footstep_clock, 0.12)

	if not action_animation_locked:
		if not is_on_floor():
			if velocity.y > 0.2:
				_play_first_available([&"Jump", &"Jump_Loop", &"Fall"])
			elif velocity.y < -0.5:
				_play_first_available([&"Fall", &"Jump_Loop"])
		elif direction.length() > 0.08:
			if sprinting:
				_play_first_available([&"Sprint", &"Run", &"Run_F"])
			else:
				_play_first_available([&"Walk", &"Walk_F", &"Walk_Forward"])
		else:
			if aiming:
				_play_first_available([&"Pistol_Aim_Neutral", &"Rifle_Aim_Idle", &"Idle"])
			else:
				_play_first_available([&"Idle", &"idle", &"Idle_Rifle"])

	camera_pivot.global_position = camera_pivot.global_position.lerp(global_position + Vector3.UP * camera_height, 1.0 - exp(-10.0 * delta))
	camera_pivot.rotation.y = camera_yaw
	camera_pivot.rotation.x = camera_pitch
	camera.position = camera.position.lerp(Vector3(0.0, 0.0, camera_distance), 1.0 - exp(-8.0 * delta))
	camera.look_at(global_position + Vector3.UP * 1.25 + forward * 8.0, Vector3.UP)

func _try_window_vault(forward: Vector3) -> bool:
	if vault_cooldown > 0.0 or forward.length() < 0.1:
		return false
	var start := global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(start, start + forward * 1.15)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var obstacle: Object = hit.get("collider")
	if not obstacle is Node or not (obstacle as Node).is_in_group("vaultable"):
		return false
	var landing := global_position + forward * 1.45
	var ground_query := PhysicsRayQueryParameters3D.create(landing + Vector3.UP * 2.0, landing + Vector3.DOWN * 2.0)
	ground_query.exclude = [get_rid()]
	var ground_hit := get_world_3d().direct_space_state.intersect_ray(ground_query)
	if ground_hit.is_empty() or absf(float(ground_hit.position.y) - global_position.y) > 0.85:
		return false
	var head_query := PhysicsRayQueryParameters3D.create(landing + Vector3.UP * 0.9, landing + Vector3.UP * 2.0)
	head_query.exclude = [get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(head_query).is_empty():
		return false
	global_position = ground_hit.position + Vector3.UP * 0.70
	velocity = forward * 1.5
	vault_cooldown = 0.8
	_play_action_animation([&"Vault_Window", &"Vault", &"Jump"])
	return true

func apply_damage(amount: float, _hit_position: Vector3 = Vector3.ZERO, _hit_normal: Vector3 = Vector3.UP, source: Node = null) -> bool:
	var health := get_node_or_null("Health")
	if health == null:
		return false
	return bool(health.call("apply_damage", amount, source))

func throw_grenade() -> void:
	if inventory == null or not inventory.call("consume_grenade"):
		if is_instance_valid(hud): hud.call("show_toast", "Sem granadas")
		return
	var grenade := RigidBody3D.new()
	grenade.set_script(load("res://scripts/grenade_projectile.gd"))
	grenade.set("team_id", team_id)
	grenade.set("source_character", self)
	get_tree().current_scene.add_child(grenade)
	var direction := -camera.global_transform.basis.z.normalized()
	grenade.global_position = global_position + Vector3.UP * 1.25 + direction * 0.7
	grenade.linear_velocity = direction * 13.0 + Vector3.UP * 4.5
	if is_instance_valid(hud): hud.call("show_toast", "Granada lançada")

func use_medkit() -> void:
	if inventory == null or not inventory.call("use_medkit"):
		if is_instance_valid(hud): hud.call("show_toast", "Kit médico indisponível")
		return
	if is_instance_valid(hud): hud.call("show_toast", "Kit médico utilizado")

func _toggle_inventory() -> void:
	if is_instance_valid(hud):
		hud.call("toggle_inventory")

func _on_inventory_changed(snapshot: Dictionary) -> void:
	if is_instance_valid(hud) and hud.has_method("set_inventory"):
		hud.call("set_inventory", snapshot)

func _play_footstep() -> void:
	var player := get_node_or_null("FootstepAudio") as AudioStreamPlayer3D
	if player != null and player.stream != null:
		player.pitch_scale = randf_range(0.94, 1.06)
		player.play()

func play_action_animation(animation_name: StringName) -> void:
	_play_action_animation([animation_name])

func _play_action_animation(names: Array[StringName]) -> void:
	if animation_player == null:
		return
	for animation_name in names:
		if animation_player.has_animation(animation_name):
			if action_animation_locked and animation_player.is_playing():
				return
			action_animation_locked = true
			current_animation = animation_name
			animation_player.play(animation_name, 0.06)
			return

func _on_animation_finished(animation_name: StringName) -> void:
	if action_animation_locked and animation_name == current_animation:
		action_animation_locked = false

func _play_first_available(names: Array[StringName]) -> void:
	if animation_player == null:
		return
	for animation_name in names:
		if animation_player.has_animation(animation_name):
			if current_animation == animation_name and animation_player.is_playing():
				return
			current_animation = animation_name
			animation_player.play(animation_name, 0.18)
			return
