extends Control

const CARD_SCENE = preload("res://Scenes/leaderboard_card.tscn")

@onready var return_button: TextureButton = $MarginContainer/VBoxContainer/TopBar/ReturnButton
@onready var list_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/ListContainer
@onready var loading_label: Label = $MarginContainer/VBoxContainer/ScrollContainer/ListContainer/LoadingLabel

func _ready() -> void:
	return_button.pressed.connect(_on_return_pressed)
	_fetch_leaderboard()

func _fetch_leaderboard() -> void:
	# Call the Cloudflare Worker via your ApiClient autoload
	var response = await ApiClient.get_global_leaderboard(100)
	
	# Remove the "Fetching..." text once data arrives
	loading_label.queue_free()
	
	if response.has("error"):
		_show_message("Failed to load leaderboard.\nCheck your connection.")
		return
		
	var leaderboard: Array = response.get("leaderboard", [])
	
	if leaderboard.is_empty():
		_show_message("No scores yet.\nBe the first to play!")
		return
		
	# Spawn a card for every player in the database
	for entry in leaderboard:
		var card = CARD_SCENE.instantiate()
		list_container.add_child(card)
		card.setup(
			int(entry.get("rank", 0)), 
			str(entry.get("name", "Unknown")), 
			int(entry.get("score", 0)),
			str(entry.get("country", ""))
		)

func _show_message(text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", load("res://Assets/Fonts/Viga-Regular.ttf"))
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(0.227, 0.2, 0.168, 0.7))
	list_container.add_child(lbl)

func _on_return_pressed() -> void:
	Nav.go_to_menu()
