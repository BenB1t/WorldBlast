extends Control
class_name WordClearEffect

## Same timing/visual language as your Block Blast line_clear_effect.gd —
## a brief flash-hold, then a pop-and-fade — adapted to draw full letter
## tile textures (letter baked in) instead of solid color blocks.

const HOLD_DURATION: float = 0.15
const FADE_DURATION: float = 0.35
const DURATION: float = HOLD_DURATION + FADE_DURATION

var _cells: Array = []  # Array of {pos: Vector2i, letter: String, skin_id: String}
var _elapsed: float = 0.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 100


func play(cleared_cells: Array) -> void:
	_cells = cleared_cells
	_elapsed = 0.0

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_method(_set_elapsed, 0.0, DURATION, DURATION)
	_tween.finished.connect(_on_finished)

	queue_redraw()


func _set_elapsed(t: float) -> void:
	_elapsed = t
	queue_redraw()


func _on_finished() -> void:
	_cells.clear()
	queue_redraw()


func _draw() -> void:
	if _cells.is_empty():
		return

	var cell_size: int = BlockBlastLayout.cell_size
	var gap: int = WordGrid.CELL_GAP
	# The board now draws its sockets BOARD_PADDING pixels inside the white
	# panel, so the pop-and-fade animation must use the same offset or the
	# fading tiles would render shifted away from their real sockets.
	var pad: int = WordGrid.BOARD_PADDING

	for cell_data in _cells:
		var pos: Vector2i = cell_data.pos
		var letter: String = cell_data.letter
		var skin_id: String = cell_data.skin_id

		var base_rect := Rect2(
			Vector2(pad + pos.x * cell_size + gap, pad + pos.y * cell_size + gap),
			Vector2(cell_size - gap * 2, cell_size - gap * 2)
		)
		var center: Vector2 = base_rect.position + base_rect.size * 0.5

		var pop_scale: float = 1.0
		var pop_alpha: float = 1.0
		var flash_alpha: float = 0.0

		if _elapsed <= HOLD_DURATION:
			pop_scale = 1.0
			pop_alpha = 1.0
			var flash_progress = clamp(_elapsed / 0.1, 0.0, 1.0)
			flash_alpha = 1.0 - flash_progress
		else:
			var fade_progress = clamp((_elapsed - HOLD_DURATION) / FADE_DURATION, 0.0, 1.0)
			var eased_progress = 1.0 - pow(1.0 - fade_progress, 3.0)
			pop_scale = 1.0 + eased_progress * 0.5
			pop_alpha = 1.0 - eased_progress
			flash_alpha = 0.0

		var pop_size: Vector2 = base_rect.size * pop_scale
		var pop_rect := Rect2(center - pop_size * 0.5, pop_size)

		var tex: Texture2D = LetterTile.get_texture(letter, skin_id)
		if tex:
			draw_texture_rect(tex, pop_rect, false, Color(1, 1, 1, pop_alpha))

		if flash_alpha > 0.0:
			draw_rect(pop_rect, Color(1, 1, 1, flash_alpha * 0.8), true)
