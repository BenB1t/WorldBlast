extends RefCounted
class_name WordAvailabilityTracker

## Implements architecture doc Section 8: "A word may be cashed in only
## once per ranked game," keyed on the WORD ITSELF, not its board location.
## "ART" cleared at one position must not be clearable again anywhere
## else on the board for the rest of that game.
##
## This is deliberately its own small class rather than being built into
## WordGrid directly, per the doc's Section 66 principle: casual and
## ranked share the same WordGrid/WordFinder/ScoreRules, with different
## AUTHORITY layered on top. WordGrid gets an optional
## `availability_tracker` reference — null in casual play (no filtering,
## identical to today's behavior), a real instance in ranked play.
##
## Recommended behavior per the doc: a previously consumed word should
## simply not become a valid pending word again — no error, no special
## feedback, it just silently stops highlighting. This avoids the
## confusing case of a player tapping a highlighted word and nothing
## happening.

var used_words: Dictionary = {}  # word (String) -> true


func is_available(word: String) -> bool:
	return not used_words.has(word)


func mark_used(word: String) -> void:
	used_words[word] = true


## Convenience for a fresh game / rematch without re-instantiating.
func reset() -> void:
	used_words.clear()
