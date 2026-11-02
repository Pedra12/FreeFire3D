extends CharacterBody3D

@export var walk_speed: float = 4.8
@export var sprint_speed: float = 7.2
@export var jump_velocity: float = 5.2
@export var turn_speed: float = 11.0
@export var camera_distance: float = 4.6
@export var camera_height: float = 1.8

@onready var visual: Node3D = $VisualRoot
@onready var model: Node3D = $VisualRoot/FemalePlayer
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var hud: Control = get_node("../MobileHUD") as Control

var animation_player: AnimationPlayer
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var camera_yaw: float = 0.0
var camera_pitch: float = -0.12
var camera_touch_id: int = -1
var mouse_look: bool = false
var jump_was_down: bool = false
var current_animation: StringName = &""

func _ready() -> void:
	add_to_group("player")
	animation_player = model.find_child("*", true, false) as AnimationPlayer
	if animation_player == null:
		for child in model.get_children():
			if child is AnimationPlayer:
				animation_player = child
				break
	camera.current = true
	camera_pivot.position = Vector3(0.0, camera_height, 0.0)
	camera.position = Vector3(0.0, 0.0, camera_distance)
	camera_pivot.rotation.y = camera_yaw
	camera_pivot.rotation.x = camera_pitch
	await _find_ground_and_place()
	_play_first_available([&"Idle", &"idle", &"Idle_Rifle"])

func _find_ground_and_place() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
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
		if event.pressed and event.position.x > screen.x * 0.48:
			camera_touch_id = event.index
		elif not event.pressed and event.index == camera_touch_id:
			camera_touch_id = -1
	elif event is InputEventScreenDrag and event.index == camera_touch_id:
		_rotate_camera(event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_look = event.pressed
	elif event is InputEventMouseMotion and mouse_look:
		_rotate_camera(event.relative)
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

func _rotate_camera(delta: Vector2) -> void:
	camera_yaw -= delta.x * 0.006
	camera_pitch = clampf(camera_pitch - delta.y * 0.0035, -0.45, 0.42)

func _physics_process(delta: float) -> void:
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
		aiming = bool(hud.get("aiming"))
		jump_now = bool(hud.get("jump_pressed"))
	var sprinting: bool = move_input.length() > 0.72 and not aiming
	var target_speed: float = sprint_speed if sprinting else walk_speed

	if direction.length() > 0.01:
		velocity.x = direction.x * target_speed
		velocity.z = direction.z * target_speed
		if not aiming:
			var target_angle: float = atan2(direction.x, direction.z)
			visual.rotation.y = lerp_angle(visual.rotation.y, target_angle, turn_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * 7.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed * 7.0 * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif jump_now and not jump_was_down:
		velocity.y = jump_velocity
		_play_first_available([&"Jump_Start", &"Jump", &"jump"])
	jump_was_down = jump_now
	move_and_slide()

	if not is_on_floor():
		if velocity.y < -0.5:
			_play_first_available([&"Jump_Land", &"Land", &"Fall"])
		elif velocity.y > 0.2:
			_play_first_available([&"Jump", &"Jump_Loop", &"Fall"])
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
	camera.look_at(camera_pivot.global_position + (-camera_pivot.global_transform.basis.z * 5.0), Vector3.UP)

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
