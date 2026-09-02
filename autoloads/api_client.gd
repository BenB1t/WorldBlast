extends Node

# Points to your local Wrangler dev server. Change to your Cloudflare URL later.
const BASE_URL := "http://127.0.0.1:8787"

func _post(endpoint: String, payload: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	
	var url := BASE_URL + endpoint
	var headers := ["Content-Type: application/json"]
	var json_body := JSON.stringify(payload)
	
	var err := http.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		http.queue_free()
		return {"error": "Failed to create HTTP request"}
	
	var response = await http.request_completed
	var result_code = response[0]
	var status_code = response[1]
	var body: PackedByteArray = response[3]
	http.queue_free()
	
	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {"error": "Network error: " + str(result_code)}
		
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return {"error": "Failed to parse JSON response"}
		
	if status_code >= 400:
		return {"error": "Server error", "status": status_code, "data": json.data}
		
	return json.data

# Renamed from _get to _http_get to avoid conflicting with Godot's built-in Object._get() method!
func _http_get(endpoint: String) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	
	var err := http.request(BASE_URL + endpoint, [], HTTPClient.METHOD_GET)
	if err != OK:
		http.queue_free()
		return {"error": "Failed to create HTTP request"}
		
	var response = await http.request_completed
	var result_code = response[0]
	var status_code = response[1]
	var body: PackedByteArray = response[3]
	http.queue_free()
	
	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {"error": "Network error: " + str(result_code)}
		
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return {"error": "Failed to parse JSON"}
		
	if status_code >= 400:
		return {"error": "Server error", "status": status_code, "data": json.data}
		
	return json.data

func start_ranked_game(player_id: String, display_name: String, country: String = "") -> Dictionary:
	return await _post("/v1/ranked/start", {
		"player_id": player_id,
		"display_name": display_name,
		"country": country
	})

func finish_ranked_game(game_id: String, player_id: String, score: int, events: Array, seed: int = 0, ruleset: String = "ranked_v1") -> Dictionary:
	return await _post("/v1/ranked/finish", {
		"game_id": game_id, 
		"player_id": player_id, 
		"score": score, 
		"events": events,
		"seed": seed,
		"ruleset_version": ruleset
	})

# --- LEADERBOARD & VAULT HELPERS ---
func get_global_leaderboard(limit: int = 100) -> Dictionary:
	return await _http_get("/v1/leaderboard/global?limit=" + str(limit))

func get_my_rank(player_id: String) -> Dictionary:
	return await _http_get("/v1/leaderboard/me?player_id=" + player_id.uri_encode())

func get_vault(player_id: String) -> Dictionary:
	return await _http_get("/v1/vault?player_id=" + player_id.uri_encode())
