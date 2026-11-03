extends Control

signal reload_requested
signal grenade_requested
signal medkit_requested
signal inventory_requested

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
var grenade_touch: int = -1
var medkit_touch: int = -1
var inventory_touch: int = -1

var joystick_center: Vector2
var joystick_radius: float = 82.0
var jump_center: Vector2
var aim_center: Vector2
var fire_center: Vector2
var reload_center: Vector2
var grenade_center: Vector2
var medkit_center: Vector2
var inventory_center: Vector2
var button_radius: float = 42.0
var ammo_current: int = 5
var ammo_reserve: int = 20
var weapon_label: String = "AWM"
var health_current: float = 100.0
var health_maximum: float = 100.0
var inventory_snapshot: Dictionary = {}
var inventory_open: bool = false
var match_status: String = "AZUL 4  |  4 VERMELHO"
var score_text: String = "0 x 0"
var round_info: String = "ROUND 1"
var toast_text: String = ""
var toast_timer: float = 0.0
var hitmarker_timer: float = 0.0
var hitmarker_kill: bool = false
var hitmarker_headshot: bool = false
var result_text: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout()
	get_viewport().size_changed.connect(_on_viewport_resized)
	queue_redraw()

func _process(delta: float) -> void:
	toast_timer = maxf(0.0, toast_timer - delta)
	hitmarker_timer = maxf(0.0, hitmarker_timer - delta)
	if toast_timer > 0.0 or hitmarker_timer > 0.0:
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
	grenade_center = Vector2(s.x - 285.0, s.y - 255.0)
	medkit_center = Vector2(s.x - 370.0, s.y - 178.0)
	inventory_center = Vector2(s.x - 100.0, 130.0)

func get_move_vector() -> Vector2:
	return move_vector

func is_touch_on_control(pos: Vector2) -> bool:
	return pos.distance_to(jump_center) < button_radius * 1.4 \
		or pos.distance_to(aim_center) < button_radius * 1.4 \
		or pos.distance_to(fire_center) < button_radius * 1.5 \
		or pos.distance_to(reload_center) < button_radius * 1.3 \
		or pos.distance_to(grenade_center) < button_radius * 1.3 \
		or pos.distance_to(medkit_center) < button_radius * 1.3 \
		or pos.distance_to(inventory_center) < button_radius * 1.4

func set_ammo(current: int, reserve: int, weapon_name: String = "AWM") -> void:
	ammo_current = current
	ammo_reserve = reserve
	weapon_label = weapon_name
	queue_redraw()

func set_health(current: float, maximum: float) -> void:
	health_current = current
	health_maximum = maxf(1.0, maximum)
	queue_redraw()

func set_inventory(snapshot: Dictionary) -> void:
	inventory_snapshot = snapshot.duplicate(true)
	queue_redraw()

func set_round_info(round_number: int, target: int, seconds_left: float) -> void:
	round_info = "ROUND %d  |  %d PARA VENCER  |  %02d:%02d" % [round_number, target, int(seconds_left) / 60, int(seconds_left) % 60]
	queue_redraw()

func set_match_status(status: String, score: String) -> void:
	match_status = status
	score_text = score
	queue_redraw()

func show_toast(message: String) -> void:
	toast_text = message
	toast_timer = 2.0
	queue_redraw()

func show_hitmarker(hit: bool, killed: bool = false, headshot: bool = false) -> void:
	if not hit:
		return
	hitmarker_timer = 0.22
	hitmarker_kill = killed
	hitmarker_headshot = headshot
	queue_redraw()

func show_round_result(won: bool, round_number: int) -> void:
	result_text = ("ROUND %d VENCIDO" % round_number) if won else ("ROUND %d PERDIDO" % round_number)
	queue_redraw()

func show_match_result(won: bool) -> void:
	result_text = "VITÓRIA FINAL" if won else "DERROTA FINAL"
	queue_redraw()

func clear_result() -> void:
	result_text = ""
	queue_redraw()

func toggle_inventory() -> void:
	inventory_open = not inventory_open
	inventory_requested.emit()
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
	if pos.distance_to(inventory_center) < button_radius * 1.3 and inventory_touch == -1:
		inventory_touch = id
		toggle_inventory()
	elif pos.distance_to(joystick_center) < joystick_radius * 1.65 and joystick_touch == -1:
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
	elif pos.distance_to(grenade_center) < button_radius * 1.15 and grenade_touch == -1:
		grenade_touch = id
		grenade_requested.emit()
	elif pos.distance_to(medkit_center) < button_radius * 1.15 and medkit_touch == -1:
		medkit_touch = id
		medkit_requested.emit()
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
	if id == grenade_touch:
		grenade_touch = -1
	if id == medkit_touch:
		medkit_touch = -1
	if id == inventory_touch:
		inventory_touch = -1
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
	_draw_button(grenade_center, "GRANADA", false, 34.0)
	_draw_button(medkit_center, "KIT", false, 34.0)
	_draw_button(inventory_center, "MOCHILA", inventory_open, 36.0)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(28, 42), "CLOCKTOWER | 4V4", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	draw_string(font, Vector2(28, 67), "VIDA %d%%" % int(round(health_current / health_maximum * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_rect(Rect2(28, 75, 180, 10), Color(0.02, 0.03, 0.04, 0.72), true)
	var health_color := Color(0.20, 0.82, 0.36, 0.95) if health_current > 35.0 else Color(0.95, 0.24, 0.16, 0.98)
	draw_rect(Rect2(28, 75, 180.0 * clampf(health_current / health_maximum, 0.0, 1.0), 10), health_color, true)
	draw_string(font, Vector2(size.x * 0.5 - 120.0, 38.0), match_status, HORIZONTAL_ALIGNMENT_CENTER, 240.0, 17, Color.WHITE)
	draw_string(font, Vector2(size.x * 0.5 - 50.0, 62.0), score_text, HORIZONTAL_ALIGNMENT_CENTER, 100.0, 14, Color(1.0, 0.82, 0.34))
	draw_string(font, Vector2(size.x * 0.5 - 150.0, 84.0), round_info, HORIZONTAL_ALIGNMENT_CENTER, 300.0, 12, Color(0.9, 0.94, 1.0))
	var ammo_text := "%s  %02d / %03d" % [weapon_label, ammo_current, ammo_reserve]
	draw_string(font, Vector2(size.x - 195.0, 48.0), ammo_text, HORIZONTAL_ALIGNMENT_RIGHT, 170.0, 19, Color.WHITE)
	if aiming:
		var center := size * 0.5
		draw_line(center + Vector2(-10, 0), center + Vector2(-3, 0), Color.WHITE, 2.0)
		draw_line(center + Vector2(3, 0), center + Vector2(10, 0), Color.WHITE, 2.0)
		draw_line(center + Vector2(0, -10), center + Vector2(0, -3), Color.WHITE, 2.0)
		draw_line(center + Vector2(0, 3), center + Vector2(0, 10), Color.WHITE, 2.0)
	if hitmarker_timer > 0.0:
		var center := size * 0.5
		var marker_color := Color(1.0, 0.22, 0.12) if hitmarker_kill else Color(1.0, 1.0, 1.0)
		var extent := 12.0 if hitmarker_headshot else 8.0
		draw_line(center + Vector2(-extent, -extent), center + Vector2(-3, -3), marker_color, 3.0)
		draw_line(center + Vector2(extent, -extent), center + Vector2(3, -3), marker_color, 3.0)
		draw_line(center + Vector2(-extent, extent), center + Vector2(-3, 3), marker_color, 3.0)
		draw_line(center + Vector2(extent, extent), center + Vector2(3, 3), marker_color, 3.0)
		if hitmarker_headshot:
			draw_string(font, center + Vector2(20, -15), "HEADSHOT", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.82, 0.25))
	if toast_timer > 0.0:
		var toast_size := font.get_string_size(toast_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
		draw_rect(Rect2(size.x * 0.5 - toast_size.x * 0.5 - 20.0, size.y - 190.0, toast_size.x + 40.0, 42.0), Color(0.02, 0.04, 0.06, 0.78), true)
		draw_string(font, Vector2(size.x * 0.5, size.y - 163.0), toast_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color.WHITE)
	if inventory_open:
		_draw_inventory(font)
	if result_text != "":
		draw_rect(Rect2(size.x * 0.5 - 190.0, size.y * 0.5 - 85.0, 380.0, 170.0), Color(0.02, 0.04, 0.07, 0.88), true)
		draw_string(font, Vector2(size.x * 0.5, size.y * 0.5 + 12.0), result_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 42, Color(0.95, 0.82, 0.28))

func _draw_inventory(font: Font) -> void:
	var panel := Rect2(size.x * 0.5 - 220.0, size.y * 0.5 - 190.0, 440.0, 380.0)
	draw_rect(panel, Color(0.015, 0.025, 0.045, 0.94), true)
	draw_rect(panel, Color(0.38, 0.58, 0.78, 0.95), false, 2.0)
	draw_string(font, Vector2(panel.position.x + 24.0, panel.position.y + 36.0), "MOCHILA DE COMBATE", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	var rows := [
		"Munição AR 5.56: %d" % int(inventory_snapshot.get("ammo_556", 0)),
		"Munição SMG / pistola 9mm: %d" % int(inventory_snapshot.get("ammo_9mm", 0)),
		"Munição calibre 12: %d" % int(inventory_snapshot.get("ammo_12g", 0)),
		"Munição sniper: %d" % int(inventory_snapshot.get("ammo_sniper", ammo_reserve)),
		"Munição 7.62: %d" % int(inventory_snapshot.get("ammo_762", 0)),
		"Kits médicos: %d" % int(inventory_snapshot.get("medkits", 0)),
		"Granadas: %d" % int(inventory_snapshot.get("grenades", 0)),
		"Colete: %d%% | Capacete: %d%%" % [int(inventory_snapshot.get("armor", 0)), int(inventory_snapshot.get("helmet", 0))],
		"Mochila nível: %d | Capacidade: %d" % [int(inventory_snapshot.get("backpack_level", 1)), int(inventory_snapshot.get("capacity", 12))]
	]
	for i in range(rows.size()):
		draw_string(font, Vector2(panel.position.x + 28.0, panel.position.y + 70.0 + i * 29.0), rows[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.88, 0.92, 0.98))
	draw_string(font, Vector2(panel.position.x + 24.0, panel.end.y - 18.0), "Toque em MOCHILA para fechar", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.65, 0.75, 0.86))

func _draw_button(center: Vector2, label: String, active: bool, radius: float = 42.0) -> void:
	var fill: Color = Color(0.18, 0.62, 0.92, 0.78) if active else Color(0.03, 0.05, 0.08, 0.48)
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.78), 2.5, true)
	var font: Font = ThemeDB.fallback_font
	var font_size := 15 if radius > 38.0 else 11
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, center + Vector2(-width * 0.5, 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

# Competitive round HUD extension validated for Android export.
