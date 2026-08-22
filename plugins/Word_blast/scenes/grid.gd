extends Control
class_name WordGrid

const GRID_SIZE: int = 8
const CELL_GAP: int = 2

const BOARD_BG_COLOR: Color = Color("EFE7D8")
const EMPTY_CELL_COLOR: Color = Color("E0D6C0")
const PENDING_HIGHLIGHT: Color = Color(1.0, 0.85, 0.2, 0.35)

## Emitted once per cascade wave with the matches cleared in that wave.
## cascade_depth is 0 for the word the player manually tapped to clear,
## 1+ for automatic cascade waves that followed from gravity.
signal words_cleared(matches: Array, cascade_depth: int)

var cells: Array = []  # cells[y][x] = "" or a single uppercase letter
var skins: Array = []  # cells[y][x] = skin_id string, cosmetic only

## Valid words currently sitting on the board, NOT yet cleared. The player
## must tap one to cash it in — this is what lets "SEA" sit around long
## enough to become "SEAT" instead of vanishing the instant it forms.
## Each entry: {word: String, cells: Array[Vector2i]}
var pending_matches: Array = []

var preview_cell: Vector2i = Vector2i(-1, -1)
var preview_valid: bool = true

var _clear_effect: WordClearEffect
var _shake_tween: Tween


func _ready() -> void:
	_reset_cells()
	_clear_effect = WordClearEffect.new()
	add_child(_clear_effect)
	refresh_layout()


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


func refresh_layout() -> void:
	custom_minimum_size = Vector2(
		GRID_SIZE * BlockBlastLayout.cell_size,
		GRID_SIZE * BlockBlastLayout.cell_size
	)
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


# =============================================================================
# PLACEMENT — no longer auto-clears. Just places the letter and refreshes
# the list of valid-but-uncleared words on the board.
# =============================================================================

func place_letter(pos: Vector2i, letter: String, skin_id: String) -> void:
	cells[pos.y][pos.x] = letter
	skins[pos.y][pos.x] = skin_id
	_rescan_pending_matches()
	queue_redraw()


## Rebuilds pending_matches from scratch by scanning every occupied cell.
## The board is only 8x8, so this is cheap enough to just redo fully
## rather than track incremental diffs — much simpler to get right.
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
# CLEARING — a deliberate player action (tap a highlighted word), not
# automatic. Cascades triggered by the resulting gravity DO auto-clear,
# since those are a bonus for the move rather than something the player
# was actively building toward.
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
	var cell := Vector2i(int(local_pos.x / cell_size), int(local_pos.y / cell_size))
	if not is_in_bounds(cell):
		return

	var tapped_match = _find_pending_match_at(cell)
	if tapped_match != null:
		_clear_match(tapped_match)


func _find_pending_match_at(cell: Vector2i):
	for m in pending_matches:
		if cell in m["cells"]:
			return m
	return null


func _clear_match(first_match: Dictionary) -> void:
	var cascade_depth: int = 0
	var matches_this_wave: Array = [first_match]

	while true:
		var cleared_set: Dictionary = {}
		for m in matches_this_wave:
			for c in m["cells"]:
				cleared_set[c] = true

		var affected_columns: Dictionary = {}  # x -> Array[int] of cleared row y's
		var cleared_info: Array = []
		for c in cleared_set.keys():
			cleared_info.append({"pos": c, "letter": cells[c.y][c.x], "skin_id": skins[c.y][c.x]})
			cells[c.y][c.x] = ""
			skins[c.y][c.x] = ""
			if not affected_columns.has(c.x):
				affected_columns[c.x] = []
			affected_columns[c.x].append(c.y)

		words_cleared.emit(matches_this_wave, cascade_depth)

		if cleared_info.size() > 0:
			_clear_effect.play(cleared_info)
			_shake(cleared_info.size())

		var moved_positions: Array[Vector2i] = _apply_gravity(affected_columns)
		queue_redraw()

		if moved_positions.is_empty():
			break

		# Check only the cells that actually moved for a NEW automatic
		# cascade match. This does NOT touch pending_matches — cascades
		# resolve immediately as a reward, they aren't offered to the
		# player to hold onto.
		var cascade_matches: Array = []
		var seen: Dictionary = {}
		for p in moved_positions:
			if is_cell_empty(p):
				continue
			for m in WordFinder.find_words_through(cells, GRID_SIZE, p.y, p.x):
				var key: String = m["word"] + ":" + str(m["cells"])
				if not seen.has(key):
					seen[key] = true
					cascade_matches.append(m)

		if cascade_matches.is_empty():
			break

		matches_this_wave = cascade_matches
		cascade_depth += 1

	_rescan_pending_matches()
	queue_redraw()


## Shifts only the letters that were ABOVE a cleared cell down to fill it —
## letters below a cleared cell never move, and any other pre-existing gap
## in the column (unrelated to this clear) keeps its exact spacing.
func _apply_gravity(columns_cleared_rows: Dictionary) -> Array[Vector2i]:
	var moved_positions: Array[Vector2i] = []

	for x in columns_cleared_rows.keys():
		var cleared_rows: Array = columns_cleared_rows[x]
		var cleared_set_y: Dictionary = {}
		for y in cleared_rows:
			cleared_set_y[y] = true

		var remaining_letters: Array = []
		var remaining_skins: Array = []
		for y in range(GRID_SIZE):
			if cleared_set_y.has(y):
				continue
			remaining_letters.append(cells[y][x])
			remaining_skins.append(skins[y][x])

		var new_letters: Array = []
		var new_skins: Array = []
		for i in range(cleared_rows.size()):
			new_letters.append("")
			new_skins.append("")
		new_letters += remaining_letters
		new_skins += remaining_skins

		for y in range(GRID_SIZE):
			if cells[y][x] != new_letters[y] and new_letters[y] != "":
				moved_positions.append(Vector2i(x, y))
			cells[y][x] = new_letters[y]
			skins[y][x] = new_skins[y]

	return moved_positions


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
		var rot := randf_range(-0.03, 0.03) * shake_amount
		var scl := Vector2(1.0, 1.0) + Vector2(randf_range(-0.01, 0.01), randf_range(-0.01, 0.01)) * shake_amount
		_shake_tween.tween_property(self, "rotation", rot, 0.035)
		_shake_tween.parallel().tween_property(self, "scale", scl, 0.035)

	_shake_tween.tween_property(self, "rotation", 0.0, 0.05)
	_shake_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.05)


# =============================================================================
# DRAWING
# =============================================================================

func _draw() -> void:
	var cell_size: int = BlockBlastLayout.cell_size
	draw_rect(Rect2(Vector2.ZERO, custom_minimum_size), BOARD_BG_COLOR)

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var cell_rect := Rect2(
				Vector2(x * cell_size + CELL_GAP, y * cell_size + CELL_GAP),
				Vector2(cell_size - CELL_GAP * 2, cell_size - CELL_GAP * 2)
			)
			var letter: String = cells[y][x]
			if letter == "":
				draw_rect(cell_rect, EMPTY_CELL_COLOR)
				continue

			var skin_id: String = skins[y][x]
			var tex: Texture2D = LetterTile.get_texture(letter, skin_id)
			if tex:
				draw_texture_rect(tex, cell_rect, false)
			else:
				draw_rect(cell_rect, Color.DARK_CYAN)

	# Golden highlight over every cell that's part of a valid, tappable
	# word currently sitting on the board.
	for m in pending_matches:
		for c in m["cells"]:
			var cell_rect := Rect2(
				Vector2(c.x * cell_size + CELL_GAP, c.y * cell_size + CELL_GAP),
				Vector2(cell_size - CELL_GAP * 2, cell_size - CELL_GAP * 2)
			)
			draw_rect(cell_rect, PENDING_HIGHLIGHT)

	if is_in_bounds(preview_cell):
		var overlay_color: Color = Color(0.2, 1.0, 0.4, 0.45) if preview_valid else Color(1.0, 0.2, 0.2, 0.45)
		var cell_rect := Rect2(
			Vector2(preview_cell.x * cell_size + CELL_GAP, preview_cell.y * cell_size + CELL_GAP),
			Vector2(cell_size - CELL_GAP * 2, cell_size - CELL_GAP * 2)
		)
		draw_rect(cell_rect, overlay_color)
