extends Control

const CARD_SCENE = preload("res://Scenes/dictionary_card.tscn")

@onready var back_button: TextureButton = $Margin/VBox/TopBar/BackButton
@onready var search_icon: TextureRect = $Margin/VBox/SearchPill/HBox/SearchIcon
@onready var search_input: LineEdit = $Margin/VBox/SearchPill/HBox/SearchInput
@onready var list_container: VBoxContainer = $Margin/VBox/Scroll/ListContainer
@onready var scroll_container: ScrollContainer = $Margin/VBox/Scroll

var all_words: Array = []

## Scroll dragging state (lets you click-drag to scroll on PC)
var _dragging := false
var _last_drag_y := 0.0

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	search_input.text_changed.connect(_on_search_changed)
	_style_search_pill()
	_hide_scrollbar()
	_load_words()
	
	# Enable mouse-drag scrolling (touch already works natively)
	if scroll_container:
		scroll_container.gui_input.connect(_on_scroll_gui_input)

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

func _hide_scrollbar() -> void:
	if scroll_container:
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER

func _on_scroll_gui_input(event: InputEvent) -> void:
	## Lets you click-and-drag to scroll on PC, just like a finger on a phone.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_last_drag_y = event.position.y
	elif event is InputEventMouseMotion and _dragging:
		var delta_y : float = event.position.y - _last_drag_y
		_last_drag_y = event.position.y
		scroll_container.v_scroll = scroll_container.v_scroll - delta_y

func _load_words() -> void:
	# Fetch the player's collected words from the Cloudflare API
	var response = await ApiClient.get_vault(PlayerIdentity.player_id)
	
	if response.has("error"):
		_show_message("Failed to load your vault.\nCheck your connection.")
		return
	
	var words: Array = response.get("words", [])
	
	if words.is_empty():
		_show_message("Your vault is empty.\nClear words in a ranked game\nto collect them!")
		return
	
	# Build the all_words array with just the word (definitions load per-card)
	all_words = []
	for w in words:
		all_words.append({
			"word": w.get("word", ""),
			"times_collected": w.get("times_collected", 1)
		})
	
	_populate_list(all_words)

func _show_message(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", load("res://Assets/Fonts/Viga-Regular.ttf"))
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	list_container.add_child(lbl)

func _populate_list(words: Array) -> void:
	# Clear existing cards
	for child in list_container.get_children():
		child.queue_free()
	
	# Create cards
	for w in words:
		var card = CARD_SCENE.instantiate()
		list_container.add_child(card)
		card.setup(w.word, "")  # Definition will be fetched by the card itself

func _on_search_changed(new_text: String) -> void:
	if new_text.is_empty():
		_populate_list(all_words)
	else:
		_populate_list(all_words.filter(func(w):
			return w.word.to_lower().begins_with(new_text.to_lower())))

func _on_back_pressed() -> void:
	Nav.go_to_menu()
