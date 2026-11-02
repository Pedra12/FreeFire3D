extends Node

signal match_finished(winning_team: int)

var team_kills: Array[int] = [0, 0]
var match_over: bool = false
var player_node: Node3D
var hud: Control

func _ready() -> void:
	call_deferred("_connect_match")

func _connect_match() -> void:
	await get_tree().process_frame
	player_node = get_tree().get_first_node_in_group("player") as Node3D
	hud = get_tree().current_scene.get_node_or_null("MobileHUD") as Control
	if is_instance_valid(player_node):
		var health := player_node.get_node_or_null("Health")
		if health != null and health.has_signal("eliminated"):
			health.eliminated.connect(_on_player_eliminated)
	for bot in get_tree().get_nodes_in_group("bots"):
		if bot.has_signal("eliminated"):
			bot.eliminated.connect(_on_bot_eliminated)
	_update_hud()
	print("MATCH_READY mode=4v4 player_team=0 bots=", get_tree().get_nodes_in_group("bots").size())

func _on_player_eliminated(killer_team: int = -1) -> void:
	if match_over:
		return
	if killer_team >= 0 and killer_team < 2:
		team_kills[killer_team] += 1
	_check_winner()

func _on_bot_eliminated(team_id: int, killer_team: int) -> void:
	if match_over:
		return
	if killer_team >= 0 and killer_team < 2:
		team_kills[killer_team] += 1
	_update_hud()
	call_deferred("_check_winner")

func _check_winner() -> void:
	if match_over:
		return
	var alive := [0, 0]
	for combatant in get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(combatant):
			continue
		var health_value := 0.0
		if combatant.is_in_group("player"):
			var health := combatant.get_node_or_null("Health")
			if health != null:
				health_value = float(health.get("current_health"))
		else:
			health_value = float(combatant.get("health"))
		if health_value > 0.0:
			var team := clampi(int(combatant.get("team_id")), 0, 1)
			alive[team] += 1
	_update_hud()
	if alive[0] == 0 or alive[1] == 0:
		match_over = true
		var winner := 0 if alive[0] > 0 else 1
		match_finished.emit(winner)
		if is_instance_valid(hud) and hud.has_method("show_match_result"):
			hud.call("show_match_result", winner == 0)
		print("MATCH_FINISHED winner_team=", winner, " kills=", team_kills)

func _update_hud() -> void:
	if not is_instance_valid(hud):
		return
	var alive := [0, 0]
	for combatant in get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(combatant):
			continue
		var health_value := 0.0
		if combatant.is_in_group("player"):
			var health := combatant.get_node_or_null("Health")
			if health != null: health_value = float(health.get("current_health"))
		else:
			health_value = float(combatant.get("health"))
		if health_value > 0.0:
			alive[clampi(int(combatant.get("team_id")), 0, 1)] += 1
	if hud.has_method("set_match_status"):
		hud.call("set_match_status", "AZUL %d  |  %d VERMELHO" % [alive[0], alive[1]], "%d x %d" % [team_kills[0], team_kills[1]])
