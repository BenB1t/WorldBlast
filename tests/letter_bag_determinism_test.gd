## Headless determinism test for LetterBag.
##
## Run from the command line (no editor needed):
##   godot --headless --script res://tests/letter_bag_determinism_test.gd
##
## Verifies the one property the entire ranked architecture depends on
## (see Section 67 of the architecture doc): two LetterBag instances
## created with the SAME seed must produce the EXACT SAME sequence of
## letters, forever — regardless of what else is going on in the game.
##
## Also verifies the negative case: two DIFFERENT seeds should (almost
## certainly) diverge, so we know the seed is actually being used and
## this isn't accidentally passing because everything returns the same
## thing regardless of seed.
extends SceneTree

const DRAW_COUNT: int = 500
const SAME_SEED: int = 12345
const OTHER_SEED: int = 67890


func _init() -> void:
	var all_passed := true

	all_passed = _test_same_seed_matches() and all_passed
	all_passed = _test_different_seed_diverges() and all_passed
	all_passed = _test_shake_rng_does_not_affect_bag() and all_passed

	if all_passed:
		print("\n[PASS] All LetterBag determinism tests passed.")
	else:
		printerr("\n[FAIL] One or more LetterBag determinism tests failed.")

	quit(0 if all_passed else 1)


func _draw_sequence(bag: LetterBag, count: int) -> Array:
	var out: Array = []
	for i in range(count):
		out.append(bag.random_letter())
	return out


func _test_same_seed_matches() -> bool:
	var bag_a := LetterBag.new(SAME_SEED)
	var bag_b := LetterBag.new(SAME_SEED)

	var seq_a := _draw_sequence(bag_a, DRAW_COUNT)
	var seq_b := _draw_sequence(bag_b, DRAW_COUNT)

	if seq_a == seq_b:
		print("[PASS] Same seed (%d) produced identical %d-letter sequences." % [SAME_SEED, DRAW_COUNT])
		return true

	printerr("[FAIL] Same seed (%d) produced DIFFERENT sequences." % SAME_SEED)
	var first_diff := -1
	for i in range(min(seq_a.size(), seq_b.size())):
		if seq_a[i] != seq_b[i]:
			first_diff = i
			break
	printerr("       First divergence at index %d: %s vs %s" % [first_diff, seq_a[first_diff], seq_b[first_diff]])
	return false


func _test_different_seed_diverges() -> bool:
	var bag_a := LetterBag.new(SAME_SEED)
	var bag_c := LetterBag.new(OTHER_SEED)

	var seq_a := _draw_sequence(bag_a, DRAW_COUNT)
	var seq_c := _draw_sequence(bag_c, DRAW_COUNT)

	if seq_a != seq_c:
		print("[PASS] Different seeds (%d vs %d) produced different sequences." % [SAME_SEED, OTHER_SEED])
		return true

	printerr("[FAIL] Different seeds (%d vs %d) produced the IDENTICAL sequence — seed is not being used." % [SAME_SEED, OTHER_SEED])
	return false


## Interleaves draws from a seeded LetterBag with calls to an independent
## RandomNumberGenerator standing in for grid.gd's _shake_rng, simulating
## a player triggering shakes between letter draws. If LetterBag were
## still using the global randi() stream, interleaved calls to a
## DIFFERENT global-stream consumer would shift its output. Since
## LetterBag now owns its own RNG instance, this interleaving must have
## zero effect on the letter sequence.
func _test_shake_rng_does_not_affect_bag() -> bool:
	var bag_isolated := LetterBag.new(SAME_SEED)
	var seq_isolated := _draw_sequence(bag_isolated, DRAW_COUNT)

	var bag_interleaved := LetterBag.new(SAME_SEED)
	var fake_shake_rng := RandomNumberGenerator.new()
	fake_shake_rng.randomize()

	var seq_interleaved: Array = []
	for i in range(DRAW_COUNT):
		# Simulate a shake happening between every letter draw.
		fake_shake_rng.randf_range(-0.03, 0.03)
		fake_shake_rng.randf_range(-0.01, 0.01)
		seq_interleaved.append(bag_interleaved.random_letter())

	if seq_isolated == seq_interleaved:
		print("[PASS] Interleaved shake-RNG calls did not affect LetterBag's sequence.")
		return true

	printerr("[FAIL] LetterBag's sequence changed when an unrelated RNG was interleaved — streams are not isolated.")
	return false
