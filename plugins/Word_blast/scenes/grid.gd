extends Control
class_name WordGrid

const GRID_SIZE: int = 8
const CELL_GAP: int = 2

const BOARD_BG_COLOR: Color = Color("EFE7D8")
const EMPTY_CELL_COLOR: Color = Color("E0D6C0")

## Emitted once per cascade wave with the matches found in that wave, so
## the caller (game script) can score each wave and animate/highlight
## before the next wave's clear. cascade_depth is 0 for the direct match
## from the player's placement, 1+ for gravity-triggered waves after it.
signal words_cleared(matches: Array, cascade_depth: int)

var cells: Array = []  # cells[y][x] = "" or a single uppercase letter
var skins: Array = []  # cells[y][x] = skin_id string, cosmetic only

var preview_cell: Vector2i = Vector2i(-1, -1)
var preview_valid: bool = true


func _ready() -> void:
	_reset_cells()
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
# PLACEMENT + WORD RESOLUTION
# =============================================================================

## Places a single letter at `pos`, then resolves any resulting words
## (including gravity-triggered cascades). Returns a summary for scoring:
##   {all_matches: Array, cascade_depth: int}
## `all_matches` is every {word, cells} dict found across every wave.
func place_letter(pos: Vector2i, letter: String, skin_id: String) -> Dictionary:
	cells[pos.y][pos.x] = letter
	skins[pos.y][pos.x] = skin_id
	queue_redraw()
	return _resolve_from(pos)


func _resolve_from(start_pos: Vector2i) -> Dictionary:
	var cascade_depth: int = 0
	var all_matches: Array = []
	var check_positions: Array[Vector2i] = [start_pos]

	while true:
		var matches: Array = []
		for p in check_positions:
			if is_cell_empty(p):
				continue
			matches += WordFinder.find_words_through(cells, GRID_SIZE, p.y, p.x)

		if matches.is_empty():
			break

		# Union all matched cells before clearing, so overlapping words
		# (e.g. "STAR" and "START" sharing letters) don't double-count.
		var cleared_set: Dictionary = {}
		for m in matches:
			for c in m["cells"]:
				cleared_set[c] = true

		for c in cleared_set.keys():
			cells[c.y][c.x] = ""
			skins[c.y][c.x] = ""

		words_cleared.emit(matches, cascade_depth)
		all_matches += matches

		check_positions = _apply_gravity()
		queue_redraw()

		if check_positions.is_empty():
			break
		cascade_depth += 1

	return {"all_matches": all_matches, "cascade_depth": cascade_depth}


## Compacts every column downward to fill gaps left by cleared cells.
## Returns the positions that received a (possibly different) letter, so
## the caller knows where to re-check for newly-formed words.
func _apply_gravity() -> Array[Vector2i]:
	var moved_positions: Array[Vector2i] = []

	for x in range(GRID_SIZE):
		var stack: Array = []
		var stack_skins: Array = []
		for y in range(GRID_SIZE):
			if cells[y][x] != "":
				stack.append(cells[y][x])
				stack_skins.append(skins[y][x])

		var write_y := GRID_SIZE - 1
		for i in range(stack.size() - 1, -1, -1):
			if cells[write_y][x] != stack[i]:
				moved_positions.append(Vector2i(x, write_y))
			cells[write_y][x] = stack[i]
			skins[write_y][x] = stack_skins[i]
			write_y -= 1

		for y in range(write_y, -1, -1):
			cells[y][x] = ""
			skins[y][x] = ""

	return moved_positions


# =============================================================================
# PLACEMENT PREVIEW (single-cell hover — pieces are single letters now)
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

	if is_in_bounds(preview_cell):
		var overlay_color: Color = Color(0.2, 1.0, 0.4, 0.45) if preview_valid else Color(1.0, 0.2, 0.2, 0.45)
		var cell_rect := Rect2(
			Vector2(preview_cell.x * cell_size + CELL_GAP, preview_cell.y * cell_size + CELL_GAP),
			Vector2(cell_size - CELL_GAP * 2, cell_size - CELL_GAP * 2)
		)
		draw_rect(cell_rect, overlay_color)
