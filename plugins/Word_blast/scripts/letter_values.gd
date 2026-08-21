extends RefCounted
class_name LetterValues

## Standard Scrabble letter values. Rarer letters (Q, Z, X, J) score more,
## rewarding the player for working awkward letters into a word rather
## than just dumping them wherever fits.
const VALUES: Dictionary = {
	"A": 1, "B": 3, "C": 3, "D": 2, "E": 1, "F": 4, "G": 2, "H": 4,
	"I": 1, "J": 8, "K": 5, "L": 1, "M": 3, "N": 1, "O": 1, "P": 3,
	"Q": 10, "R": 1, "S": 1, "T": 1, "U": 1, "V": 4, "W": 4, "X": 8,
	"Y": 4, "Z": 10,
}


static func value_of(letter: String) -> int:
	return VALUES.get(letter, 0)


static func value_of_word(word: String) -> int:
	var total: int = 0
	for letter in word:
		total += VALUES.get(letter, 0)
	return total
