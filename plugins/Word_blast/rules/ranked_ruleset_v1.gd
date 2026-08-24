extends Resource
class_name RankedRuleset

## Frozen definition of "ranked_v1" — per architecture doc Section 68,
## Phase 2: "Freeze the rules. Do not change these casually after scores
## are published."
##
## Every value here was confirmed against the ACTUAL engine behavior at
## freeze time (grid.gd, word_finder.gd, score_rules.gd, letter_bag.gd),
## not assumed from the design doc — see the comment on each field for
## which file/line it was verified against.
##
## HOW TO USE THIS FILE SAFELY:
## Once ranked_v1 games have been played and scores published/stored,
## THIS FILE MUST NOT BE EDITED. If any rule needs to change, create a
## new resource — RankedRulesetV2 or similar, with ruleset_id = "ranked_v2"
## — and let old ranked_v1 games keep pointing at ranked_v1 forever.
## Every stored game/score should record which ruleset_id it was played
## under (see the doc's D1 `rulesets` table in Section 68/Phase 5), so a
## rule change never silently invalidates or reinterprets historical
## results. Treat this file as append-only across its lifetime: once
## published, immutable.

## Identifies which frozen ruleset a game was played under. Stored
## alongside every ranked game record so historical scores stay
## interpretable even after ranked_v2, v3, etc. exist.
const RULESET_ID: String = "ranked_v1"

## --- Board ---------------------------------------------------------
## Verified: grid.gd, GRID_SIZE = 8. 8x8 = 64 cells.
const GRID_SIZE: int = 8

## --- Word direction --------------------------------------------------
## Verified: word_finder.gd, find_words_through() only scans
## Vector2i(1,0) [horizontal, left-to-right] and Vector2i(0,1)
## [vertical, top-to-bottom]. No reverse, no diagonals.
## (Reverse reading was prototyped during development and explicitly
## reverted — see word_finder.gd's class comment — because it surfaces
## words the player didn't intentionally spell, e.g. "LIT" also
## silently matching "TIL" backward. Confusing rather than rewarding,
## especially for players less familiar with reversed/uncommon words.)
const ALLOW_REVERSE_WORDS: bool = false
const ALLOW_DIAGONAL_WORDS: bool = false

## --- Word formation ---------------------------------------------------
## Verified: word_finder.gd checks ALL valid substrings length >= 3
## within a run, not just the longest. E.g. "START" can simultaneously
## contain "STAR", "START", "TART" as separate pending matches.
const MIN_WORD_LENGTH: int = 3
const FIND_ALL_SUBSTRINGS_NOT_JUST_LONGEST: bool = true

## --- Clearing behavior -------------------------------------------------
## Verified: grid.gd — words do NOT auto-clear on formation. They sit as
## "pending" (highlighted/pulsing) until the player taps them.
const MANUAL_CLEARING: bool = true

## Verified: grid.gd — no gravity. Cleared cells become empty and STAY
## empty until a new piece is placed directly into them. There is no
## automatic cascade; words_cleared always emits cascade_depth = 0.
const GRAVITY_ENABLED: bool = false

## Verified: grid.gd _clear_connected_group() — tapping one pending word
## clears it AND any other pending word that transitively shares a cell
## with it (connected-components over "shares a cell"), even if that
## other word is otherwise unrelated in meaning/location.
const CONNECTED_OVERLAP_CLEARING: bool = true

## --- Word reuse ---------------------------------------------------------
## Verified: word_availability_tracker.gd + grid.gd integration. A word
## may score points only once per ranked game, keyed on the WORD ITSELF
## (not board location/cells). A repeated word still CLEARS normally
## (stays satisfying, keeps the board playable) but contributes ZERO
## points on every clear after the first.
const WORD_REUSE_ALLOWED: bool = true
const REUSED_WORD_SCORE_MULTIPLIER: float = 0.0

## --- Letter generation ---------------------------------------------------
## Verified: letter_bag.gd. Weighted-random, NOT board-aware — the bag
## has no knowledge of the current board or tray state, it only biases
## toward common English letter frequency (see letter_bag.gd's WEIGHTS
## dict for the exact table). Deliberately kept simple for ranked_v1:
## "same seed -> same letter sequence" only needs to reproduce a fixed
## weight table plus a seeded RNG, not replicate board-aware logic
## client and server side. Board-aware selection is a possible future
## ranked_v2+ feature, not part of this frozen ruleset.
const LETTER_GENERATION_IS_BOARD_AWARE: bool = false

## --- Scoring --------------------------------------------------------
## Verified: score_rules.gd. Pure function of
## (word, cascade_depth, combo_count) — no hidden state, fully
## reproducible by a server given the same inputs. cascade_depth is
## always 0 in ranked_v1 since GRAVITY_ENABLED is false (kept as a
## parameter for forward compatibility, not because cascades occur).
const BASE_SCORE_BY_LENGTH: Dictionary = {3: 30, 4: 60, 5: 100, 6: 150, 7: 220}
const FALLBACK_BASE_SCORE_8PLUS: int = 300
const LETTER_VALUE_MULTIPLIER: int = 10
const CASCADE_STEP: float = 0.5
const COMBO_STEP: float = 0.25

## --- Game over ---------------------------------------------------------
## Verified: word_blast_game.gd _check_game_over(). The board being
## completely full is NOT sufficient for game over on its own — if
## there is at least one pending (tappable) word on the full board, the
## player still has a legal move (tap to clear, freeing cells), so the
## game continues. True game over requires: board full AND no pending
## matches. (This specifically fixes the case where the placement that
## fills the last empty cell is also the placement that completes a
## word — the board is full for one frame, but the player hasn't
## actually run out of options.)
const GAME_OVER_REQUIRES_NO_PENDING_MATCHES: bool = true
