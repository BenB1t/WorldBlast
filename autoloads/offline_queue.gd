extends Node

const QUEUE_PATH := "user://pending_ranked_submissions.json"

func _ready() -> void:
	# Try to flush the queue every time the app starts
	flush()

func add(payload: Dictionary) -> void:
	var queue := _load_queue()
	queue.append(payload)
	_save_queue(queue)
	print("[OfflineQueue] Saved score to pending queue.")

func flush() -> void:
	var queue := _load_queue()
	if queue.is_empty(): 
		return

	print("[OfflineQueue] Attempting to flush %d pending scores..." % queue.size())
	var remaining := []
	
	for payload in queue:
		var response = await ApiClient.finish_ranked_game(
			payload["game_id"],
			payload["player_id"],
			payload["score"],
			payload["events"],
			payload.get("seed", 0),
			payload.get("ruleset_version", "ranked_v1")
		)
		
		if response.has("error"):
			remaining.append(payload) # Keep it for next time
		else:
			print("[OfflineQueue] Successfully submitted offline score: ", payload["game_id"])
			
	_save_queue(remaining)

func _load_queue() -> Array:
	if not FileAccess.file_exists(QUEUE_PATH): 
		return []
	var file := FileAccess.open(QUEUE_PATH, FileAccess.READ)
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Array:
		return json.data
	return []

func _save_queue(queue: Array) -> void:
	var file := FileAccess.open(QUEUE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(queue))
	file.close()
