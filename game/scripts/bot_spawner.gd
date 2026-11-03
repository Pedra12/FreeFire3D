extends Node3D
@export var bot_scene: PackedScene
@export_range(1, 7, 1) var bot_count: int = 7
const BLUE_SPAWN := Vector3(-30.0, 1.5, 0.0)
const RED_SPAWN := Vector3(30.0, 1.5, 0.0)
const BLUE_OFFSETS: Array[Vector3] = [Vector3(-2.5,0,-3),Vector3(2.5,0,-3),Vector3(-2.5,0,3),Vector3(2.5,0,3)]
const RED_OFFSETS: Array[Vector3] = [Vector3(-2.5,0,-3),Vector3(2.5,0,-3),Vector3(-2.5,0,3),Vector3(2.5,0,3)]

func _ready() -> void:
	call_deferred("deploy_round")

func deploy_round() -> void:
	if bot_scene == null:
		push_error("BOT_SPAWNER: bot_scene missing"); return
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not is_instance_valid(player):
		push_error("BOT_SPAWNER: player not found"); return
	for old in get_tree().get_nodes_in_group("bots"):
		if is_instance_valid(old): old.queue_free()
	await get_tree().process_frame
	var map_node := get_parent().get_node_or_null("Map")
	var waited := 0
	while map_node != null and not bool(map_node.get("is_ready_for_queries")) and waited < 600:
		await get_tree().physics_frame; waited += 1
	player.set("team_id",0)
	player.global_position = _ground_position(BLUE_SPAWN,player)
	var health := player.get_node_or_null("Health")
	if health:
		health.set("current_health",health.get("maximum_health"))
		health.set("is_eliminated",false)
		health.health_changed.emit(health.current_health,health.maximum_health)
	player.set("velocity",Vector3.ZERO)
	for i in range(7):
		var bot := bot_scene.instantiate() as CharacterBody3D
		if bot == null: continue
		var team := 0 if i < 3 else 1
		bot.set("team_id",team)
		var cid: String = ["assault","medic","support","recon"][i%4]
		var weapon: StringName = StringName(String(MatchConfig.CLASSES[cid]["weapon"]))
		add_child(bot)
		bot.global_position = _ground_position((BLUE_SPAWN+BLUE_OFFSETS[i]) if team==0 else (RED_SPAWN+RED_OFFSETS[i-3]),bot)
		var mount=bot.get_node_or_null("WeaponMount")
		if mount: mount.call("equip_weapon",weapon)
		match weapon:
			&"assault_rifle": bot.set("attack_damage",28.0); bot.set("attack_interval",0.18); bot.set("attack_range",38.0)
			&"smg": bot.set("attack_damage",20.0); bot.set("attack_interval",0.14); bot.set("attack_range",24.0)
			&"shotgun": bot.set("attack_damage",34.0); bot.set("attack_interval",0.9); bot.set("attack_range",12.0)
			&"awm": bot.set("attack_damage",48.0); bot.set("attack_interval",1.25); bot.set("attack_range",52.0)
	print("ROUND_DEPLOY blue=4 red=4")

func _ground_position(point: Vector3, actor: CharacterBody3D) -> Vector3:
	var q:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*45,point+Vector3.DOWN*100)
	q.exclude=[actor.get_rid()]
	var hit=get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position+Vector3.UP*0.85 if not hit.is_empty() else point
