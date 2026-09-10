extends RefCounted
class_name GameEventLog

const LOG_VERSION: int = 1

var game_id: String = ""
var game_seed: int = -1
var is_ranked: bool = false
var ruleset_id: String = ""
var events: Array = []
var finished: bool = false

## Casual countdown clock (seconds) captured at the last save write.
## -1.0 means "no timer data" (old saves or invalid state).
var time_left: float = -1.0

func begin(id: String, seed: int, ranked: bool, ruleset: String = "") -> void:
	game_id = id
	game_seed = seed
	is_ranked = ranked
	ruleset_id = ruleset
	events.clear()
	finished = false

func log_place(letter: String, x: int, y: int, skin_id: String = "") -> void:
	events.append({
		"seq": events.size() + 1,
		"type": "place",
		"letter": letter,
		"x": x,
		"y": y,
		"skin": skin_id,
	})

func log_place_piece(shape: String, letters: Array, x: int, y: int, slot: int, skin_id: String = "") -> void:
	events.append({
		"seq": events.size() + 1,
		"type": "place",
		"shape": shape,
		"letters": letters,
		"x": x,
		"y": y,
		"slot": slot,
		"skin": skin_id,
	})

func log_clear(x: int, y: int) -> void:
	events.append({
		"seq": events.size() + 1,
		"type": "clear",
		"x": x,
		"y": y,
	})

func log_finish(claimed_score: int) -> void:
	finished = true
	events.append({
		"seq": events.size() + 1,
		"type": "finish",
		"claimed_score": claimed_score,
	})

func to_dictionary() -> Dictionary:
	return {
		"log_version": LOG_VERSION,
		"game_id": game_id,
		"seed": game_seed,
		"ranked": is_ranked,
		"ruleset": ruleset_id,
		"time_left": time_left,      # <--- CRITICAL: Saves the clock to disk
		"events": events,
	}

func to_json() -> String:
	return JSON.stringify(to_dictionary())

static func from_dictionary(data: Dictionary) -> GameEventLog:
	var log := GameEventLog.new()
	log.game_id = str(data.get("game_id", ""))
	log.game_seed = int(data.get("seed", -1))
	log.is_ranked = bool(data.get("ranked", false))
	log.ruleset_id = str(data.get("ruleset", ""))
	log.time_left = float(data.get("time_left", -1.0))  # <--- CRITICAL: Reads the clock from disk
	log.events = data.get("events", [])
	log.finished = false
	for e in log.events:
		if str(e.get("type", "")) == "finish":
			log.finished = true
	return log

static func from_json(text: String) -> GameEventLog:
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return from_dictionary(parsed)
