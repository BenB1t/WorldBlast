extends Control
class_name TimeBar

## Vertical 1-minute countdown. The WHITE fill (remaining time) is anchored
## at the bottom and its top edge sinks from top to down as time drains;
## cleared words push the white level back up (capped at full).

const BAR_WIDTH: float = 18.0
const RADIUS: int = 9

## INVERTED: dark teal track, white remaining-time fill.
const BG_COLOR := Color(0.13, 0.42, 0.60)       # dark teal capsule
const BORDER_COLOR := Color.WHITE               # crisp white outline
const FILL_COLOR := Color.WHITE                 # remaining time = white
const FILL_LOW_COLOR := Color(0.86, 0.25, 0.22) # red when < 25%

var ratio: float = 1.0
var _pulse_tween: Tween

func _ready() -> void:
	custom_minimum_size = Vector2(BAR_WIDTH, 0)
	set_v_size_flags(Control.SIZE_EXPAND_FILL)   # stretch to the grid's height
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_ratio(r: float) -> void:
	ratio = clamp(r, 0.0, 1.0)
	queue_redraw()

func pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "modulate", Color(0.6, 1.0, 0.7), 0.12)
	_pulse_tween.tween_property(self, "modulate", Color.WHITE, 0.35)

func _draw() -> void:
	if size.y < 4:
		return
	# Dark teal capsule with a white border
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = BG_COLOR
	sb_bg.border_color = BORDER_COLOR
	sb_bg.set_border_width_all(2)
	sb_bg.set_corner_radius_all(RADIUS)
	sb_bg.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))

	# White fill anchored at the BOTTOM: its top edge sinks top-to-down
	if ratio > 0.005:
		var fill_h: float = (size.y - 6) * ratio
		var inner := Rect2(Vector2(3, size.y - 3 - fill_h), Vector2(size.x - 6, fill_h))
		var sb_fill := StyleBoxFlat.new()
		sb_fill.bg_color = FILL_LOW_COLOR if ratio < 0.25 else FILL_COLOR
		sb_fill.set_corner_radius_all(max(RADIUS - 3, 2))
		sb_fill.draw(get_canvas_item(), inner)
