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

static var _total_weight: int = -1


static func random_letter() -> String:
	if _total_weight < 0:
		_total_weight = 0
		for w in WEIGHTS.values():
			_total_weight += w

	var roll := randi() % _total_weight
	var cumulative := 0
	for letter in WEIGHTS.keys():
		cumulative += WEIGHTS[letter]
		if roll < cumulative:
			return letter
	return "E"  # unreachable fallback
