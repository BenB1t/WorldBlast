extends RefCounted
class_name ScoreRules

const BASE_BY_LENGTH: Dictionary = {3: 30, 4: 60, 5: 100, 6: 150, 7: 220}
const FALLBACK_BASE: int = 300  # 8-letter words (max on an 8x8 board)

## Multiplies LetterValues.value_of_word() before adding it to the base.
## Raw Scrabble values are small (1-10 per letter), so this scales them up
## to be meaningful next to the length-based base score above.
const LETTER_VALUE_MULTIPLIER: int = 10

const CASCADE_STEP: float = 0.5   # +50% per cascade depth level
const COMBO_STEP: float = 0.25    # +25% per consecutive-clear combo count


## cascade_depth: how many gravity-triggered waves led to this word (0 for
## the first, direct match). combo_count: consecutive placements in a row
## that produced at least one clear, tracked externally in game state.
static func score_word(word: String, cascade_depth: int, combo_count: int) -> int:
	var base: int = BASE_BY_LENGTH.get(word.length(), FALLBACK_BASE)
	var letter_bonus: int = LetterValues.value_of_word(word) * LETTER_VALUE_MULTIPLIER

	var cascade_multiplier: float = 1.0 + CASCADE_STEP * cascade_depth
	var combo_multiplier: float = 1.0 + COMBO_STEP * combo_count

	return int(round((base + letter_bonus) * cascade_multiplier * combo_multiplier))
