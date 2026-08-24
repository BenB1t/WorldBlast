extends RefCounted
class_name GameEventLog
## Append-only record of one Word Blast game. This single object is:
##   - the save file for close-and-resume (replaying rebuilds the exact
##     game state, even days later),
##   - the offline-resilience buffer from architecture doc §53,
##   - the artifact that will be submitted to the Cloudflare Worker for
##     ranked validation in Phase 4+.
##
## Schema v1:
##   meta:   { log_version, game_id, seed, ranked, ruleset }
##   events: [
##     {"seq": 1, "type": "place", "letter": "A", "x": 3, "y": 2, "skin": "skin_04"},
##     {"seq": 2, "type": "clear", "x": 3, "y": 2},
##     {"seq": 3, "type": "finish", "claimed_score": 145}
##   ]
## "skin" is cosmetic metadata; the replayer ignores it. A log WITHOUT a
## finish event is a game in progress — that is the resume case.

const LOG_VERSION: int = 1

var game_id: String = ""
var game_seed: int = -1
var is_ranked: bool = false
var ruleset_id: String = ""
var events: Array = []
var finished: bool = false

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
		"events": events,
	}

func to_json() -> String:
	return JSON.stringify(to_dictionary())

## JSON numbers come back as floats — everything is explicitly cast back
## to int on the way in, which is why seeds must stay 32-bit.
static func from_dictionary(data: Dictionary) -> GameEventLog:
	var log := GameEventLog.new()
	log.game_id = str(data.get("game_id", ""))
	log.game_seed = int(data.get("seed", -1))
	log.is_ranked = bool(data.get("ranked", false))
	log.ruleset_id = str(data.get("ruleset", ""))
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
