extends Node3D

@export var orbit_distance: float = 190.0
@export_range(15.0, 75.0, 1.0) var pitch_degrees: float = 36.0
@export var touch_sensitivity: float = 0.004

@onready var camera: Camera3D = $Camera3D

var yaw: float = 0.0
var look_touch_id: int = -1
var mouse_look_active: bool = false

func _ready() -> void:
	_update_camera()

func _input(event: InputEvent) -> void:
	var screen_size := get_viewport().get_visible_rect().size

	if event is InputEventScreenTouch:
		if event.pressed and event.position.x >= screen_size.x * 0.45:
			look_touch_id = event.index
		elif not event.pressed and event.index == look_touch_id:
			look_touch_id = -1

	elif event is InputEventScreenDrag and event.index == look_touch_id:
		_apply_look_delta(event.relative)

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_look_active = event.pressed

	elif event is InputEventMouseMotion and mouse_look_active:
		_apply_look_delta(event.relative)

func _apply_look_delta(delta: Vector2) -> void:
	yaw -= delta.x * touch_sensitivity
	pitch_degrees = clampf(pitch_degrees + delta.y * touch_sensitivity * 100.0, 18.0, 68.0)
	_update_camera()

func _update_camera() -> void:
	rotation.y = yaw
	var pitch := deg_to_rad(pitch_degrees)
	camera.position = Vector3(0.0, sin(pitch) * orbit_distance, cos(pitch) * orbit_distance)
	camera.look_at(Vector3.ZERO, Vector3.UP)
