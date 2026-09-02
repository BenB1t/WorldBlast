extends RefCounted
class_name HeadlessGame
## Headless, Node-free mirror of the authoritative Word Blast rules:
## grid placement / pending / clear logic from grid.gd, tray + bag flow
## from letter_tray.gd, and combo / score / game-over state from
## word_blast_game.gd.
##
## Two consumers:
##   1. GameReplayer replays event logs through this class to verify a
##      claimed game (anti-cheat foundation, becomes the Worker logic later).
##   2. Save/resume: a saved game IS (seed + event log). Resuming means
##      replaying that log through this class and hydrating the visual
##      scene from the resulting state.
##
## Determinism contract: same seed + same events + same ranked flag
## ALWAYS produces identical final state. Nothing visual (shake, pop
## animations, layout) may ever touch this class. Skins are carried as
## passive metadata only, so resume can restore the board's look.

const GRID_SIZE: int = 8
const TRAY_SIZE: int = 3
const COMBO_RESET_TURNS: int = 3  # mirrors word_blast_game.gd

var game_seed: int = -1
var is_ranked: bool = false

var letter_bag: LetterBag = null
var availability_tracker: WordAvailabilityTracker = null  # ranked only, else null

var cells: Array = []   # cells[y][x] = "" or a single uppercase letter
var skins: Array = []   # skins[y][x] = skin id, passive metadata only
var tray: Array = []    # the 3 pieces (Dictionaries) currently offered to the player
var pending_matches: Array = []

var score: int = 0
var combo_count: int = 0
var turns_since_last_clear: int = 0
var game_over: bool = false

## bag_override exists ONLY for unit tests (scripted letter sequences).
## Production paths and GameReplayer must never use it — the whole point
## is that seed -> LetterBag reproduces the real letter stream.
func setup(seed: int, ranked: bool, bag_override: LetterBag = null) -> void:
	game_seed = seed
	is_ranked = ranked
	letter_bag = bag_override if bag_override != null else LetterBag.new(seed)
	availability_tracker = WordAvailabilityTracker.new() if ranked else null
	score = 0
	combo_count = 0
	turns_since_last_clear = 0
	game_over = false
	pending_matches = []
	_reset_cells()
	tray.clear()
	# LetterTray._ready() -> refill() draws 3 pieces up front; mirror that.
	for i in range(TRAY_SIZE):
		tray.append(letter_bag.random_piece())

# =============================================================================
# EVENTS
# =============================================================================

## Applies a "place" event for a multi-cell piece. Mirrors the live path:
## the drag is blocked after game over, the drop requires all cells to be
## empty and in bounds, the piece must match the tray slot, and the slot
## refills immediately, then turns_since_last_clear increments and game
## over is re-checked.
## Returns {"valid": bool, "reason": String}.
func apply_place_piece(shape: String, letters: Array, x: int, y: int, slot: int, skin_id: String = "") -> Dictionary:
	if game_over:
		return {"valid": false, "reason": "game_over"}
	
	# If skin_id is empty (old save), generate a random one so the grid looks nice
	if skin_id == "":
		skin_id = LetterTile.random_skin_id()
	
	var offs := LetterBag.offsets_for(shape)
	var anchor := Vector2i(x, y)
	
	for o in offs:
		var p: Vector2i = anchor + o
		if not is_in_bounds(p):
			return {"valid": false, "reason": "out_of_bounds"}
		if cells[p.y][p.x] != "":
			return {"valid": false, "reason": "cell_occupied"}
	
	if slot < 0 or slot >= tray.size():
		return {"valid": false, "reason": "invalid_slot"}
	
	for i in range(offs.size()):
		var p: Vector2i = anchor + offs[i]
		cells[p.y][p.x] = letters[i]
		skins[p.y][p.x] = skin_id
	
	tray[slot] = letter_bag.random_piece()
	_rescan_pending_matches()
	turns_since_last_clear += 1
	_check_game_over()
	return {"valid": true, "reason": ""}
	
	
	
## Legacy single-letter placement. Kept so the replayer can detect old saves
## and fail them cleanly (the tray/bag model changed with pieces).
func apply_place(letter: String, x: int, y: int, skin_id: String = "") -> Dictionary:
	return {"valid": false, "reason": "legacy_single_letter_not_supported"}

## Applies a "clear" event (player tapped cell x,y). Mirrors grid.gd
## _handle_tap -> _clear_connected_group plus word_blast_game scoring.
## If no pending word covers that cell this was a no-op in the live game
## too, so the replayer accepts it silently rather than failing.
func apply_clear(x: int, y: int) -> Dictionary:
	var pos := Vector2i(x, y)
	var tapped = _find_pending_match_at(pos)
	if tapped == null:
		return {"cleared": false}
	_clear_connected_group(tapped)
	return {"cleared": true}

# =============================================================================
# GRID LOGIC — line-for-line mirror of grid.gd (no rendering)
# =============================================================================

func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_SIZE and pos.y >= 0 and pos.y < GRID_SIZE

func has_any_empty_cell() -> bool:
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if cells[y][x] == "":
				return true
	return false

func _reset_cells() -> void:
	cells.clear()
	skins.clear()
	for y in range(GRID_SIZE):
		var row: Array = []
		row.resize(GRID_SIZE)
		row.fill("")
		cells.append(row)
		var skin_row: Array = []
		skin_row.resize(GRID_SIZE)
		skin_row.fill("")
		skins.append(skin_row)

func _rescan_pending_matches() -> void:
	var found: Dictionary = {}
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if cells[y][x] == "":
				continue
			var matches: Array = WordFinder.find_words_through(cells, GRID_SIZE, y, x)
			for m in matches:
				var key: String = m["word"] + ":" + str(m["cells"])
				found[key] = m
	pending_matches = found.values()

func _find_pending_match_at(cell: Vector2i):
	for m in pending_matches:
		if cell in m["cells"]:
			return m
	return null

## Exact structural copy of grid.gd's _clear_connected_group (same DFS
## order — group order matters for the sequential already_used check
## below), followed by word_blast_game._on_words_cleared scoring with
## cascade_depth = 0.
func _clear_connected_group(start_match: Dictionary) -> void:
	var group: Array = []
	var visited: Dictionary = {}
	var to_visit: Array = [start_match]
	visited[pending_matches.find(start_match)] = true
	while not to_visit.is_empty():
		var current: Dictionary = to_visit.pop_back()
		group.append(current)
		var current_cells: Dictionary = {}
		for c in current["cells"]:
			current_cells[c] = true
		for i in range(pending_matches.size()):
			if visited.has(i):
				continue
			var other: Dictionary = pending_matches[i]
			var shares_cell := false
			for c in other["cells"]:
				if current_cells.has(c):
					shares_cell = true
					break
			if shares_cell:
				visited[i] = true
				to_visit.append(other)

	var cleared_set: Dictionary = {}
	for m in group:
		for c in m["cells"]:
			cleared_set[c] = true

	# Same check-then-mark ordering as grid.gd: sequential per match, so a
	# second occurrence of the same word inside one connected clear already
	# sees it as used. Do not reorder without changing grid.gd to match.
	if availability_tracker != null:
		for m in group:
			m["already_used"] = not availability_tracker.is_available(m["word"])
			availability_tracker.mark_used(m["word"])
	else:
		for m in group:
			m["already_used"] = false

	for c in cleared_set.keys():
		cells[c.y][c.x] = ""
		skins[c.y][c.x] = ""

	# --- scoring: mirror of _on_words_cleared(matches, 0) ---
	if turns_since_last_clear > COMBO_RESET_TURNS:
		combo_count = 0
	turns_since_last_clear = 0
	var wave_points: int = 0
	for m in group:
		var word_points: int = ScoreRules.score_word(m["word"], 0, combo_count)
		# Live code checks `active_ruleset != null`; that is exactly
		# is_ranked, since the ruleset is only assigned for ranked games.
		if m.get("already_used", false) and is_ranked:
			word_points = int(round(word_points * RankedRuleset.REUSED_WORD_SCORE_MULTIPLIER))
		wave_points += word_points
	score += wave_points
	combo_count += 1

	_rescan_pending_matches()

# =============================================================================
# GAME OVER — mirror of word_blast_game._check_game_over
# =============================================================================

func _check_game_over() -> void:
	if has_any_empty_cell():
		return
	if not pending_matches.is_empty():
		return
	game_over = true
