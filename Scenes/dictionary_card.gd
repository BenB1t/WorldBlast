extends PanelContainer
class_name DictionaryCard

@onready var word_label: Label = $VBox/WordLabel
@onready var definition_label: Label = $VBox/DefinitionLabel

func _ready() -> void:
	_style_card()

func _style_card() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	
	# Removed the teal border!
	
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.18) # Soft drop shadow
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	add_theme_stylebox_override("panel", style)

	word_label.add_theme_font_override("font", load("res://Assets/Fonts/LilitaOne-Regular.ttf"))
	word_label.add_theme_font_size_override("font_size", 24)
	word_label.add_theme_color_override("font_color", Color(0.13, 0.13, 0.15, 1))

	definition_label.add_theme_font_override("font", load("res://Assets/Fonts/Viga-Regular.ttf"))
	definition_label.add_theme_font_size_override("font_size", 15)
	definition_label.add_theme_color_override("font_color", Color(0.25, 0.25, 0.28, 1))
	definition_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func setup(word: String, definition: String) -> void:
	word_label.text = word.to_upper()
	definition_label.text = definition
