extends Control
class_name LetterPiece

signal drag_started(piece: LetterPiece)

var piece: Dictionary = {}   # {"shape": String, "letters": Array}
var skin_id: String = ""
var letter: String = ""      # first letter (compat)
var display_scale: float = 1.0
var full_size: Vector2 = Vector2.ZERO

func set_piece(p: Dictionary, skin: String, scale: float) -> void:
	piece = p
	skin_id = skin
	letter = p.get("letters", [""])[0]
	display_scale = scale
	_update_size()
	queue_redraw()

func offsets() -> Array:
	return LetterBag.offsets_for(piece.get("shape", "S"))

func bounding_cells() -> Vector2i:
	var mx := 0; var my := 0
	for o in offsets():
		mx = max(mx, o.x); my = max(my, o.y)
	return Vector2i(mx + 1, my + 1)

func set_display_scale(s: float) -> void:
	display_scale = s
	_update_size()
	queue_redraw()

func refresh_layout(scale_override: float = -1) -> void:
	if scale_override > 0: display_scale = scale_override
	_update_size()
	queue_redraw()

func _update_size() -> void:
	var b := bounding_cells()
	var cell_size: float = BlockBlastLayout.cell_size * display_scale
	full_size = Vector2(b.x * cell_size, b.y * cell_size)
	custom_minimum_size = full_size

# Draw letters directly — like your Block Blast piece.gd — instead of
# child TextureRect nodes. Guarantees every letter tile is pixel-for-pixel
# the same size, matching the tray's uniform scale perfectly.
func _draw() -> void:
	if piece.is_empty():
		return
	var cell_size: float = BlockBlastLayout.cell_size * display_scale
	var offs: Array = offsets()
	var letters: Array = piece.get("letters", [])
	for i in range(offs.size()):
		var o: Vector2i = offs[i]
		var rect := Rect2(Vector2(o.x, o.y) * cell_size, Vector2(cell_size, cell_size))
		var letter_str: String = letters[i] if i < letters.size() else ""
		var tex: Texture2D = LetterTile.get_texture(letter_str, skin_id)
		if tex:
			draw_texture_rect(tex, rect, false)
		else:
			# Fallback: solid tile with letter text
			draw_rect(rect, Color(0.85, 0.9, 1.0))
			var font := ThemeDB.fallback_font
			if font:
				var text_size := font.get_string_size(letter_str, HORIZONTAL_ALIGNMENT_CENTER, -1, int(cell_size * 0.6))
				var text_pos := rect.position + (rect.size - text_size) * 0.5 + Vector2(0, text_size.y * 0.35)
				draw_string(font, text_pos, letter_str, HORIZONTAL_ALIGNMENT_CENTER, int(rect.size.x), int(cell_size * 0.6), Color.DARK_SLATE_GRAY)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		drag_started.emit(self)
	elif event is InputEventScreenTouch and event.pressed:
		drag_started.emit(self)
