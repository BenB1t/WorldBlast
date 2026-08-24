extends RefCounted
class_name LetterBag

## Rough English letter frequency, tuned (not exact Scrabble distribution)
## so common letters and vowels come up often enough that words are
## reliably achievable — matches the design goal that failure should feel
## caused by the player's placement decisions, not letter-supply bad luck.
const WEIGHTS: Dictionary = {
	"E": 12, "A": 9, "I": 9, "O": 8, "U": 5,
	"N": 6, "R": 6, "T": 6, "L": 4, "S": 6,
	"D": 4, "G": 3,
	"B": 2, "C": 2, "M": 2, "P": 2,
	"F": 2, "H": 2, "V": 1, "W": 2, "Y": 2,
	"K": 1, "J": 1, "X": 1, "Q": 1, "Z": 1,
}

## Computed once (weights are const) and shared across all instances —
## this is just the sum of WEIGHTS.values(), not randomness, so it's safe
## to cache at the class level.
static var _total_weight: int = -1
static var _letters_in_weight_order: Array = []

## Each LetterBag owns its own RNG stream. This is the whole point of this
## rewrite: two LetterBag instances created with the same seed produce the
## exact same sequence of letters forever, regardless of what randomness
## anything else in the game (e.g. grid.gd's shake tween) consumes. Using
## Godot's global randi()/randf() instead would make the sequence depend
## on call-order across totally unrelated systems, which breaks replay.
var _rng: RandomNumberGenerator


## seed: pass the ranked game's seed for deterministic play. Leave omitted
## (or pass -1) for casual play, where each bag randomizes itself normally
## via the OS's entropy source, same as before this rewrite.
func _init(rng_seed: int = -1) -> void:
	_rng = RandomNumberGenerator.new()
	if rng_seed < 0:
		_rng.randomize()
	else:
		_rng.seed = rng_seed

	if _total_weight < 0:
		_total_weight = 0
		_letters_in_weight_order = WEIGHTS.keys()
		for w in WEIGHTS.values():
			_total_weight += w


func random_letter() -> String:
	var roll: int = _rng.randi() % _total_weight
	var cumulative := 0
	for letter in _letters_in_weight_order:
		cumulative += WEIGHTS[letter]
		if roll < cumulative:
			return letter
	return "E"  # unreachable fallback
