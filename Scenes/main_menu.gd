extends Control

@onready var start_button: Button = $StartButton
@onready var podium_button: TextureButton = $IconRow/TextureButton
@onready var profile_button: TextureButton = $IconRow/TextureButton3

@onready var profile_card: PopupPanel = $ProfileCard
@onready var profile_close_btn: TextureButton = $ProfileCard/MarginContainer/Content/HeaderRow/TextureButton
@onready var name_input: LineEdit = $ProfileCard/MarginContainer/Content/NameField/NameInput
@onready var country_option: OptionButton = $ProfileCard/MarginContainer/Content/CountryField/OptionButton
@onready var save_button: TextureButton = $ProfileCard/MarginContainer/Content/TextureButton
@onready var dictionary_button: TextureButton = $IconRow/TextureButton2

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	podium_button.pressed.connect(_on_podium_pressed)
	profile_button.pressed.connect(_on_profile_pressed)
	profile_close_btn.pressed.connect(_on_profile_close)
	save_button.pressed.connect(_on_profile_save)
	dictionary_button.pressed.connect(_on_dictionary_pressed) 
	_populate_countries()
	
	# Apply the new design styles to the inputs!
	_style_line_edit(name_input)
	_style_option_button(country_option)
	_refresh_start_button()

## Shows CONTINUE when an unfinished session is waiting on disk,
## START otherwise. Also cleans up finished games' leftover saves.
func _refresh_start_button() -> void:
	var save_log := GameSave.read()
	if save_log == null:
		start_button.text = "START"
	elif save_log.finished:
		GameSave.delete_save()
		start_button.text = "START"
	else:
		start_button.text = "CONTINUE"

func _on_start_pressed() -> void:
	start_button.disabled = true

	# PRIORITY 1 — RESUME: an unfinished local session always wins.
	# No server call is needed, so this also works fully offline.
	var save_log := GameSave.read()
	if save_log != null and not save_log.finished:
		RankedSession.clear_session()
		Nav.go_to_game()
		return

	# PRIORITY 2 — FRESH GAME: ask the server; fall back to local offline ranked.
	start_button.text = "CONNECTING..."
	var response = await ApiClient.start_ranked_game(
		PlayerIdentity.player_id,
		PlayerIdentity.display_name,
		PlayerIdentity.country
	)

	if response.has("error"):
		# OFFLINE FALLBACK: Generate local seed and ID, mark as ranked
		print("[MainMenu] Offline detected. Starting local ranked game.")
		var local_session = {
			"game_id": "offline_" + str(Time.get_unix_time_from_system()) + "_" + str(randi()),
			"seed": randi(),
			"ruleset_version": "ranked_v1",
			"dictionary_version": "english_v1",
			"offline": true
		}
		RankedSession.start_new_session(local_session)
	else:
		RankedSession.start_new_session(response)

	Nav.go_to_game()


func _on_podium_pressed() -> void:
	Nav.go_to_leaderboard()

func _on_dictionary_pressed() -> void:
	Nav.go_to_dictionary()

func _on_profile_pressed() -> void:
	name_input.text = PlayerIdentity.display_name
	_select_country(PlayerIdentity.country)
	profile_card.popup_centered()

func _select_country(code: String) -> void:
	if code == "":
		country_option.selected = -1
		return
	for i in range(country_option.item_count):
		if country_option.get_item_metadata(i) == code:
			country_option.select(i)
			return
	country_option.selected = -1

func _on_profile_close() -> void:
	profile_card.hide()

func _on_profile_save() -> void:
	var new_name := name_input.text.strip_edges()
	if new_name == "":
		new_name = "Player"

	PlayerIdentity.display_name = new_name
	if country_option.selected >= 0:
		PlayerIdentity.country = str(country_option.get_item_metadata(country_option.selected))
	else:
		PlayerIdentity.country = ""
	PlayerIdentity.save_data()
	profile_card.hide()

func _populate_countries() -> void:
	country_option.clear()
	for entry in Countries.LIST:
		country_option.add_item(entry[1])
		country_option.set_item_metadata(country_option.item_count - 1, entry[0])
	country_option.selected = -1


func _style_option_button(option_btn: OptionButton) -> void:
	# 1. Style the button itself (closed state)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color.WHITE
	btn_style.border_color = Color(0.82, 0.83, 0.86) # Light gray border
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(8)
	btn_style.content_margin_left = 12
	btn_style.content_margin_right = 12
	btn_style.content_margin_top = 8
	btn_style.content_margin_bottom = 8
	
	option_btn.add_theme_stylebox_override("normal", btn_style)
	option_btn.add_theme_stylebox_override("hover", btn_style)
	option_btn.add_theme_stylebox_override("pressed", btn_style)
	option_btn.add_theme_stylebox_override("focus", btn_style)
	
	option_btn.add_theme_color_override("font_color", Color(0.227, 0.2, 0.168, 1))
	option_btn.add_theme_font_override("font", load("res://Assets/Fonts/LilitaOne-Regular.ttf"))
	option_btn.add_theme_font_size_override("font_size", 20)

	# 2. Style the dropdown list (PopupMenu)
	var popup = option_btn.get_popup()
	
	var popup_panel = StyleBoxFlat.new()
	popup_panel.bg_color = Color.WHITE
	popup_panel.border_color = Color(0.82, 0.83, 0.86)
	popup_panel.set_border_width_all(2)
	popup_panel.set_corner_radius_all(8)
	popup_panel.shadow_color = Color(0, 0, 0, 0.15)
	popup_panel.shadow_size = 4
	popup_panel.shadow_offset = Vector2(0, 2)
	popup_panel.content_margin_left = 4
	popup_panel.content_margin_right = 4
	popup_panel.content_margin_top = 4
	popup_panel.content_margin_bottom = 4
	
	popup.add_theme_stylebox_override("panel", popup_panel)
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.9, 0.95, 1.0) # Light blue hover
	hover_style.set_corner_radius_all(4)
	hover_style.content_margin_left = 8
	hover_style.content_margin_right = 8
	hover_style.content_margin_top = 6
	hover_style.content_margin_bottom = 6
	
	popup.add_theme_stylebox_override("hover", hover_style)
	
	var selected_style = StyleBoxFlat.new()
	selected_style.bg_color = Color(0.8, 0.9, 1.0) # Slightly darker blue for selected
	selected_style.set_corner_radius_all(4)
	selected_style.content_margin_left = 8
	selected_style.content_margin_right = 8
	selected_style.content_margin_top = 6
	selected_style.content_margin_bottom = 6
	
	popup.add_theme_stylebox_override("selected", selected_style)
	
	popup.add_theme_color_override("font_color", Color(0.227, 0.2, 0.168, 1))
	popup.add_theme_font_override("font", load("res://Assets/Fonts/LilitaOne-Regular.ttf"))
	popup.add_theme_font_size_override("font_size", 18)


func _style_line_edit(line_edit: LineEdit) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = Color(0.82, 0.83, 0.86)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	
	line_edit.add_theme_stylebox_override("normal", style)
	line_edit.add_theme_stylebox_override("focus", style)
	line_edit.add_theme_color_override("font_color", Color(0.227, 0.2, 0.168, 1))
	line_edit.add_theme_font_override("font", load("res://Assets/Fonts/LilitaOne-Regular.ttf"))
	line_edit.add_theme_font_size_override("font_size", 20)
