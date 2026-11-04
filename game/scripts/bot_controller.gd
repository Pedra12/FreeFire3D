extends CharacterBody3D

signal eliminated(team_id: int, killer_team: int)

@export var team_id: int = 1
@export var class_id: StringName = &"assault"
@export var weapon_id: StringName = &"assault_rifle"
@export var maximum_health: float = 100.0
@export var move_speed: float = 3.0
@export var detection_range: float = 52.0
@export var attack_range: float = 28.0
@export var attack_interval: float = 0.82
@export var attack_damage: float = 9.0
@export var turn_speed: float = 8.5
@export var magazine_size: int = 24
@export var reload_duration: float = 1.8

@onready var visual: Node3D = $VisualRoot
@onready var model: Node3D = $VisualRoot/CharacterModel

var health: float = 100.0
var target: Node3D
var animation_player: AnimationPlayer
var attack_timer: float = 0.8
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var current_animation: StringName = &""
var action_animation_locked: bool = false
var ammo_in_magazine: int = 24
var reloading: bool = false
var alive: bool = true
var footstep_clock: float = 0.0
var strafe_sign: float = 1.0

func _ready() -> void:
	add_to_group("damageable")
	add_to_group("combatants")
	add_to_group("bots")
	health = maximum_health
	ammo_in_magazine = magazine_size
	strafe_sign = -1.0 if get_instance_id() % 2 == 0 else 1.0
	_apply_class_profile()
	var animation_nodes := model.find_children("*", "AnimationPlayer", true, false)
	if not animation_nodes.is_empty():
		animation_player = animation_nodes[0] as AnimationPlayer
	if animation_player != null:
		animation_player.animation_finished.connect(_on_animation_finished)
	var map_node := get_parent().get_node_or_null("Map")
	var waited := 0
	while map_node != null and not bool(map_node.get("is_ready_for_queries")) and waited < 600:
		await get_tree().physics_frame
		waited += 1
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 25.0, global_position + Vector3.DOWN * 80.0)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position.y = float(hit.position.y) + 0.90
	_play([&"Idle", &"idle", &"Idle_Rifle"])

func _apply_class_profile() -> void:
	match class_id:
		&"assault":
			attack_damage = 14.0
			attack_interval = 0.24
			attack_range = 34.0
			magazine_size = 30
			reload_duration = 2.0
		&"medic":
			attack_damage = 10.0
			attack_interval = 0.13
			attack_range = 24.0
			magazine_size = 32
			reload_duration = 1.65
		&"support":
			attack_damage = 8.0
			attack_interval = 0.72
			attack_range = 12.0
			magazine_size = 6
			reload_duration = 2.4
		&"recon":
			attack_damage = 42.0
			attack_interval = 1.45
			attack_range = 48.0
			magazine_size = 5
			reload_duration = 2.5
			move_speed = 2.65\n\nfunc _physics_process(delta: float) -> void:
	if not alive:
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	if reloading:
		_apply_gravity(delta)
		move_and_slide()
		return
	if not is_instance_valid(target) or not _is_valid_enemy(target) or global_position.distance_to(target.global_position) > detection_range * 1.35:
		target = _find_enemy()
	if not is_instance_valid(target):
		_stop_horizontal(delta)
		_apply_gravity(delta)
		move_and_slide()
		_play([&"Idle", &"idle", &"Idle_Rifle"])
		return

	var offset := target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	var direction := offset.normalized()
	var visible := _has_line_of_sight(target)
	if distance > attack_range or not visible:
		var travel := _avoid_obstacle(direction)
		velocity.x = travel.x * move_speed
		velocity.z = travel.z * move_speed
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), turn_speed * delta)
		_play([&"Walk", &"Walk_F", &"Run", &"Idle"])
		footstep_clock -= delta
		if footstep_clock <= 0.0:
			_play_footstep()
			footstep_clock = 0.52
	else:
		_stop_horizontal(delta)
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), turn_speed * delta)
		_play([&"Pistol_Aim_Neutral", &"Rifle_Aim_Idle", &"Idle_Rifle", &"Idle"])
		if attack_timer <= 0.0:
			if ammo_in_magazine <= 0:
				_reload()
			else:
				_attack_target()
				attack_timer = attack_interval
	_apply_gravity(delta)
	move_and_slide()

func _find_enemy() -> Node3D:
	var nearest: Node3D
	var nearest_distance := detection_range
	for candidate in get_tree().get_nodes_in_group("combatants"):
		if not candidate is Node3D or candidate == self or not _is_valid_enemy(candidate):
			continue
		var distance := global_position.distance_to((candidate as Node3D).global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate as Node3D
	return nearest

func _is_valid_enemy(candidate: Node) -> bool:
	if not is_instance_valid(candidate) or candidate == self:
		return false
	if candidate.get("team_id") == null or int(candidate.get("team_id")) == team_id:
		return false
	if candidate.is_in_group("player"):
		var health_node := candidate.get_node_or_null("Health")
		return health_node != null and float(health_node.get("current_health")) > 0.0
	return float(candidate.get("health")) > 0.0

func _has_line_of_sight(candidate: Node3D) -> bool:
	var from := global_position + Vector3.UP * 1.15
	var to := candidate.global_position + Vector3.UP * 1.15
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Object = hit.get("collider")
	return collider == candidate

func _avoid_obstacle(direction: Vector3) -> Vector3:
	var from := global_position + Vector3.UP * 0.9
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * 2.0)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return direction
	var side := direction.cross(Vector3.UP).normalized() * strafe_sign
	var alternate := PhysicsRayQueryParameters3D.create(from, from + side * 2.0)
	alternate.exclude = [get_rid()]
	if get_world_3d().direct_space_state.intersect_ray(alternate).is_empty():
		return side
	return -side

func _attack_target() -> void:
	if not is_instance_valid(target):
		return
	ammo_in_magazine -= 1
	_play_action(_shoot_animation_for_weapon())
	var from := global_position + Vector3.UP * 1.2
	var to := target.global_position + Vector3.UP * 1.15
	var spread_scale := 0.012 if class_id == &"recon" else (0.065 if class_id == &"support" else 0.035)
	var spread := Vector3(
		randf_range(-spread_scale, spread_scale),
		randf_range(-spread_scale * 0.7, spread_scale * 0.7),
		randf_range(-spread_scale, spread_scale)
	)
	to += spread * from.distance_to(to)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		if collider is Node and collider.has_method("apply_damage") and collider.get("team_id") != null and int(collider.get("team_id")) != team_id:
			collider.call("apply_damage", attack_damage, hit.position, hit.normal, self)
	if ammo_in_magazine <= 0:
		_reload()

func _shoot_animation_for_weapon() -> StringName:
	var candidates: Array[StringName] = []
	match weapon_id:
		&"awm":
			candidates = [&"Sniper_Shoot", &"Rifle_Shoot", &"Pistol_Shoot"]
		&"shotgun":
			candidates = [&"Shotgun_Shoot", &"Rifle_Shoot", &"Pistol_Shoot"]
		&"smg":
			candidates = [&"SMG_Shoot", &"Rifle_Shoot", &"Pistol_Shoot"]
		_:
			candidates = [&"Rifle_Shoot", &"Assault_Rifle_Shoot", &"Pistol_Shoot"]
	for clip in candidates:
		if animation_player != null and animation_player.has_animation(clip):
			return clip
	return &"Pistol_Shoot"

func _reload() -> void:
	if reloading:
		return
	reloading = true
	_play_action(&"Pistol_Reload")
	await get_tree().create_timer(reload_duration).timeout
	if not is_inside_tree():
		return
	ammo_in_magazine = magazine_size
	reloading = false

func apply_damage(amount: float, hit_position: Vector3 = Vector3.ZERO, _hit_normal: Vector3 = Vector3.UP, source: Node = null) -> bool:
	if not alive or health <= 0.0 or amount <= 0.0:
		return false
	if is_instance_valid(source) and source.get("team_id") != null and int(source.get("team_id")) == team_id:
		return false
	health = maxf(0.0, health - amount)
	_show_damage_number(amount, hit_position)
	if health <= 0.0:
		alive = false
		var killer_team := int(source.get("team_id")) if is_instance_valid(source) and source.get("team_id") != null else -1
		eliminated.emit(team_id, killer_team)
		var death_clip: StringName = &"Death01" if animation_player != null and animation_player.has_animation(&"Death01") else &"Death"
		_play_action(death_clip)
		_spawn_elimination_effect()
		var cleanup_delay := 0.9
		if animation_player != null and animation_player.has_animation(death_clip):
			cleanup_delay = maxf(cleanup_delay, animation_player.get_animation(death_clip).length)
		var cleanup_timer := get_tree().create_timer(minf(cleanup_delay, 2.0))
		cleanup_timer.timeout.connect(queue_free)
		return true
	return false

func _show_damage_number(amount: float, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = str(roundi(amount))
	label.font_size = 42
	label.pixel_size = 0.003
	label.modulate = Color(1.0, 0.84, 0.32, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	var effects_root: Node = get_tree().current_scene
	if effects_root == null:
		effects_root = get_parent()
	if effects_root == null:
		return
	effects_root.add_child(label)
	label.global_position = at + Vector3.UP * 0.3
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y + 0.9, 0.55)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.55)
	tween.tween_callback(label.queue_free)

func _spawn_elimination_effect() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var burst := Node3D.new()
	burst.name = "EliminationBurst"
	scene.add_child(burst)
	burst.global_position = global_position + Vector3.UP * 0.85
	var sphere := SphereMesh.new()
	sphere.radius = 0.055
	sphere.height = 0.11
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.25, 0.08, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.12, 0.025, 1.0)
	for index in range(10):
		var shard := MeshInstance3D.new()
		shard.mesh = sphere
		shard.material_override = material
		burst.add_child(shard)
		var angle := TAU * float(index) / 10.0
		var destination := Vector3(cos(angle) * randf_range(0.35, 0.75), randf_range(-0.1, 0.65), sin(angle) * randf_range(0.35, 0.75))
		var tween := shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "position", destination, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, "scale", Vector3.ZERO, 0.55)
	var cleanup := get_tree().create_timer(0.7)
	cleanup.timeout.connect(burst.queue_free)


func _play_footstep() -> void:
	var audio := get_node_or_null("FootstepAudio") as AudioStreamPlayer3D
	if audio != null and audio.stream != null:
		audio.pitch_scale = randf_range(0.94, 1.06)
		audio.play()

func _stop_horizontal(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed * 5.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, move_speed * 5.0 * delta)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = minf(velocity.y, 0.0)

func _play_action(animation_name: StringName) -> void:
	if animation_player == null or not animation_player.has_animation(animation_name):
		return
	action_animation_locked = true
	current_animation = animation_name
	animation_player.play(animation_name, 0.06)

func _on_animation_finished(animation_name: StringName) -> void:
	if action_animation_locked and animation_name == current_animation:
		action_animation_locked = false

func _play(names: Array[StringName]) -> void:
	if animation_player == null or action_animation_locked:
		return
	for name in names:
		if animation_player.has_animation(name):
			if current_animation == name and animation_player.is_playing():
				return
			current_animation = name
			animation_player.play(name, 0.2)
			return
