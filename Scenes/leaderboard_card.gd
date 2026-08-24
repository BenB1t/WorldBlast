extends PanelContainer
class_name LeaderboardCard

## Expected scene structure (built in the editor):
## LeaderboardCard (PanelContainer)  <- this script
## └── HBoxContainer
##     ├── RankLabel  (Label)
##     ├── NameLabel  (Label)
##     └── ScoreLabel (Label)

@onready var rank_label: Label = $HBoxContainer/RankLabel
@onready var name_label: Label = $HBoxContainer/NameLabel
@onready var score_label: Label = $HBoxContainer/ScoreLabel

const TOP_COLORS := {
	1: {"tint": Color(1.00, 0.94, 0.72), "text": Color(0.80, 0.58, 0.05)},  # gold
	2: {"tint": Color(0.89, 0.92, 0.97), "text": Color(0.50, 0.55, 0.65)},  # silver
	3: {"tint": Color(1.00, 0.88, 0.74), "text": Color(0.72, 0.44, 0.16)},  # bronze
}
const DEFAULT_TEXT := Color(0.28, 0.24, 0.19)

func setup(rank: int, player_name: String, score: int) -> void:
	rank_label.text = str(rank)
	name_label.text = player_name
	score_label.text = str(score)

	if TOP_COLORS.has(rank):
		rank_label.add_theme_color_override("font_color", TOP_COLORS[rank]["text"])
		_apply_top_tint(TOP_COLORS[rank]["tint"])
	else:
		rank_label.add_theme_color_override("font_color", DEFAULT_TEXT)

## Tints the card background for top 3. We DUPLICATE the stylebox first so
## we don't tint every card that shares the same resource.
func _apply_top_tint(tint: Color) -> void:
	var base_style = get_theme_stylebox("panel")
	if base_style is StyleBoxTexture:
		var style := base_style.duplicate() as StyleBoxTexture
		style.modulate_color = tint
		add_theme_stylebox_override("panel", style)
	elif base_style is StyleBoxFlat:
		var flat := base_style.duplicate() as StyleBoxFlat
		flat.bg_color = tint
		add_theme_stylebox_override("panel", flat)
