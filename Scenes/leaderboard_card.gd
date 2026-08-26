extends PanelContainer
class_name LeaderboardCard

@onready var rank_label: Label = $HBox/RankLabel
@onready var name_label: Label = $HBox/NameLabel
@onready var flag_icon: TextureRect = $HBox/FlagIcon
@onready var score_label: Label = $HBox/ScoreLabel

## Optional subtle top-3 touch that keeps the clean design:
## only the RANK NUMBER gets a medal color.
const TOP_RANK_COLORS := {
	1: Color("#F6B93B"),  # gold
	2: Color("#9BA8B6"),  # silver
	3: Color("#CD8B62"),  # bronze
}

func setup(rank: int, player_name: String, score: int, country: String = "") -> void:
	rank_label.text = str(rank)
	name_label.text = player_name.to_upper()
	score_label.text = _format_score(score)

	if TOP_RANK_COLORS.has(rank):
		rank_label.add_theme_color_override("font_color", TOP_RANK_COLORS[rank])

	if country != "":
		FlagLoader.flag_for(country, _on_flag_ready)

func _on_flag_ready(tex: Texture2D) -> void:
	if tex == null:
		return
	flag_icon.texture = tex
	flag_icon.visible = true

## "15900" -> "15,900" like the design
func _format_score(value: int) -> String:
	var s := str(value)
	var out := ""
	var n := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		n += 1
		if n % 3 == 0 and i > 0:
			out = "," + out
	return out
