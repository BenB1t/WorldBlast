extends HBoxContainer
class_name LetterTray
const LETTER_PIECE_SCENE = preload("res://plugins/word_blast/scenes/letter_piece.tscn")
const SLOT_COUNT: int = 3
## A single letter always occupies exactly 1 cell of footprint, unlike
## your original SLOT_CELLS = 5 (which had to fit the largest shape).
const SLOT_CELLS: int = 1
signal tray_refilled
var slots: Array[LetterPiece] = []
var slot_containers: Array[Control] = []

## Injected by whoever owns this tray (word_blast_game.gd) before _ready()
## runs its first refill(), via @onready ordering or an explicit setter —
## see note below. LetterBag is no longer static, so the tray needs an
## actual instance to draw from. Falls back to a fresh unseeded bag if
## nothing was assigned, so this still works standalone (e.g. in a test
## scene) without erroring.
var letter_bag: LetterBag

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
	refill()
func refresh_layout() -> void:
	var tray_scale: float = BlockBlastLayout.get_tray_scale()
	var slot_size: float = SLOT_CELLS * BlockBlastLayout.cell_size * tray_scale
	for slot_container in slot_containers:
		slot_container.custom_minimum_size = Vector2(slot_size, slot_size)
	for i in range(SLOT_COUNT):
		var piece: LetterPiece = slots[i]
		if piece != null:
			piece.refresh_layout(tray_scale)
			_position_piece_in_slot(i)
## Word Blast refills one slot at a time as soon as it's placed (unlike
## Block Blast, which waits for all 3 to empty) — this keeps the player
## always holding 3 options rather than draining down to fewer choices,
## which matters more here since a bad single-letter draw is common.
## Change this behavior easily if you'd rather match your original pacing.
func refill() -> void:
	for i in range(SLOT_COUNT):
		if slots[i] == null:
			_spawn_slot(i)
	tray_refilled.emit()
func refill_slot(index: int) -> void:
	_spawn_slot(index)
	tray_refilled.emit()
func _spawn_slot(index: int) -> void:
	var piece: LetterPiece = LETTER_PIECE_SCENE.instantiate()
	var letter: String = letter_bag.random_letter()
	var skin_id: String = LetterTile.random_skin_id()
	slot_containers[index].add_child(piece)
	piece.set_piece(letter, skin_id, BlockBlastLayout.get_tray_scale())
	slots[index] = piece
	_position_piece_in_slot(index)
func reposition_piece(index: int) -> void:
	_position_piece_in_slot(index)
func _position_piece_in_slot(index: int) -> void:
	var piece: LetterPiece = slots[index]
	if piece == null:
		return
	var slot_size: Vector2 = slot_containers[index].custom_minimum_size
	piece.position = Vector2(
		(slot_size.x - piece.full_size.x) * 0.5,
		slot_size.y - piece.full_size.y
	)
func remove_piece(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT or slots[index] == null:
		return
	var piece: LetterPiece = slots[index]
	# The piece may already have been removed from its slot container —
	# e.g. word_blast_game.gd reparents it to drag_layer during a drag,
	# then removes it from drag_layer on a successful drop, before
	# calling this. Only remove_child() if it's still actually there,
	# or Godot errors: "p_child->data.parent != this".
	if piece.get_parent() == slot_containers[index]:
		slot_containers[index].remove_child(piece)
	piece.queue_free()
	slots[index] = null
	refill_slot(index)
func get_piece_at(index: int) -> LetterPiece:
	if index < 0 or index >= SLOT_COUNT:
		return null
	return slots[index]
