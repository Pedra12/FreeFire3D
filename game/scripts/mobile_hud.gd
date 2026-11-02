extends Control

var move_vector: Vector2 = Vector2.ZERO
var jump_pressed: bool = false
var aiming: bool = false
var firing: bool = false
var joystick_touch: int = -1
var joystick_origin: Vector2 = Vector2.ZERO
var joystick_value: Vector2 = Vector2.ZERO
var jump_touch: int = -1
var aim_touch: int = -1
var fire_touch: int = -1

var joystick_center: Vector2
var joystick_radius: float = 82.0
var jump_center: Vector2
var aim_center: Vector2
var fire_center: Vector2
var button_radius: float = 42.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout()
	get_viewport().size_changed.connect(_on_viewport_resized)
	queue_redraw()

func _on_viewport_resized() -> void:
	_layout()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()
		queue_redraw()

func _layout() -> void:
	var s: Vector2 = get_viewport_rect().size
	joystick_center = Vector2(120.0, s.y - 132.0)
	jump_center = Vector2(s.x - 92.0, s.y - 105.0)
	aim_center = Vector2(s.x - 190.0, s.y - 178.0)
	fire_center = Vector2(s.x - 100.0, s.y - 255.0)

func get_move_vector() -> Vector2:
	return move_vector

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_handle_touch_start(event.index, event.position)
		else:
			_handle_touch_end(event.index)
	elif event is InputEventScreenDrag:
		_handle_touch_drag(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_touch_start(99, event.position)
		else:
			_handle_touch_end(99)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_handle_touch_drag(99, event.position)

func _handle_touch_start(id: int, pos: Vector2) -> void:
	if pos.distance_to(joystick_center) < joystick_radius * 1.65 and joystick_touch == -1:
		joystick_touch = id
		joystick_origin = joystick_center
		_update_joystick(pos)
	elif pos.distance_to(jump_center) < button_radius * 1.35 and jump_touch == -1:
		jump_touch = id
		jump_pressed = true
	elif pos.distance_to(aim_center) < button_radius * 1.35 and aim_touch == -1:
		aim_touch = id
		aiming = true
	elif pos.distance_to(fire_center) < button_radius * 1.45 and fire_touch == -1:
		fire_touch = id
		firing = true
	queue_redraw()

func _handle_touch_drag(id: int, pos: Vector2) -> void:
	if id == joystick_touch:
		_update_joystick(pos)
	queue_redraw()

func _handle_touch_end(id: int) -> void:
	if id == joystick_touch:
		joystick_touch = -1
		move_vector = Vector2.ZERO
		joystick_value = Vector2.ZERO
	if id == jump_touch:
		jump_touch = -1
		jump_pressed = false
	if id == aim_touch:
		aim_touch = -1
		aiming = false
	if id == fire_touch:
		fire_touch = -1
		firing = false
	queue_redraw()

func _update_joystick(pos: Vector2) -> void:
	var offset: Vector2 = pos - joystick_origin
	if offset.length() > joystick_radius:
		offset = offset.normalized() * joystick_radius
	joystick_value = offset / joystick_radius
	move_vector = joystick_value

func _draw() -> void:
	draw_circle(joystick_center, joystick_radius, Color(0.03, 0.05, 0.08, 0.30))
	draw_arc(joystick_center, joystick_radius, 0.0, TAU, 64, Color(1, 1, 1, 0.45), 3.0, true)
	draw_circle(joystick_center + joystick_value * joystick_radius, 34.0, Color(0.86, 0.91, 1.0, 0.62))
	_draw_button(jump_center, "PULAR", jump_pressed)
	_draw_button(aim_center, "MIRA", aiming)
	_draw_button(fire_center, "ATIRAR", firing)
	draw_string(ThemeDB.fallback_font, Vector2(28, 42), "Bermuda | Treino", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)

func _draw_button(center: Vector2, label: String, active: bool) -> void:
	var fill: Color = Color(0.18, 0.62, 0.92, 0.78) if active else Color(0.03, 0.05, 0.08, 0.48)
	draw_circle(center, button_radius, fill)
	draw_arc(center, button_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.78), 2.5, true)
	var font: Font = ThemeDB.fallback_font
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(font, center + Vector2(-width * 0.5, 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
