extends Control

const CARD_SCENE = preload("res://Scenes/dictionary_card.tscn")

@onready var back_button: TextureButton = $Margin/VBox/TopBar/BackButton
@onready var search_icon: TextureRect = $Margin/VBox/SearchPill/HBox/SearchIcon
@onready var search_input: LineEdit = $Margin/VBox/SearchPill/HBox/SearchInput
@onready var list_container: VBoxContainer = $Margin/VBox/Scroll/ListContainer

var all_words: Array = []

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	search_input.text_changed.connect(_on_search_changed)
	_style_search_pill()
	_load_words()

func _style_search_pill() -> void:
	# White rounded pill container
	var pill = StyleBoxFlat.new()
	pill.bg_color = Color.WHITE
	pill.border_color = Color(0.10, 0.35, 0.45, 1)
	pill.set_border_width_all(2)
	pill.set_corner_radius_all(24)
	pill.content_margin_left = 16
	pill.content_margin_right = 16
	pill.content_margin_top = 10
	pill.content_margin_bottom = 10
	$Margin/VBox/SearchPill.add_theme_stylebox_override("panel", pill)

	# Magnifier icon (swap in a real magnifier PNG later if you have one)
	search_icon.texture = load("res://Assets/UI/library-big.svg")
	search_icon.modulate = Color(0.10, 0.45, 0.60, 1)
	search_icon.custom_minimum_size = Vector2(24, 24)
	search_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	search_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Make the LineEdit transparent so the pill shows through
	var empty = StyleBoxEmpty.new()
	search_input.add_theme_stylebox_override("normal", empty)
	search_input.add_theme_stylebox_override("focus", empty)
	search_input.add_theme_color_override("font_color", Color(0.25, 0.25, 0.28, 1))
	search_input.add_theme_color_override("placeholder_color", Color(0.55, 0.55, 0.58, 1))
	search_input.add_theme_font_override("font", load("res://Assets/Fonts/Viga-Regular.ttf"))
	search_input.add_theme_font_size_override("font_size", 18)
	search_input.placeholder_text = "Search words..."

func _load_words() -> void:
	# Placeholder data for now. Later: load the player's collected words.
	all_words = [
		{"word": "blast", "definition": "A destructive wave of highly compressed air spreading outward from an explosion."},
		{"word": "vault", "definition": "A secure room or compartment for storing valuables."},
		{"word": "ability", "definition": "The physical or mental power or skill needed to do something."},
		{"word": "abroad", "definition": "In or to a foreign country."},
		{"word": "absence", "definition": "The fact of not being in a particular place."},
	]
	_populate_list(all_words)

func _populate_list(words: Array) -> void:
	for child in list_container.get_children():
		child.queue_free()
	for w in words:
		var card = CARD_SCENE.instantiate()
		list_container.add_child(card)
		card.setup(w.word, w.definition)

func _on_search_changed(new_text: String) -> void:
	if new_text.is_empty():
		_populate_list(all_words)
	else:
		_populate_list(all_words.filter(func(w):
			return w.word.to_lower().begins_with(new_text.to_lower())))

func _on_back_pressed() -> void:
	Nav.go_to_menu()
