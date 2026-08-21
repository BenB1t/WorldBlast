extends Control

const HORIZONTAL_MARGIN: float = 24.0
const TOP_MARGIN: float = 40.0
const BOTTOM_MARGIN: float = 16.0
const TOP_BAR_HEIGHT: float = 72.0
const SECTION_SPACING: float = 24.0
const MIN_CELL_SIZE: int = 16
const TRAY_SPACING: float = 24.0
const TRAY_FIT_SAFETY: float = 0.92

const DRAG_LIFT := Vector2(0, -80)
const GAME_OVER_DELAY: float = 1.1

@onready var grid: WordGrid = $Margin/VBoxContainer/CenterContainer/Grid
@onready var tray: LetterTray = $Margin/VBoxContainer/TrayCenterContainer/Tray
@onready var drag_layer: Control = $DragLayer
@onready var score_label: Label = $Margin/VBoxContainer/TopBar/ScoreLabel

var score: int = 0
var combo_count: int = 0  # consecutive placements in a row that cleared something
var is_game_over: bool = false

var dragging_piece: LetterPiece = null
var dragging_slot_index: int = -1
var drag_origin_parent: Node = null
var drag_origin_index: int = -1


func _ready() -> void:
	_configure_layout()
	_connect_tray_pieces()
	tray.tray_refilled.connect(_connect_tray_pieces)
	get_viewport().size_changed.connect(_configure_layout)
	grid.words_cleared.connect(_on_words_cleared)


func _configure_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size

	var available_width: float = viewport_size.x - HORIZONTAL_MARGIN * 2.0
	var cell_size_from_width: int = int(floor(available_width / WordGrid.GRID_SIZE))

	var available_height: float = viewport_size.y \
		- TOP_MARGIN - BOTTOM_MARGIN \
		- TOP_BAR_HEIGHT \
		- SECTION_SPACING * 2.0
	var rows_needed: int = WordGrid.GRID_SIZE + LetterTray.SLOT_CELLS
	var cell_size_from_height: int = int(floor(available_height / rows_needed))

	var new_cell_size: int = min(cell_size_from_width, cell_size_from_height)
	new_cell_size = max(new_cell_size, MIN_CELL_SIZE)

	var tray_gaps: float = TRAY_SPACING * float(LetterTray.SLOT_COUNT - 1)
	var slot_width_budget: float = (available_width - tray_gaps) / float(LetterTray.SLOT_COUNT) * TRAY_FIT_SAFETY
	var tray_cell_size_from_width: int = int(floor(slot_width_budget / LetterTray.SLOT_CELLS))
	var new_tray_cell_size: int = clamp(tray_cell_size_from_width, 1, new_cell_size)

	BlockBlastLayout.cell_size = new_cell_size
	BlockBlastLayout.tray_cell_size = new_tray_cell_size

	grid.refresh_layout()
	tray.refresh_layout()


func _connect_tray_pieces() -> void:
	for i in range(LetterTray.SLOT_COUNT):
		var piece: LetterPiece = tray.get_piece_at(i)
		if piece == null:
			continue
		if piece.drag_started.is_connected(_on_piece_drag_started):
			continue
		piece.drag_started.connect(_on_piece_drag_started.bind(i))


func _on_piece_drag_started(piece: LetterPiece, slot_index: int) -> void:
	if is_game_over:
		return
	if dragging_piece != null:
		return

	dragging_piece = piece
	dragging_slot_index = slot_index
	drag_origin_parent = piece.get_parent()
	drag_origin_index = piece.get_index()

	drag_origin_parent.remove_child(piece)
	drag_layer.add_child(piece)
	piece.set_display_scale(1.0)

	_update_drag(get_viewport().get_mouse_position())


func _input(event: InputEvent) -> void:
	if dragging_piece == null:
		return

	if event is InputEventMouseMotion:
		_update_drag(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_update_drag(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and not event.pressed:
		_end_drag(event.position)
		get_viewport().set_input_as_handled()


func _update_drag(pointer_pos: Vector2) -> void:
	var top_left: Vector2 = _piece_top_left_for(pointer_pos)
	dragging_piece.global_position = top_left

	var cell_pos: Vector2i = _top_left_to_grid_cell(top_left)
	var valid: bool = grid.is_cell_empty(cell_pos)
	grid.set_preview(cell_pos, valid)


func _end_drag(pointer_pos: Vector2) -> void:
	var piece: LetterPiece = dragging_piece
	var slot_index: int = dragging_slot_index

	grid.clear_preview()

	var top_left: Vector2 = _piece_top_left_for(pointer_pos)
	var cell_pos: Vector2i = _top_left_to_grid_cell(top_left)
	var valid: bool = grid.is_cell_empty(cell_pos)

	if valid:
		var result: Dictionary = grid.place_letter(cell_pos, piece.letter, piece.skin_id)
		drag_layer.remove_child(piece)
		tray.remove_piece(slot_index)  # also refills this slot immediately

		if result["all_matches"].is_empty():
			combo_count = 0  # placement produced no clear — combo resets
		else:
			combo_count += 1

		_connect_tray_pieces()
		_check_game_over()
	else:
		drag_layer.remove_child(piece)
		piece.set_display_scale(BlockBlastLayout.get_tray_scale())
		drag_origin_parent.add_child(piece)
		drag_origin_parent.move_child(piece, drag_origin_index)
		tray.reposition_piece(slot_index)

	dragging_piece = null
	dragging_slot_index = -1
	drag_origin_parent = null
	drag_origin_index = -1


func _piece_top_left_for(pointer_pos: Vector2) -> Vector2:
	var lifted: Vector2 = pointer_pos + DRAG_LIFT
	return lifted - dragging_piece.full_size * 0.5


func _top_left_to_grid_cell(top_left: Vector2) -> Vector2i:
	var local_pos: Vector2 = top_left - grid.global_position
	var cell_size: int = BlockBlastLayout.cell_size
	return Vector2i(
		roundi(local_pos.x / cell_size),
		roundi(local_pos.y / cell_size)
	)


## Fires once per cascade wave (grid.gd emits this per wave inside
## _resolve_from). Scores every word found in that wave and updates the
## running total immediately, so score climbs visibly wave by wave rather
## than jumping all at once at the end of a cascade.
func _on_words_cleared(matches: Array, cascade_depth: int) -> void:
	var wave_points: int = 0
	for m in matches:
		wave_points += ScoreRules.score_word(m["word"], cascade_depth, combo_count)
	_add_score(wave_points)

	# TODO: this is also the hook point for a "highlight the word before it
	# clears" animation/delay — grid.gd currently clears immediately in the
	# same call, so add a short await here (and a matching delay inside
	# grid.gd's _resolve_from) once you're ready for that polish pass.


func _add_score(points: int) -> void:
	score += points
	score_label.text = str(score)


## Since every piece is a single letter now, "does the next piece fit
## anywhere" simplifies to "is the board not completely full" — no shape
## fitting check needed, unlike your original _shape_fits_anywhere().
func _check_game_over() -> void:
	if grid.has_any_empty_cell():
		return
	_trigger_game_over()


func _trigger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true

	print("[WordBlast] Game over. Final score: %d" % score)
	# Hook up your GameOverOverlay here the same way block_blast_game.gd
	# does — show_game_over(score), await the delay, then hand off however
	# your host shell expects (BeatIt.finish_game equivalent, or just
	# change_scene_to_file back to the title screen).
