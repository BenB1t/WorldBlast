extends RefCounted
class_name GameReplayer
## Replays a serialized GameEventLog through HeadlessGame. This is the
## exact logic that becomes the Cloudflare Worker's server-side validator
## in Phase 6 — if a replay cannot reproduce the claimed result here,
## the submission is rejected.
##
## Also used for save/resume: result["game"] is the fully reconstructed
## HeadlessGame state, ready to hydrate the visual scene.

static func replay(log_data: Dictionary) -> Dictionary:
	var errors: Array = []
	var game := HeadlessGame.new()

	var seed_value: int = int(log_data.get("seed", -1))
	var ranked: bool = bool(log_data.get("ranked", false))
	if seed_value < 0:
		return {"valid": false, "errors": ["missing_or_invalid_seed"], "game": game}

	game.setup(seed_value, ranked)

	var events: Array = log_data.get("events", [])
	for e in events:
		var etype: String = str(e.get("type", ""))
		var seq_label: String = str(e.get("seq", "?"))
		match etype:
			"place":
				var result: Dictionary = game.apply_place(
					str(e.get("letter", "")),
					int(e.get("x", -1)),
					int(e.get("y", -1)),
					str(e.get("skin", ""))
				)
				if not result["valid"]:
					errors.append("seq %s: invalid place (%s)" % [seq_label, result["reason"]])
					return {"valid": false, "errors": errors, "game": game}
			"clear":
				# No-op taps are legal in the live game too; nothing to verify.
				game.apply_clear(int(e.get("x", -1)), int(e.get("y", -1)))
			"finish":
				var claimed: int = int(e.get("claimed_score", -1))
				if claimed != game.score:
					errors.append("seq %s: claimed score %d != simulated %d" % [seq_label, claimed, game.score])
				if not game.game_over:
					errors.append("seq %s: finish event but simulated game is not over" % seq_label)
			_:
				errors.append("seq %s: unknown event type '%s'" % [seq_label, etype])
				return {"valid": false, "errors": errors, "game": game}

	return {"valid": errors.is_empty(), "errors": errors, "game": game}
