extends Node

var is_active: bool = false
var game_id: String = ""
var game_seed: int = 0

func start_new_session(server_response: Dictionary) -> void:
	is_active = true
	game_id = server_response.get("game_id", "")
	game_seed = server_response.get("seed", 0)

func clear_session() -> void:
	is_active = false
	game_id = ""
	game_seed = 0
