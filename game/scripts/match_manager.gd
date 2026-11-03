extends Node
signal match_finished(winning_team: int)
signal round_finished(winning_team: int, round_number: int)

@export_range(1, 15) var rounds_to_win := 5
@export_range(1, 10) var round_duration := 180
@export var intermission_seconds := 4.0

var round_number := 1
var round_scores: Array[int] = [0, 0]
var team_kills: Array[int] = [0, 0]
var match_over := false
var round_over := false
var player_node: Node3D
var hud: Control
var spawner: Node
var round_timer := 0.0
var _transitioning := false

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_connect_match")

func _connect_match() -> void:
	await get_tree().process_frame
	player_node = get_tree().get_first_node_in_group("player") as Node3D
	hud = get_tree().root.find_child("MobileHUD", true, false) as Control
	spawner = get_parent().get_node_or_null("BotSpawner")
	if is_instance_valid(player_node):
		var health := player_node.get_node_or_null("Health")
		if health and health.has_signal("eliminated") and not health.eliminated.is_connected(_on_player_eliminated):
			health.eliminated.connect(_on_player_eliminated)
	for bot in get_tree().get_nodes_in_group("bots"):
		_connect_bot(bot)
	round_timer = float(round_duration)
	_update_hud()
	print("MATCH_READY 4v4 rounds_to_win=", rounds_to_win)

func _process(delta: float) -> void:
	if match_over or round_over:
		return
	round_timer = maxf(0.0, round_timer - delta)
	if round_timer <= 0.0:
		_finish_round(_round_winner_by_alive())

func _on_node_added(node: Node) -> void:
	if node != self:
		call_deferred("_connect_bot", node)

func _connect_bot(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_in_group("bots"):
		return
	var cb := Callable(self, "_on_bot_eliminated")
	if node.has_signal("eliminated") and not node.is_connected("eliminated", cb):
		node.connect("eliminated", cb)
	_update_hud()

func _on_player_eliminated(killer_team: int = -1) -> void:
	if match_over or round_over: return
	if killer_team in [0, 1]: team_kills[killer_team] += 1
	call_deferred("_evaluate_round")

func _on_bot_eliminated(_victim_team: int, killer_team: int) -> void:
	if match_over or round_over: return
	if killer_team in [0, 1]: team_kills[killer_team] += 1
	call_deferred("_evaluate_round")

func _evaluate_round() -> void:
	if match_over or round_over: return
	var alive := _alive_counts()
	if alive[0] == 0 or alive[1] == 0:
		_finish_round(0 if alive[0] > alive[1] else 1)

func _round_winner_by_alive() -> int:
	var a := _alive_counts()
	if a[0] == a[1]: return -1
	return 0 if a[0] > a[1] else 1

func _alive_counts() -> Array[int]:
	var counts: Array[int] = [0, 0]
	for actor in get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(actor): continue
		var hp := 0.0
		if actor.is_in_group("player"):
			var h := actor.get_node_or_null("Health")
			if h: hp = float(h.current_health)
		else:
			hp = float(actor.get("health"))
		if hp > 0.0: counts[clampi(int(actor.get("team_id")), 0, 1)] += 1
	return counts

func _finish_round(winner: int) -> void:
	if round_over or match_over: return
	round_over = true
	if winner in [0, 1]: round_scores[winner] += 1
	round_finished.emit(winner, round_number)
	if is_instance_valid(hud) and hud.has_method("show_round_result"):
		hud.call("show_round_result", winner == 0, round_number)
	print("ROUND_END round=", round_number, " winner=", winner, " score=", round_scores)
	_update_hud()
	if winner in [0, 1] and round_scores[winner] >= rounds_to_win:
		match_over = true
		match_finished.emit(winner)
		if is_instance_valid(hud): hud.call("show_match_result", winner == 0)
		print("MATCH_FINISHED winner_team=", winner)
		return
	_transition_round()

func _transition_round() -> void:
	if _transitioning: return
	_transitioning = true
	await get_tree().create_timer(intermission_seconds).timeout
	if match_over: return
	round_number += 1
	round_over = false
	if is_instance_valid(hud) and hud.has_method("clear_result"):
		hud.call("clear_result")
	round_timer = float(round_duration)
	if is_instance_valid(spawner) and spawner.has_method("deploy_round"):
		await spawner.call("deploy_round")
	_update_hud()
	_transitioning = false
	print("ROUND_START ", round_number)

func _update_hud() -> void:
	if not is_instance_valid(hud): return
	var alive := _alive_counts()
	if hud.has_method("set_match_status"):
		hud.call("set_match_status", "AZUL %d | %d VERMELHO" % alive, "%d x %d  •  R%d" % [round_scores[0], round_scores[1], round_number])
	if hud.has_method("set_round_info"):
		hud.call("set_round_info", round_number, rounds_to_win, round_timer)
