extends CharacterBody3D

@export var maximum_health: float = 100.0
@export var move_speed: float = 2.35
@export var detection_range: float = 48.0
@export var attack_range: float = 13.0
@export var attack_interval: float = 1.25
@export var attack_damage: float = 7.0
@export var turn_speed: float = 7.5

@onready var visual: Node3D = $VisualRoot
@onready var model: Node3D = $VisualRoot/CharacterModel

var health: float = 100.0
var player: Node3D
var animation_player: AnimationPlayer
var attack_timer: float = 0.8
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var current_animation: StringName = &""
var action_animation_locked: bool = false

func _ready() -> void:
	add_to_group("damageable")
	add_to_group("bots")
	health = maximum_health
	var animation_nodes := model.find_children("*", "AnimationPlayer", true, false)
	if not animation_nodes.is_empty():
		animation_player = animation_nodes[0] as AnimationPlayer
	if animation_player != null:
		animation_player.animation_finished.connect(_on_animation_finished)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 25.0, global_position + Vector3.DOWN * 80.0)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position.y = float(hit.position.y) + 0.70
	player = get_tree().get_first_node_in_group("player") as Node3D
	_play([&"Idle", &"idle", &"Idle_Rifle"])

func _physics_process(delta: float) -> void:
	attack_timer = maxf(0.0, attack_timer - delta)
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta)
		_apply_gravity(delta)
		move_and_slide()
		return

	var offset := player.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance > detection_range:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 2.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 2.0 * delta)
		_play([&"Idle", &"idle", &"Idle_Rifle"])
	elif distance > attack_range:
		var direction := offset.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		var angle := atan2(direction.x, direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, angle, turn_speed * delta)
		_play([&"Walk", &"Walk_F", &"Run", &"Idle"])
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 5.0 * delta)
		var direction := offset.normalized()
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), turn_speed * delta)
		_play([&"Pistol_Aim_Neutral", &"Rifle_Aim_Idle", &"Idle_Rifle", &"Idle"])
		if attack_timer <= 0.0:
			_attack_player()
			attack_timer = attack_interval

	_apply_gravity(delta)
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = minf(velocity.y, 0.0)

func _attack_player() -> void:
	if not is_instance_valid(player):
		return
	var health_node := player.get_node_or_null("Health")
	if health_node != null and health_node.has_method("apply_damage"):
		_play_action(&"Pistol_Shoot")
		health_node.apply_damage(attack_damage)

func apply_damage(amount: float, _hit_position: Vector3 = Vector3.ZERO, _hit_normal: Vector3 = Vector3.UP) -> void:
	if health <= 0.0:
		return
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		queue_free()

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
