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

## Piece shapes: single, duo and trio — horizontal and vertical.
## Offsets are relative to the piece's anchor (top-left of its bounding
## box), so placement math is just anchor + offset.
const SHAPES: Dictionary = {
	"S":  [Vector2i(0, 0)],
	"H2": [Vector2i(0, 0), Vector2i(1, 0)],
	"V2": [Vector2i(0, 0), Vector2i(0, 1)],
	"H3": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	"V3": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)],
}
const SHAPE_IDS: Array = ["S", "H2", "V2", "H3", "V3"]

## Relative spawn odds per shape — edit freely to tune the mix.
## They are relative weights, not percentages, so any numbers work:
##   [100, 0, 0, 0, 0]    -> singles only (current)
##   [34, 22, 22, 11, 11] -> balanced mix
##   [0, 50, 50, 0, 0]    -> duos only
##   [0, 0, 0, 50, 50]    -> trios only
##   [2, 1, 1, 0, 0]      -> mostly singles with occasional duos
const SHAPE_WEIGHTS: Array = [100, 0, 0, 0, 0]

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


## Shared helper so every system (piece, tray, grid, headless replay)
## agrees on a shape's cell offsets. Never mutate the returned array.
static func offsets_for(shape: String) -> Array:
	return SHAPES.get(shape, [Vector2i(0, 0)])


## Draws one full piece: exactly one shape roll, then one letter roll per
## cell in offset order. The fixed draw order is what keeps the live game
## and the headless replay bit-for-bit identical.
func random_piece() -> Dictionary:
	var shape: String = _pick_shape()
	var letters: Array = []
	for i in range(SHAPES[shape].size()):
		letters.append(random_letter())
	return {"shape": shape, "letters": letters}


func _pick_shape() -> String:
	var total: int = 0
	for w in SHAPE_WEIGHTS:
		total += int(w)
	# Safety: an all-zeros config must never crash the RNG.
	if total <= 0:
		return "S"
	var roll: int = _rng.randi_range(1, total)
	var acc := 0
	for i in range(SHAPE_IDS.size()):
		acc += int(SHAPE_WEIGHTS[i])
		if roll <= acc:
			return SHAPE_IDS[i]
	return "S"
