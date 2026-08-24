extends Control

var list_container: VBoxContainer
var loading_label: Label

func _ready() -> void:
	_build_ui()
	_fetch_and_populate()

func _build_ui() -> void:
	# 1. Background (Matches Main Menu)
	var bg = TextureRect.new()
	bg.texture = load("res://Assets/Background/1.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 2. Main Layout Margins
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)

	# 3. Top Bar
	var top_bar = HBoxContainer.new()
	top_bar.custom_minimum_size.y = 72
	vbox.add_child(top_bar)

	# Return Button (Red round button with cross icon)
	var return_btn = TextureButton.new()
	return_btn.custom_minimum_size = Vector2(64, 64)
	return_btn.texture_normal = load("res://Assets/UI/button_round_depth_gloss_red.svg")
	return_btn.texture_pressed = load("res://Assets/UI/button_round_gradient_red.svg")
	return_btn.pressed.connect(_on_return_pressed)
	top_bar.add_child(return_btn)

	var return_icon = TextureRect.new()
	return_icon.texture = load("res://Assets/UI/cross.png")
	return_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	return_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	return_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return_btn.add_child(return_icon)

	# Title
	var title = Label.new()
	title.text = "LEADERBOARD"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", load("res://Assets/Fonts/LilitaOne-Regular.ttf"))
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.227, 0.2, 0.168, 1))
	title.add_theme_color_override("font_outline_color", Color(0.51, 0.38, 0.10, 0.5))
	title.add_theme_constant_override("outline_size", 4)
	top_bar.add_child(title)
	
	# Invisible Spacer to keep the Title perfectly centered
	var spacer = Control.new()
	spacer.custom_minimum_size.x = 64
	top_bar.add_child(spacer)

	# 4. Scroll Container for the List
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	list_container = VBoxContainer.new()
	list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_container.add_theme_constant_override("separation", 12)
	scroll.add_child(list_container)
	
	# Loading State
	loading_label = Label.new()
	loading_label.text = "Fetching global scores..."
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.add_theme_font_override("font", load("res://Assets/Fonts/Viga-Regular.ttf"))
	loading_label.add_theme_font_size_override("font_size", 24)
	loading_label.add_theme_color_override("font_color", Color(0.227, 0.2, 0.168, 0.7))
	list_container.add_child(loading_label)

func _fetch_and_populate() -> void:
	# Call the Cloudflare Worker via your ApiClient autoload
	var response = await ApiClient.get_global_leaderboard(50)
	
	loading_label.queue_free()
	
	if response.has("error"):
		_show_message("Failed to load leaderboard.\nCheck your connection.", Color.RED)
		return
		
	var leaderboard: Array = response.get("leaderboard", [])
	
	if leaderboard.is_empty():
		_show_message("No scores yet.\nBe the first to play!", Color(0.227, 0.2, 0.168, 0.7))
		return
		
	for entry in leaderboard:
		_create_row(entry)

func _show_message(text: String, color: Color) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", load("res://Assets/Fonts/Viga-Regular.ttf"))
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", color)
	list_container.add_child(lbl)

func _create_row(entry: Dictionary) -> void:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Create the "Card" styling
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.85)
	style.border_color = Color(0.227, 0.2, 0.168, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	list_container.add_child(panel)
	
	var inner_hbox = HBoxContainer.new()
	inner_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(inner_hbox)

	var body_font = load("res://Assets/Fonts/Viga-Regular.ttf")
	var text_color = Color(0.227, 0.2, 0.168, 1)

	# Rank Number
	var rank_label = Label.new()
	rank_label.text = "%s." % str(entry.get("rank", "-"))
	rank_label.custom_minimum_size.x = 60
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank_label.add_theme_font_override("font", body_font)
	rank_label.add_theme_font_size_override("font_size", 28)
	rank_label.add_theme_color_override("font_color", text_color)
	inner_hbox.add_child(rank_label)

	# Player Name
	var name_label = Label.new()
	name_label.text = str(entry.get("name", "Unknown"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.add_theme_font_override("font", body_font)
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", text_color)
	inner_hbox.add_child(name_label)

	# Score
	var score_label = Label.new()
	score_label.text = str(entry.get("score", 0))
	score_label.custom_minimum_size.x = 120
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.add_theme_font_override("font", body_font)
	score_label.add_theme_font_size_override("font_size", 28)
	score_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.1, 1)) # Golden color
	inner_hbox.add_child(score_label)

func _on_return_pressed() -> void:
	Nav.go_to_menu()
