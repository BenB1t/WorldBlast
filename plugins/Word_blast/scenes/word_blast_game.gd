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
## If the player places this many letters in a row without clearing any
## word, the combo streak resets — otherwise combo_count would never
## reset now that clearing is a deliberate tap instead of automatic.
const COMBO_RESET_TURNS: int = 3

## Casual games leave this false: word reuse is unrestricted, matching
## the game's behavior before Section 8 existed. Ranked games (once a
## proper mode-select/launcher exists) should set this to true BEFORE
## this scene enters the tree — e.g. instantiate the scene, set
## `word_blast_game.is_ranked = true`, then add it to the tree — since
## availability_tracker must be assigned in _enter_tree(), before
## LetterTray's _ready() runs.
@export var is_ranked: bool = false

## The frozen ruleset actually in effect for this game. Null in casual
## play (is_ranked = false) — nothing reads this in that case. Loaded in
## _enter_tree() when is_ranked is true, same timing constraint as
## everything else there. See ranked_ruleset_v1.gd for what this governs
## and why editing it after scores are published is forbidden.
var active_ruleset: RankedRuleset = null

@onready var grid: WordGrid = $Margin/VBoxContainer/CenterContainer/Grid
@onready var tray: LetterTray = $Margin/VBoxContainer/TrayCenterContainer/Tray
@onready var drag_layer: Control = $DragLayer
@onready var current_score_label: Label = $Margin/VBoxContainer/TopBar/ScoreBox/CurrentScoreLabel

var score: int = 0
var combo_count: int = 0  # consecutive CLEARS (taps) in a row, resets after a cold streak
var turns_since_last_clear: int = 0
var is_game_over: bool = false

var dragging_piece: LetterPiece = null
var dragging_slot_index: int = -1
var drag_origin_parent: Node = null
var drag_origin_index: int = -1


## _enter_tree() runs top-down (parent before children), unlike _ready()
## which runs bottom-up (children before parent). LetterTray._ready()
## calls refill() immediately, which needs letter_bag already assigned —
## so bag injection MUST happen here, not in _ready(). Word-reuse
## enforcement (availability_tracker) is assigned here too, gated by
## is_ranked, for the same reason: grid's first _rescan happens as soon
## as letters are placed, so the tracker needs to exist before any of
## that starts.
##
## No seed passed = casual play, bag randomizes itself normally. For
## ranked mode, generate/receive a real seed and pass it here instead:
##   tray.letter_bag = LetterBag.new(ranked_seed)
func _enter_tree() -> void:
	var tray_node: LetterTray = $Margin/VBoxContainer/TrayCenterContainer/Tray
	tray_node.letter_bag = LetterBag.new()

	if is_ranked:
		active_ruleset = RankedRuleset.new()
		if active_ruleset.WORD_REUSE_ALLOWED:
			var grid_node: WordGrid = $Margin/VBoxContainer/CenterContainer/Grid
			grid_node.availability_tracker = WordAvailabilityTracker.new()


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
		grid.place_letter(cell_pos, piece.letter, piece.skin_id)
		drag_layer.remove_child(piece)
		tray.remove_piece(slot_index)  # also refills this slot immediately

		turns_since_last_clear += 1
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


## Fires once per cascade wave (grid.gd emits this per wave from
## _clear_match). cascade_depth == 0 is the word the player deliberately
## tapped; 1+ are automatic cascade waves from gravity. Combo streak is
## tracked here since clearing (not placing) is now what "counts."
##
## Each match may carry an "already_used" flag (set by grid.gd when
## availability_tracker is assigned, i.e. ranked mode). A repeated word
## still clears normally and still counts toward combo — its points are
## scaled by active_ruleset.REUSED_WORD_SCORE_MULTIPLIER (0.0 in
## ranked_v1, i.e. zero points) rather than a hardcoded skip, so the
## frozen ruleset stays the single source of truth for that number. In
## casual mode (active_ruleset is null / flag absent), full points
## always apply, same as before Section 8 existed.
func _on_words_cleared(matches: Array, cascade_depth: int) -> void:
	if cascade_depth == 0:
		if turns_since_last_clear > COMBO_RESET_TURNS:
			combo_count = 0
		turns_since_last_clear = 0

	var wave_points: int = 0
	for m in matches:
		var word_points: int = ScoreRules.score_word(m["word"], cascade_depth, combo_count)
		if m.get("already_used", false) and active_ruleset != null:
			word_points = int(round(word_points * active_ruleset.REUSED_WORD_SCORE_MULTIPLIER))
		wave_points += word_points
	_add_score(wave_points)

	if cascade_depth == 0:
		combo_count += 1


func _add_score(points: int) -> void:
	score += points
	current_score_label.text = "SCORE: %d" % score


## A full board is NOT automatically game over: if there's at least one
## pending (highlighted, tappable) word sitting on it, the player still
## has a legal move — tap to clear it, freeing cells. This matters
## specifically for the case where the placement that just filled the
## last empty cell is ALSO the placement that completed a word: the
## board is technically full for one frame, but the player hasn't
## actually run out of options yet.
##
## True game over is: board full AND nothing pending to clear.
func _check_game_over() -> void:
	if grid.has_any_empty_cell():
		return
	if not grid.pending_matches.is_empty():
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
