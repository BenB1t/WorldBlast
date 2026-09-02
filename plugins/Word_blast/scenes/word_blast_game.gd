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
const COMBO_RESET_TURNS: int = 3

@export var is_ranked: bool = false

var active_ruleset: RankedRuleset = null

@onready var grid: WordGrid = $Margin/VBoxContainer/CenterContainer/Grid
@onready var tray: LetterTray = $Margin/VBoxContainer/TrayCenterContainer/Tray
@onready var drag_layer: Control = $DragLayer
@onready var current_score_label: Label = $Margin/VBoxContainer/TopBar/ScoreBox/CurrentScoreLabel
@onready var quit_button: TextureButton = $Margin/VBoxContainer/TopBar/ReturnButton
@onready var restart_button: TextureButton = $Margin/VBoxContainer/TopBar/ReturnButton2
@onready var hint_button: TextureButton = $HintButton

var score: int = 0
var combo_count: int = 0
var turns_since_last_clear: int = 0
var is_game_over: bool = false

var dragging_piece: LetterPiece = null
var dragging_slot_index: int = -1
var drag_origin_parent: Node = null
var drag_origin_index: int = -1

var game_seed: int = -1
var game_id: String = ""
var event_log: GameEventLog = null

var _cleared_words: Dictionary = {}

var _resumed_headless: HeadlessGame = null
var _resumed_log: GameEventLog = null

var _hint_tween: Tween = null
var _hint_searching: bool = false
var _board_version: int = 0


func _enter_tree() -> void:
	var tray_node: LetterTray = $Margin/VBoxContainer/TrayCenterContainer/Tray
	
	if RankedSession.is_active:
		is_ranked = true
		tray_node.letter_bag = LetterBag.new(RankedSession.game_seed)
		active_ruleset = RankedRuleset.new()
		if active_ruleset.WORD_REUSE_ALLOWED:
			var grid_node: WordGrid = $Margin/VBoxContainer/CenterContainer/Grid
			grid_node.availability_tracker = WordAvailabilityTracker.new()
		return

	var save_log := GameSave.read()
	if save_log != null and not save_log.finished:
		var result := GameReplayer.replay(save_log.to_dictionary())
		if result["valid"]:
			_resumed_headless = result["game"]
			_resumed_log = save_log
		else:
			push_warning("[WordBlast] Save exists but replay failed: %s" % result["errors"])

	if _resumed_headless != null:
		tray_node.suppress_refill = true
		tray_node.letter_bag = _resumed_headless.letter_bag
		is_ranked = _resumed_log.is_ranked
	else:
		game_seed = randi()
		tray_node.letter_bag = LetterBag.new(game_seed)

	if is_ranked:
		active_ruleset = RankedRuleset.new()
		if active_ruleset.WORD_REUSE_ALLOWED:
			var grid_node: WordGrid = $Margin/VBoxContainer/CenterContainer/Grid
			if _resumed_headless != null and _resumed_headless.availability_tracker != null:
				grid_node.availability_tracker = _resumed_headless.availability_tracker
			else:
				grid_node.availability_tracker = WordAvailabilityTracker.new()


func _ready() -> void:
	_configure_layout()

	quit_button.pressed.connect(_on_quit_to_menu_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	hint_button.pressed.connect(_on_hint_pressed)

	if RankedSession.is_active:
		_start_new_game()
	elif _resumed_headless != null:
		event_log = _resumed_log
		game_seed = _resumed_log.game_seed
		game_id = _resumed_log.game_id
		is_ranked = _resumed_log.is_ranked
		
		score = _resumed_headless.score
		combo_count = _resumed_headless.combo_count
		turns_since_last_clear = _resumed_headless.turns_since_last_clear

		grid.load_snapshot(_resumed_headless)
		tray.load_snapshot(_resumed_headless)
		_update_score_label()
		print("[WordBlast] Resumed saved game: %s" % game_id)
	else:
		_start_new_game()

	_connect_tray_pieces()
	tray.tray_refilled.connect(_connect_tray_pieces)
	get_viewport().size_changed.connect(_configure_layout)
	grid.words_cleared.connect(_on_words_cleared)


func _start_new_game() -> void:
	if RankedSession.is_active:
		game_seed = RankedSession.game_seed
		game_id = RankedSession.game_id
		is_ranked = true
		RankedSession.clear_session()
	else:
		game_id = "casual_" + str(Time.get_unix_time_from_system())
		is_ranked = false

	event_log = GameEventLog.new()
	event_log.begin(game_id, game_seed, is_ranked, "ranked_v1" if is_ranked else "")
	GameSave.write(event_log)


func _configure_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size

	var available_width: float = viewport_size.x - HORIZONTAL_MARGIN * 2.0
	var cell_size_from_width: int = int(floor((available_width - 2 * WordGrid.BOARD_PADDING) / WordGrid.GRID_SIZE))

	var available_height: float = viewport_size.y \
		- TOP_MARGIN - BOTTOM_MARGIN \
		- TOP_BAR_HEIGHT \
		- SECTION_SPACING * 2.0
	var rows_needed: int = WordGrid.GRID_SIZE + LetterTray.SLOT_CELLS
	var cell_size_from_height: int = int(floor((available_height - 2 * WordGrid.BOARD_PADDING) / rows_needed))

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

	var anchor: Vector2i = _top_left_to_grid_cell(top_left)
	var offs: Array = dragging_piece.offsets()
	var preview_cells := []
	for o in offs:
		preview_cells.append(anchor + o)
	grid.set_preview_cells(preview_cells, grid.can_place_area(anchor, offs))


func _end_drag(pointer_pos: Vector2) -> void:
	var piece: LetterPiece = dragging_piece
	var slot_index: int = dragging_slot_index

	grid.clear_preview()

	var top_left: Vector2 = _piece_top_left_for(pointer_pos)
	var anchor: Vector2i = _top_left_to_grid_cell(top_left)
	var offs: Array = piece.offsets()
	var valid: bool = grid.can_place_area(anchor, offs)

	if valid:
		grid.place_piece(anchor, offs, piece.piece.letters, piece.skin_id)
		grid.clear_hints()
		_board_version += 1

		if event_log != null:
			event_log.log_place_piece(piece.piece.shape, piece.piece.letters, anchor.x, anchor.y, slot_index, piece.skin_id)
			GameSave.write(event_log)

		drag_layer.remove_child(piece)
		tray.remove_piece(slot_index)

		turns_since_last_clear += 1
		_connect_tray_pieces()
		_check_game_over()
	else:
		drag_layer.remove_child(piece)
		# Restore the shrink-to-fit tray scale for this piece's shape
		var b: Vector2i = piece.bounding_cells()
		var max_dim: int = max(b.x, b.y)
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
		roundi((local_pos.x - WordGrid.BOARD_PADDING) / cell_size),
		roundi((local_pos.y - WordGrid.BOARD_PADDING) / cell_size)
	)


func _on_words_cleared(matches: Array, cascade_depth: int, tapped_cell: Vector2i) -> void:
	grid.clear_hints()
	_board_version += 1

	if event_log != null:
		event_log.log_clear(tapped_cell.x, tapped_cell.y)
		GameSave.write(event_log)

	if cascade_depth == 0:
		if turns_since_last_clear > COMBO_RESET_TURNS:
			combo_count = 0
		turns_since_last_clear = 0

	var wave_points: int = 0
	for m in matches:
		_cleared_words[m["word"]] = true
		
		var word_points: int = ScoreRules.score_word(m["word"], cascade_depth, combo_count)
		if m.get("already_used", false) and active_ruleset != null:
			word_points = int(round(word_points * active_ruleset.REUSED_WORD_SCORE_MULTIPLIER))
		wave_points += word_points
	_add_score(wave_points)

	if cascade_depth == 0:
		combo_count += 1


func _add_score(points: int) -> void:
	score += points
	_update_score_label()


func _update_score_label() -> void:
	current_score_label.text = "SCORE: %d" % score


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

	if event_log != null:
		event_log.log_finish(score)
		GameSave.write(event_log)
		
		if is_ranked:
			print("[WordBlast] Submitting ranked score to server...")
			var events_data: Array = []
			if "events" in event_log.to_dictionary():
				events_data = event_log.to_dictionary()["events"]
				
			var payload = {
				"game_id": game_id,
				"player_id": PlayerIdentity.player_id,
				"score": score,
				"events": events_data,
				"seed": game_seed,
				"ruleset_version": "ranked_v1",
				"words": _cleared_words.keys()
			}

			var response = await ApiClient.finish_ranked_game(
				payload["game_id"], 
				payload["player_id"], 
				payload["score"], 
				payload["events"],
				payload["seed"],
				payload["ruleset_version"]
			)
			
			if response.has("error"):
				print("[WordBlast] Submission failed (offline?). Adding to queue.")
				OfflineQueue.add(payload)
			else:
				print("[WordBlast] Score submitted successfully!")
				
			GameSave.delete_save()

	print("[WordBlast] Game over. Final score: %d" % score)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if event_log != null and not event_log.finished:
			GameSave.write(event_log)


func _on_restart_pressed() -> void:
	GameSave.delete_save()

	var response = await ApiClient.start_ranked_game(
		PlayerIdentity.player_id,
		PlayerIdentity.display_name,
		PlayerIdentity.country
	)
	if response.has("error"):
		RankedSession.clear_session()
	else:
		RankedSession.start_new_session(response)

	Nav.restart_game()


func _on_quit_to_menu_pressed() -> void:
	if event_log != null and not event_log.finished:
		GameSave.write(event_log)
	Nav.go_to_menu()


# =============================================================================
# HINT SYSTEM
# =============================================================================

func _on_hint_pressed() -> void:
	if is_game_over or _hint_searching:
		return
	_hint_searching = true
	hint_button.disabled = true

	var hints: Dictionary = await _find_hint_placements()

	_hint_searching = false
	hint_button.disabled = false

	if hints.is_empty():
		return
	grid.set_hints(hints)
	_animate_hints()


func _find_hint_placements() -> Dictionary:
	var occupied: Array[Vector2i] = []
	for y in range(WordGrid.GRID_SIZE):
		for x in range(WordGrid.GRID_SIZE):
			if grid.cells[y][x] != "":
				occupied.append(Vector2i(x, y))
	if occupied.is_empty():
		return {}

	var start_version := _board_version

	var letter_positions := {}
	for cell in occupied:
		var l: String = grid.cells[cell.y][cell.x]
		if not letter_positions.has(l):
			letter_positions[l] = []
		letter_positions[l].append(cell)

	var word_list: Array = WordDictionary.get_all_words().duplicate()
	word_list.shuffle()

	var placements := []
	var processed := 0

	for word in word_list:
		var word_str: String = str(word)
		var L: int = word_str.length()

		if L < 3 or L > WordGrid.GRID_SIZE:
			continue
		var upper: String = word_str.to_upper()

		for letter in letter_positions:
			var letter_str: String = str(letter)
			if upper.find(letter_str) == -1:
				continue
			for i in range(L):
				if upper[i] != letter_str:
					continue
				for cell in letter_positions[letter]:
					var cell_v: Vector2i = cell
					for dir in [Vector2i(1, 0), Vector2i(0, 1)]:
						# Explicit Vector2i types so Godot never has to infer
						var start: Vector2i = cell_v - dir * i
						var end: Vector2i = start + dir * (L - 1)
						if start.x < 0 or start.y < 0 or end.x >= WordGrid.GRID_SIZE or end.y >= WordGrid.GRID_SIZE:
							continue
						var ghosts := {}
						var used := 0
						var ok := true
						for j in range(L):
							var p: Vector2i = start + dir * j
							var existing: String = grid.cells[p.y][p.x]
							if existing == "":
								ghosts[p] = upper[j]
							elif existing != upper[j]:
								ok = false
								break
							else:
								used += 1
						if ok and used >= 1 and ghosts.size() >= 1:
							placements.append({"word": upper, "ghosts": ghosts})
							if placements.size() >= 40:
								return _pick_hints(placements)

		processed += 1
		if processed % 200 == 0:
			await get_tree().process_frame
			if _board_version != start_version:
				return {}

	return _pick_hints(placements)

func _pick_hints(placements: Array) -> Dictionary:
	placements.shuffle()
	var taken := {}
	var hints := {}
	var chosen := 0
	for p in placements:
		var overlaps := false
		for pos in p["ghosts"]:
			if taken.has(pos):
				overlaps = true
				break
		if overlaps:
			continue
		for pos in p["ghosts"]:
			hints[pos] = p["ghosts"][pos]
			taken[pos] = true
		chosen += 1
		if chosen >= 3:
			break
	return hints


func _animate_hints() -> void:
	if _hint_tween and _hint_tween.is_valid():
		_hint_tween.kill()
	grid.hint_alpha = 0.0
	_hint_tween = create_tween()
	_hint_tween.tween_property(grid, "hint_alpha", 0.45, 0.4)
	_hint_tween.tween_interval(1.5)
	_hint_tween.tween_property(grid, "hint_alpha", 0.0, 0.6)
	_hint_tween.tween_callback(grid.clear_hints)
