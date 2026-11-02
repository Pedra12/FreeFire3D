extends Control

signal reload_requested

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
var reload_touch: int = -1

var joystick_center: Vector2
var joystick_radius: float = 82.0
var jump_center: Vector2
var aim_center: Vector2
var fire_center: Vector2
var reload_center: Vector2
var button_radius: float = 42.0
var ammo_current: int = 30
var ammo_reserve: int = 120
var health_current: float = 100.0
var health_maximum: float = 100.0

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
	reload_center = Vector2(s.x - 285.0, s.y - 105.0)

func get_move_vector() -> Vector2:
	return move_vector

func set_ammo(current: int, reserve: int) -> void:
	ammo_current = current
	ammo_reserve = reserve
	queue_redraw()

func set_health(current: float, maximum: float) -> void:
	health_current = current
	health_maximum = maxf(1.0, maximum)
	queue_redraw()

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
	elif pos.distance_to(reload_center) < button_radius * 1.15 and reload_touch == -1:
		reload_touch = id
		reload_requested.emit()
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
	if id == reload_touch:
		reload_touch = -1
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
	_draw_button(reload_center, "RECARREGAR", false, 34.0)
	draw_string(ThemeDB.fallback_font, Vector2(28, 42), "BERMUDA | SOBREVIVENCIA", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(28, 67), "VIDA %d%%" % int(round(health_current / health_maximum * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_rect(Rect2(28, 75, 180, 10), Color(0.02, 0.03, 0.04, 0.72), true)
	var health_color := Color(0.20, 0.82, 0.36, 0.95) if health_current > 35.0 else Color(0.95, 0.24, 0.16, 0.98)
	draw_rect(Rect2(28, 75, 180.0 * clampf(health_current / health_maximum, 0.0, 1.0), 10), health_color, true)
	var ammo_text := "%02d / %03d" % [ammo_current, ammo_reserve]
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 190.0, 48.0), ammo_text, HORIZONTAL_ALIGNMENT_RIGHT, 160.0, 25, Color.WHITE)
	if aiming:
		var center := size * 0.5
		draw_line(center + Vector2(-10, 0), center + Vector2(-3, 0), Color.WHITE, 2.0)
		draw_line(center + Vector2(3, 0), center + Vector2(10, 0), Color.WHITE, 2.0)
		draw_line(center + Vector2(0, -10), center + Vector2(0, -3), Color.WHITE, 2.0)
		draw_line(center + Vector2(0, 3), center + Vector2(0, 10), Color.WHITE, 2.0)

func _draw_button(center: Vector2, label: String, active: bool, radius: float = 42.0) -> void:
	var fill: Color = Color(0.18, 0.62, 0.92, 0.78) if active else Color(0.03, 0.05, 0.08, 0.48)
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.78), 2.5, true)
	var font: Font = ThemeDB.fallback_font
	var font_size := 15 if radius > 38.0 else 11
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, center + Vector2(-width * 0.5, 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
