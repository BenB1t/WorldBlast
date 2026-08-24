## Headless tests for Phase 3: event log + replay.
##
## Run from the command line:
##   godot --headless --script res://tests/replay_test.gd
##
## What this proves:
##   1. seed + event log ALWAYS reproduces the same board/score/tray,
##      including through a JSON round-trip (the resume/save path).
##   2. Ranked word-reuse scoring (second clear = 0 points) and casual
##      full rescoring both behave as the frozen ruleset requires.
##   3. Cheat attempts are rejected: letters never dealt, occupied cells.
##   4. An unfinished log (no finish event) replays cleanly — that is
##      the close-the-app-and-come-back-in-2-days case.
extends SceneTree

const TEST_SEED: int = 42

func _initialize() -> void:

	var all_passed := true
	all_passed = _test_seeded_replay_is_deterministic() and all_passed
	all_passed = _test_json_roundtrip_survives() and all_passed
	all_passed = _test_ranked_word_reuse_scoring() and all_passed
	all_passed = _test_casual_allows_rescoring() and all_passed
	all_passed = _test_rejects_letter_not_in_tray() and all_passed
	all_passed = _test_rejects_occupied_cell() and all_passed
	all_passed = _test_unfinished_log_replays_for_resume() and all_passed

	if all_passed:
		print("\n[PASS] All replay tests passed.")
	else:
		printerr("\n[FAIL] One or more replay tests failed.")
	quit(0 if all_passed else 1)

# =============================================================================
# BOOTSTRAP
# =============================================================================

# =============================================================================
# HELPERS
# =============================================================================

## Test-only bag that returns a scripted letter sequence instead of
## weighted-random draws. Lets us spell known words (e.g. ART) without
## depending on what the weighted bag happens to deal.
class ScriptedBag extends LetterBag:
	var _seq: Array
	var _i: int = 0

	func _init(seq: Array) -> void:
		super(-1)
		_seq = seq

	func random_letter() -> String:
		var letter: String = _seq[_i % _seq.size()]
		_i += 1
		return letter

func _states_match(a: HeadlessGame, b: HeadlessGame) -> bool:
	if a.cells != b.cells:
		return false
	if a.skins != b.skins:
		return false
	if a.tray != b.tray:
		return false
	if a.score != b.score:
		return false
	if a.combo_count != b.combo_count:
		return false
	if a.turns_since_last_clear != b.turns_since_last_clear:
		return false
	if a.game_over != b.game_over:
		return false
	if a.pending_matches.size() != b.pending_matches.size():
		return false
	return true

# =============================================================================
# TESTS
# =============================================================================

## Builds a log by dealing real letters from a twin bag and placing them,
## then replays that log twice through GameReplayer. Both replays must
## match each other and the reference simulation exactly.
func _test_seeded_replay_is_deterministic() -> bool:
	var ref := HeadlessGame.new()
	ref.setup(TEST_SEED, false)
	var twin := LetterBag.new(TEST_SEED)

	var log := GameEventLog.new()
	log.begin("det-test", TEST_SEED, false)

	# Place the first 16 dealt letters across the top two rows. Because
	# the tray refills immediately after every placement, dealt letter i
	# is guaranteed to be in the tray at placement i.
	for i in range(16):
		var letter: String = twin.random_letter()
		var pos := Vector2i(i % 8, i / 8)
		var res: Dictionary = ref.apply_place(letter, pos.x, pos.y)
		if not res["valid"]:
			printerr("[FAIL] Reference placement %d unexpectedly invalid: %s" % [i, res["reason"]])
			return false
		log.log_place(letter, pos.x, pos.y)

	var result_a: Dictionary = GameReplayer.replay(log.to_dictionary())
	var result_b: Dictionary = GameReplayer.replay(log.to_dictionary())
	if not result_a["valid"] or not result_b["valid"]:
		printerr("[FAIL] Replay of a legal game was marked invalid: %s / %s" % [result_a["errors"], result_b["errors"]])
		return false
	if not _states_match(result_a["game"], result_b["game"]):
		printerr("[FAIL] Two replays of the same log diverged.")
		return false
	if not _states_match(result_a["game"], ref):
		printerr("[FAIL] Replay diverged from the reference simulation.")
		return false

	print("[PASS] Seeded replay is deterministic and matches live simulation.")
	return true

func _test_json_roundtrip_survives() -> bool:
	var log := GameEventLog.new()
	log.begin("json-test", TEST_SEED, false)
	var twin := LetterBag.new(TEST_SEED)
	for i in range(6):
		var letter: String = twin.random_letter()
		log.log_place(letter, i, 0, "skin_0%d" % (i + 1))
	log.log_clear(1, 0)

	var restored: GameEventLog = GameEventLog.from_json(log.to_json())
	if restored == null:
		printerr("[FAIL] JSON round-trip returned null.")
		return false
	if restored.game_seed != TEST_SEED:
		printerr("[FAIL] Seed corrupted by JSON round-trip: %d" % restored.game_seed)
		return false

	var result: Dictionary = GameReplayer.replay(restored.to_dictionary())
	if not result["valid"]:
		printerr("[FAIL] JSON round-tripped log failed replay: %s" % result["errors"])
		return false

	print("[PASS] Log survives JSON serialization (save/resume path).")
	return true

## Ranked: spelling ART twice — first clear scores, second clear clears
## but scores zero (word already consumed). Combo still advances.
func _test_ranked_word_reuse_scoring() -> bool:
	# First 3 draws fill the tray; the next draws refill placed slots.
	# Sequence chosen so the tray refills back to A,R,T for round two.
	var bag := ScriptedBag.new(["A", "R", "T", "A", "R", "T", "Z", "Z", "Z"])
	var game := HeadlessGame.new()
	game.setup(7, true, bag)

	var expected_first: int = ScoreRules.score_word("ART", 0, 0)

	var placements := [[0, 0], [1, 0], [2, 0]]
	var letters := ["A", "R", "T"]
	for i in range(3):
		var res: Dictionary = game.apply_place(letters[i], placements[i][0], placements[i][1])
		if not res["valid"]:
			printerr("[FAIL] Ranked ART placement %d invalid: %s" % [i, res["reason"]])
			return false
	var first_clear: Dictionary = game.apply_clear(1, 0)
	if not first_clear["cleared"] or game.score != expected_first:
		printerr("[FAIL] First ART clear: cleared=%s score=%d (expected %d)" % [first_clear["cleared"], game.score, expected_first])
		return false

	for i in range(3):
		var res: Dictionary = game.apply_place(letters[i], placements[i][0], placements[i][1])
		if not res["valid"]:
			printerr("[FAIL] Ranked ART re-placement %d invalid: %s" % [i, res["reason"]])
			return false
	var second_clear: Dictionary = game.apply_clear(1, 0)
	if not second_clear["cleared"]:
		printerr("[FAIL] Reused ART should still clear in ranked mode.")
		return false
	if game.score != expected_first:
		printerr("[FAIL] Reused ART scored points in ranked mode: total=%d (expected %d)" % [game.score, expected_first])
		return false
	if game.combo_count != 2:
		printerr("[FAIL] Combo should count reused clears too: %d (expected 2)" % game.combo_count)
		return false
	if game.availability_tracker.is_available("ART"):
		printerr("[FAIL] ART should be marked used in the tracker.")
		return false

	print("[PASS] Ranked word reuse: second clear scores 0, still clears, combo advances.")
	return true

## Casual: no tracker — the same ART twice scores full points both times.
func _test_casual_allows_rescoring() -> bool:
	var bag := ScriptedBag.new(["A", "R", "T", "A", "R", "T", "Z", "Z", "Z"])
	var game := HeadlessGame.new()
	game.setup(7, false, bag)

	var first_expected: int = ScoreRules.score_word("ART", 0, 0)
	var second_expected: int = ScoreRules.score_word("ART", 0, 1)  # combo_count = 1

	var placements := [[0, 0], [1, 0], [2, 0]]
	var letters := ["A", "R", "T"]
	for round in range(2):
		for i in range(3):
			var res: Dictionary = game.apply_place(letters[i], placements[i][0], placements[i][1])
			if not res["valid"]:
				printerr("[FAIL] Casual ART placement invalid: %s" % res["reason"])
				return false
		game.apply_clear(1, 0)

	var total_expected: int = first_expected + second_expected
	if game.score != total_expected:
		printerr("[FAIL] Casual rescoring wrong: %d (expected %d)" % [game.score, total_expected])
		return false

	print("[PASS] Casual mode rescoring works (no word-reuse restriction).")
	return true

func _test_rejects_letter_not_in_tray() -> bool:
	# Find a letter guaranteed not to be in the dealt tray.
	var twin := LetterBag.new(TEST_SEED)
	var dealt := [twin.random_letter(), twin.random_letter(), twin.random_letter()]
	var forged := "Q"
	for candidate in ["Q", "Z", "X", "J"]:
		if not dealt.has(candidate):
			forged = candidate
			break

	var log := GameEventLog.new()
	log.begin("cheat-test", TEST_SEED, false)
	log.log_place(forged, 0, 0)

	var result: Dictionary = GameReplayer.replay(log.to_dictionary())
	if result["valid"]:
		printerr("[FAIL] Replayed accepted a letter that was never dealt.")
		return false

	print("[PASS] Replay rejects a letter that was never dealt.")
	return true

func _test_rejects_occupied_cell() -> bool:
	var twin := LetterBag.new(TEST_SEED)
	var twin_ref := HeadlessGame.new()
	twin_ref.setup(TEST_SEED, false)
	var first_letter: String = twin.random_letter()
	var second_letter: String = twin.random_letter()

	var log := GameEventLog.new()
	log.begin("cheat-test-2", TEST_SEED, false)
	log.log_place(first_letter, 0, 0)
	log.log_place(second_letter, 0, 0)  # same cell again

	var result: Dictionary = GameReplayer.replay(log.to_dictionary())
	if result["valid"]:
		printerr("[FAIL] Replay accepted a placement onto an occupied cell.")
		return false

	print("[PASS] Replay rejects placement onto an occupied cell.")
	return true

## The resume case: a log with no finish event must replay cleanly and
## leave the game in a not-over state, ready to be continued.
func _test_unfinished_log_replays_for_resume() -> bool:
	var log := GameEventLog.new()
	log.begin("resume-test", TEST_SEED, false)
	var twin := LetterBag.new(TEST_SEED)
	for i in range(5):
		log.log_place(twin.random_letter(), i, 0)

	var result: Dictionary = GameReplayer.replay(log.to_dictionary())
	if not result["valid"]:
		printerr("[FAIL] Unfinished log failed replay: %s" % result["errors"])
		return false
	if result["game"].game_over:
		printerr("[FAIL] Resumed game should not be game over.")
		return false

	print("[PASS] Unfinished log replays cleanly (resume case).")
	return true
