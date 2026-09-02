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
				if e.has("shape"):
					# Current format: one event per multi-cell piece.
					var result: Dictionary = game.apply_place_piece(
						str(e.get("shape", "S")),
						e.get("letters", []),
						int(e.get("x", -1)),
						int(e.get("y", -1)),
						int(e.get("slot", -1))
					)
					if not result["valid"]:
						errors.append("seq %s: invalid place_piece (%s)" % [seq_label, result["reason"]])
						return {"valid": false, "errors": errors, "game": game}
				else:
					# Pre-piece save: the tray/bag model changed (pieces now
					# consume a shape roll + N letter rolls), so these logs
					# can no longer be replayed deterministically. Fail
					# cleanly so the game discards the save and starts fresh.
					errors.append("seq %s: legacy single-letter event (save predates piece update)" % seq_label)
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
