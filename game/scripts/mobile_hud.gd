extends CanvasLayer

var move_vector: Vector2 = Vector2.ZERO
var jump_pressed: bool = false
var aiming: bool = false
var firing: bool = false
var _joystick_touch: int = -1
var _joystick_origin: Vector2 = Vector2.ZERO
var _joystick_value: Vector2 = Vector2.ZERO
var _jump_touch: int = -1
var _aim_touch: int = -1
var _fire_touch: int = -1

var joystick_center: Vector2
var joystick_radius: float = 82.0
var jump_center: Vector2
var aim_center: Vector2
var fire_center: Vector2
var button_radius: float = 42.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(queue_redraw)
	_layout()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()
		queue_redraw()

func _layout() -> void:
	var s := get_viewport().get_visible_rect().size
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
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_handle_touch_start(99, event.position)
			else:
				_handle_touch_end(99)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_handle_touch_drag(99, event.position)

func _handle_touch_start(id: int, pos: Vector2) -> void:
	if pos.distance_to(joystick_center) < joystick_radius * 1.65 and _joystick_touch == -1:
		_joystick_touch = id
		_joystick_origin = joystick_center
		_update_joystick(pos)
	elif pos.distance_to(jump_center) < button_radius * 1.35:
		_jump_touch = id
		jump_pressed = true
	elif pos.distance_to(aim_center) < button_radius * 1.35:
		_aim_touch = id
		aiming = true
	elif pos.distance_to(fire_center) < button_radius * 1.45:
		_fire_touch = id
		firing = true
	queue_redraw()

func _handle_touch_drag(id: int, pos: Vector2) -> void:
	if id == _joystick_touch:
		_update_joystick(pos)
	queue_redraw()

func _handle_touch_end(id: int) -> void:
	if id == _joystick_touch:
		_joystick_touch = -1
		move_vector = Vector2.ZERO
		_joystick_value = Vector2.ZERO
	if id == _jump_touch:
		_jump_touch = -1
		jump_pressed = false
	if id == _aim_touch:
		_aim_touch = -1
		aiming = false
	if id == _fire_touch:
		_fire_touch = -1
		firing = false
	queue_redraw()

func _update_joystick(pos: Vector2) -> void:
	var offset := pos - _joystick_origin
	if offset.length() > joystick_radius:
		offset = offset.normalized() * joystick_radius
	_joystick_value = offset / joystick_radius
	move_vector = _joystick_value

func _draw() -> void:
	draw_circle(joystick_center, joystick_radius, Color(0.03, 0.05, 0.08, 0.30))
	draw_arc(joystick_center, joystick_radius, 0.0, TAU, 64, Color(1, 1, 1, 0.45), 3.0, true)
	draw_circle(joystick_center + _joystick_value * joystick_radius, 34.0, Color(0.86, 0.91, 1.0, 0.62))
	_draw_button(jump_center, "PULAR", jump_pressed)
	_draw_button(aim_center, "MIRA", aiming)
	_draw_button(fire_center, "ATIRAR", firing)
	draw_string(ThemeDB.fallback_font, Vector2(28, 42), "Bermuda  |  Treino", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)

func _draw_button(center: Vector2, label: String, active: bool) -> void:
	var fill := Color(0.18, 0.62, 0.92, 0.78) if active else Color(0.03, 0.05, 0.08, 0.48)
	draw_circle(center, button_radius, fill)
	draw_arc(center, button_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.78), 2.5, true)
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(font, center + Vector2(-width * 0.5, 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
