extends HBoxContainer
class_name LetterTray

const LETTER_PIECE_SCENE = preload("res://plugins/word_blast/scenes/letter_piece.tscn")
const SLOT_COUNT: int = 3

## Sized for the LARGEST piece (a trio = 3 cells) so no piece ever exceeds
## its slot. Matches the Block Blast pattern you already built.
const SLOT_CELLS: int = 3

signal tray_refilled

var slots: Array[LetterPiece] = []
var slot_containers: Array[Control] = []

var letter_bag: LetterBag
var suppress_refill: bool = false

func _ready() -> void:
	if letter_bag == null:
		letter_bag = LetterBag.new()
	for i in range(SLOT_COUNT):
		var slot_container := Control.new()
		add_child(slot_container)
		slot_containers.append(slot_container)
	slots.resize(SLOT_COUNT)
	slots.fill(null)
	refresh_layout()
	if not suppress_refill:
		refill()

func refresh_layout() -> void:
	var tray_scale: float = BlockBlastLayout.get_tray_scale()
	# Slot sized for largest piece (3 cells) at tray scale — matches Block Blast
	var slot_size: float = SLOT_CELLS * BlockBlastLayout.cell_size * tray_scale
	for slot_container in slot_containers:
		slot_container.custom_minimum_size = Vector2(slot_size, slot_size)
	for i in range(SLOT_COUNT):
		var piece: LetterPiece = slots[i]
		if piece != null:
			# Uniform tray_scale for ALL pieces — no per-piece shrinking
			piece.refresh_layout(tray_scale)
			_position_piece_in_slot(i)

func refill() -> void:
	for i in range(SLOT_COUNT):
		if slots[i] == null:
			_spawn_slot(i)
	tray_refilled.emit()

func refill_slot(index: int) -> void:
	_spawn_slot(index)
	tray_refilled.emit()

func _spawn_slot(index: int) -> void:
	var p: Dictionary = letter_bag.random_piece()
	var piece: LetterPiece = LETTER_PIECE_SCENE.instantiate()
	var skin_id: String = LetterTile.random_skin_id()
	slot_containers[index].add_child(piece)
	# Build at tray scale directly — uniform for all pieces (singles, duos, trios)
	piece.set_piece(p, skin_id, BlockBlastLayout.get_tray_scale())
	slots[index] = piece
	_position_piece_in_slot(index)

func reposition_piece(index: int) -> void:
	_position_piece_in_slot(index)

func _position_piece_in_slot(index: int) -> void:
	var piece: LetterPiece = slots[index]
	if piece == null:
		return
	var slot_size: Vector2 = slot_containers[index].custom_minimum_size
	# Bottom-aligned horizontally centered (matches Block Blast baseline)
	piece.position = Vector2(
		(slot_size.x - piece.full_size.x) * 0.5,
		slot_size.y - piece.full_size.y
	)

func remove_piece(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT or slots[index] == null:
		return
	var piece: LetterPiece = slots[index]
	if piece.get_parent() == slot_containers[index]:
		slot_containers[index].remove_child(piece)
	piece.queue_free()
	slots[index] = null
	refill_slot(index)

func get_piece_at(index: int) -> LetterPiece:
	if index < 0 or index >= SLOT_COUNT:
		return null
	return slots[index]

func load_snapshot(headless: HeadlessGame) -> void:
	for i in range(SLOT_COUNT):
		if slots[i] != null:
			if slots[i].get_parent() == slot_containers[i]:
				slot_containers[i].remove_child(slots[i])
			slots[i].queue_free()
			slots[i] = null
	for i in range(SLOT_COUNT):
		var piece: LetterPiece = LETTER_PIECE_SCENE.instantiate()
		var p: Dictionary = headless.tray[i]
		var skin_id: String = LetterTile.random_skin_id()
		slot_containers[i].add_child(piece)
		piece.set_piece(p, skin_id, BlockBlastLayout.get_tray_scale())
		slots[i] = piece
		_position_piece_in_slot(i)
