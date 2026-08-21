extends Control
class_name LetterPiece

signal drag_started(piece: LetterPiece)

var letter: String = ""
var skin_id: String = ""

## Multiplier on BlockBlastLayout.cell_size — 1.0 while dragging, smaller
## while resting in the tray, same pattern as your original Piece.
var display_scale: float = 1.0
var full_size: Vector2 = Vector2.ZERO


func set_piece(new_letter: String, new_skin_id: String, new_display_scale: float = 1.0) -> void:
	letter = new_letter
	skin_id = new_skin_id
	display_scale = new_display_scale
	_rebuild()


func refresh_layout(new_display_scale: float = -1.0) -> void:
	if new_display_scale >= 0.0:
		display_scale = new_display_scale
	_rebuild()


func set_display_scale(s: float) -> void:
	display_scale = s
	_rebuild()


func _rebuild() -> void:
	var cell_size: float = BlockBlastLayout.cell_size * display_scale
	full_size = Vector2(cell_size, cell_size)
	custom_minimum_size = full_size
	queue_redraw()


func _draw() -> void:
	if letter == "":
		return

	var cell_size: float = BlockBlastLayout.cell_size * display_scale
	var cell_rect := Rect2(Vector2.ZERO, Vector2(cell_size, cell_size))

	var tex: Texture2D = LetterTile.get_texture(letter, skin_id)
	if tex:
		draw_texture_rect(tex, cell_rect, false)
	else:
		draw_rect(cell_rect, Color.DARK_CYAN)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		drag_started.emit(self)
	elif event is InputEventScreenTouch and event.pressed:
		drag_started.emit(self)
