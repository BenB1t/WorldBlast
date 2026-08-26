extends Control
class_name WordGrid

const GRID_SIZE: int = 8
const CELL_GAP: int = 3          # inset per side of a cell (gap between cells = 2x)
const BOARD_PADDING: int = 10    # white margin between panel edge and first cell
const BOARD_RADIUS: int = 14     # panel corner radius
const CELL_RADIUS: int = 8       # socket corner radius

## New clean look: floating white panel + light gray rounded sockets.
const BOARD_BG_COLOR: Color = Color.WHITE
const BOARD_SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.18)
const EMPTY_CELL_COLOR: Color = Color(0.925, 0.925, 0.94)
const CELL_BORDER_COLOR: Color = Color(0.82, 0.83, 0.86)
const PENDING_HIGHLIGHT: Color = Color(1.0, 0.831, 0.29, 0.35)

## Pop-in animation played on a tile when it's placed.
const POP_DURATION: float = 0.18

## Pending-word highlight pulses between these two alpha values instead of
## sitting at a flat opacity, so tappable words visibly "breathe" and draw
## the eye without needing a tutorial.
const PULSE_SPEED: float = 3.0
const PULSE_MIN_ALPHA: float = 0.22
const PULSE_MAX_ALPHA: float = 0.55

## Emitted once when the player taps a word to clear it. cascade_depth is
## always 0 — there is no gravity, so there are no automatic cascade waves.
## The parameter is kept so existing callers (e.g. scoring code) don't break.
signal words_cleared(matches: Array, cascade_depth: int, tapped_cell: Vector2i)

var cells: Array = []  # cells[y][x] = "" or a single uppercase letter
var skins: Array = []  # cells[y][x] = skin_id string, cosmetic only

## Valid words currently sitting on the board, NOT yet cleared. The player
## must tap one to cash it in — this is what lets "SEA" sit around long
## enough to become "SEAT" instead of vanishing the instant it forms.
## Each entry: {word: String, cells: Array[Vector2i]}
var pending_matches: Array = []

var preview_cell: Vector2i = Vector2i(-1, -1)
var preview_valid: bool = true

## Optional. Left null in casual play, in which case word reuse is
## unrestricted (identical to pre-Section-8 behavior). Assign a real
## WordAvailabilityTracker instance for ranked play — see that class for
## the full rationale. Set this any time before the first
## place_letter() call (or before any words could already be pending).
var availability_tracker: WordAvailabilityTracker = null

## Internal running clock (seconds) used to drive the pop-in and pulse
## animations. Vector2i -> time (in this clock) the tile was placed.
var _elapsed: float = 0.0
var _placement_times: Dictionary = {}

var _clear_effect: WordClearEffect
var _shake_tween: Tween

## Shake jitter is purely cosmetic — it never affects `cells`, so it does
## NOT need to be deterministic/seeded. It gets its own RNG instance
## specifically so it can never share (and therefore never desync) the
## LetterBag's seeded stream, which DOES need to stay reproducible for
## ranked replay. Using Godot's global randf_range() here would silently
## consume rolls from whatever stream LetterBag might also be drawing
## from, if the two were ever coupled by future refactors.
var _shake_rng := RandomNumberGenerator.new()

## Pre-created once so _draw() never allocates StyleBoxes per frame.
var _sb_board_shadow: StyleBoxFlat
var _sb_board: StyleBoxFlat
var _sb_cell: StyleBoxFlat
var _sb_pulse: StyleBoxFlat
var _sb_preview: StyleBoxFlat


func _ready() -> void:
	_reset_cells()
	_init_styleboxes()
	_clear_effect = WordClearEffect.new()
	add_child(_clear_effect)
	refresh_layout()
	set_process(true)
	_shake_rng.randomize()


func _init_styleboxes() -> void:
	_sb_board_shadow = StyleBoxFlat.new()
	_sb_board_shadow.bg_color = BOARD_SHADOW_COLOR
	_sb_board_shadow.set_corner_radius_all(BOARD_RADIUS)

	_sb_board = StyleBoxFlat.new()
	_sb_board.bg_color = BOARD_BG_COLOR
	_sb_board.set_corner_radius_all(BOARD_RADIUS)

	_sb_cell = StyleBoxFlat.new()
	_sb_cell.bg_color = EMPTY_CELL_COLOR
	_sb_cell.border_color = CELL_BORDER_COLOR
	_sb_cell.set_border_width_all(2)
	_sb_cell.set_corner_radius_all(CELL_RADIUS)

	_sb_pulse = StyleBoxFlat.new()
	_sb_pulse.set_corner_radius_all(CELL_RADIUS)

	_sb_preview = StyleBoxFlat.new()
	_sb_preview.set_corner_radius_all(CELL_RADIUS)


func _process(delta: float) -> void:
	_elapsed += delta

	# Keep redrawing every frame while there's a pop-in animation still
	# playing or any word is pulsing on the board; otherwise stay idle so
	# we're not burning cycles on a static grid.
	var animating_pop := false
	for t in _placement_times.values():
		if _elapsed - t < POP_DURATION:
			animating_pop = true
			break

	if animating_pop or not pending_matches.is_empty():
		queue_redraw()


func _reset_cells() -> void:
	cells.clear()
	skins.clear()
	_placement_times.clear()
	for y in range(GRID_SIZE):
		var row: Array = []
		row.resize(GRID_SIZE)
		row.fill("")
		cells.append(row)
		var skin_row: Array = []
		skin_row.resize(GRID_SIZE)
		skin_row.fill("")
		skins.append(skin_row)


func refresh_layout() -> void:
	var side: int = GRID_SIZE * BlockBlastLayout.cell_size + BOARD_PADDING * 2
	custom_minimum_size = Vector2(side, side)
	queue_redraw()


# =============================================================================
# QUERIES
# =============================================================================

func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_SIZE and pos.y >= 0 and pos.y < GRID_SIZE


func is_cell_empty(pos: Vector2i) -> bool:
	if not is_in_bounds(pos):
		return false
	return cells[pos.y][pos.x] == ""


func has_any_empty_cell() -> bool:
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if cells[y][x] == "":
				return true
	return false


## Rect of one cell in LOCAL grid coordinates, including the white
## board padding. Every draw + hit-test goes through this so the math
## can never drift out of sync.
func _cell_rect(x: int, y: int) -> Rect2:
	var cell_size: int = BlockBlastLayout.cell_size
	return Rect2(
		Vector2(BOARD_PADDING + x * cell_size + CELL_GAP, BOARD_PADDING + y * cell_size + CELL_GAP),
		Vector2(cell_size - CELL_GAP * 2, cell_size - CELL_GAP * 2)
	)


# =============================================================================
# PLACEMENT — no longer auto-clears. Just places the letter and refreshes
# the list of valid-but-uncleared words on the board.
# =============================================================================

func place_letter(pos: Vector2i, letter: String, skin_id: String) -> void:
	cells[pos.y][pos.x] = letter
	skins[pos.y][pos.x] = skin_id
	_placement_times[pos] = _elapsed
	_rescan_pending_matches()
	queue_redraw()


## Rebuilds pending_matches from scratch by scanning every occupied cell.
## The board is only 8x8, so this is cheap enough to just redo fully
## rather than track incremental diffs — much simpler to get right.
##
## Note: this does NOT filter out already-used words (see
## availability_tracker). A repeated word still becomes pending and is
## still tappable/clearable — it's just worth zero points the second
## time. See _clear_connected_group(), which is where that's enforced.
func _rescan_pending_matches() -> void:
	var found: Dictionary = {}  # dedupe key -> match dict
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if cells[y][x] == "":
				continue
			var matches: Array = WordFinder.find_words_through(cells, GRID_SIZE, y, x)
			for m in matches:
				var key: String = m["word"] + ":" + str(m["cells"])
				found[key] = m

	pending_matches = found.values()


# =============================================================================
# CLEARING — a deliberate player action (tap a highlighted word). Clears
# exactly the tapped word's cells and nothing else — no gravity, no
# cascades. Cleared cells become empty and stay empty until a new piece
# is placed there directly.
# =============================================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_tap(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_handle_tap(event.position)


func _handle_tap(local_pos: Vector2) -> void:
	var cell_size: int = BlockBlastLayout.cell_size
	if cell_size <= 0:
		return
	# Account for the white board padding before converting to a cell index.
	var cell := Vector2i(
		int((local_pos.x - BOARD_PADDING) / cell_size),
		int((local_pos.y - BOARD_PADDING) / cell_size)
	)
	if not is_in_bounds(cell):
		return

	var tapped_match = _find_pending_match_at(cell)
	if tapped_match != null:
		_clear_connected_group(tapped_match, cell)


func _find_pending_match_at(cell: Vector2i):
	for m in pending_matches:
		if cell in m["cells"]:
			return m
	return null


## Tapping a highlighted cell clears that word AND any other pending word
## that shares a cell with it (transitively) — e.g. "SIDE" and "DIE"
## sharing the D — but leaves unrelated words elsewhere on the board
## (e.g. "HAT") untouched. This is a connected-components walk over
## pending_matches using "shares a cell" as the edge.
func _clear_connected_group(start_match: Dictionary, tapped_cell: Vector2i) -> void:
	var group: Array = []
	var visited: Dictionary = {}  # match index -> true

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

	# Tag each match with whether it was ALREADY used before this clear —
	# checked before mark_used() below, since mark_used() would otherwise
	# make every word look "already used" by the time anyone can ask.
	# word_blast_game.gd reads this tag to award zero points for a
	# repeat, while still letting the clear itself happen normally (the
	# word still visually clears — it's just worth nothing the 2nd+ time).
	if availability_tracker != null:
		for m in group:
			m["already_used"] = not availability_tracker.is_available(m["word"])
			availability_tracker.mark_used(m["word"])
	else:
		for m in group:
			m["already_used"] = false

	var cleared_info: Array = []
	for c in cleared_set.keys():
		cleared_info.append({"pos": c, "letter": cells[c.y][c.x], "skin_id": skins[c.y][c.x]})
		cells[c.y][c.x] = ""
		skins[c.y][c.x] = ""
		_placement_times.erase(c)

	# Left-to-right, top-to-bottom order so the clear effect reads as a
	# sweep across the word(s) rather than firing in random dictionary order.
	cleared_info.sort_custom(func(a, b):
		if a["pos"].y != b["pos"].y:
			return a["pos"].y < b["pos"].y
		return a["pos"].x < b["pos"].x
	)

	words_cleared.emit(group, 0, tapped_cell)

	if cleared_info.size() > 0:
		_clear_effect.play(cleared_info)
		_shake(cleared_info.size())

	_rescan_pending_matches()
	queue_redraw()


# =============================================================================
# PLACEMENT PREVIEW (single-cell hover — pieces are single letters)
# =============================================================================

func set_preview(pos: Vector2i, valid: bool) -> void:
	preview_cell = pos
	preview_valid = valid
	queue_redraw()


func clear_preview() -> void:
	if preview_cell == Vector2i(-1, -1):
		return
	preview_cell = Vector2i(-1, -1)
	queue_redraw()


# =============================================================================
# SHAKE
# =============================================================================

func _shake(letters_cleared: int) -> void:
	if _shake_tween and _shake_tween.is_running():
		_shake_tween.kill()

	pivot_offset = size * 0.5
	var shake_amount: float = clamp(2.0 + letters_cleared * 1.0, 2.0, 8.0)

	_shake_tween = create_tween()
	for i in range(3):
		var rot := _shake_rng.randf_range(-0.03, 0.03) * shake_amount
		var scl := Vector2(1.0, 1.0) + Vector2(_shake_rng.randf_range(-0.01, 0.01), _shake_rng.randf_range(-0.01, 0.01)) * shake_amount
		_shake_tween.tween_property(self, "rotation", rot, 0.035)
		_shake_tween.parallel().tween_property(self, "scale", scl, 0.035)

	_shake_tween.tween_property(self, "rotation", 0.0, 0.05)
	_shake_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.05)


# =============================================================================
# DRAWING — floating white rounded panel + rounded gray sockets
# =============================================================================

## Ease-out-back: overshoots slightly past 1.0 before settling, which reads
## as a satisfying little "pop" rather than a flat linear grow-in.
func _pop_scale(t: float) -> float:
	var x: float = clamp(t / POP_DURATION, 0.0, 1.0)
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


func _draw() -> void:
	# Floating white panel with a soft drop shadow underneath.
	var board_rect := Rect2(Vector2.ZERO, custom_minimum_size)
	var shadow_rect := Rect2(Vector2(0, 4), custom_minimum_size)
	_sb_board_shadow.draw(get_canvas_item(), shadow_rect)
	_sb_board.draw(get_canvas_item(), board_rect)

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var cell_rect := _cell_rect(x, y)
			var letter: String = cells[y][x]
			if letter == "":
				# Rounded light-gray socket with a subtle border.
				_sb_cell.draw(get_canvas_item(), cell_rect)
				continue

			var skin_id: String = skins[y][x]
			var tex: Texture2D = LetterTile.get_texture(letter, skin_id)

			var pos := Vector2i(x, y)
			var scale: float = 1.0
			if _placement_times.has(pos):
				var t: float = _elapsed - _placement_times[pos]
				if t < POP_DURATION:
					scale = max(_pop_scale(t), 0.0)

			var draw_rect_final: Rect2 = cell_rect
			if scale != 1.0:
				var center: Vector2 = cell_rect.get_center()
				var scaled_size: Vector2 = cell_rect.size * scale
				draw_rect_final = Rect2(center - scaled_size * 0.5, scaled_size)

			if tex:
				draw_texture_rect(tex, draw_rect_final, false)
			else:
				draw_rect(draw_rect_final, Color.DARK_CYAN)

	# Pulsing golden rounded highlight over every cell that's part of a
	# valid, tappable word currently sitting on the board.
	if not pending_matches.is_empty():
		var pulse_t: float = (sin(_elapsed * PULSE_SPEED) + 1.0) * 0.5  # 0..1
		var pulse_alpha: float = lerp(PULSE_MIN_ALPHA, PULSE_MAX_ALPHA, pulse_t)
		_sb_pulse.bg_color = Color(PENDING_HIGHLIGHT.r, PENDING_HIGHLIGHT.g, PENDING_HIGHLIGHT.b, pulse_alpha)
		for m in pending_matches:
			for c in m["cells"]:
				_sb_pulse.draw(get_canvas_item(), _cell_rect(c.x, c.y))

	if is_in_bounds(preview_cell):
		_sb_preview.bg_color = Color(0.2, 1.0, 0.4, 0.45) if preview_valid else Color(1.0, 0.2, 0.2, 0.45)
		_sb_preview.draw(get_canvas_item(), _cell_rect(preview_cell.x, preview_cell.y))


# =============================================================================
# SAVE/RESUME HYDRATION
# =============================================================================

## Injects a previously saved headless game state into the visual grid.
## Used by word_blast_game.gd to resume a game seamlessly after closing
## the app. Sets placement times in the past so the pop-in animation
## doesn't replay for tiles that were already on the board.
func load_snapshot(headless: HeadlessGame) -> void:
	_reset_cells()
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			cells[y][x] = headless.cells[y][x]
			skins[y][x] = headless.skins[y][x]
			if cells[y][x] != "":
				# Place it in the past so it doesn't play the pop animation on resume
				_placement_times[Vector2i(x, y)] = _elapsed - POP_DURATION
	pending_matches = headless.pending_matches.duplicate(true)
	queue_redraw()
