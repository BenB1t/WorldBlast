extends Control

@onready var start_button: Button = $StartButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:
	# 1. Update UI to show we are connecting
	start_button.disabled = true
	start_button.text = "CONNECTING..."
	
	# 2. Call the Cloudflare Worker to start a ranked game
	var response = await ApiClient.start_ranked_game(
		PlayerIdentity.player_id, 
		PlayerIdentity.display_name
	)
	
	# 3. Handle errors (e.g. if Wrangler isn't running or network is down)
	if response.has("error"):
		print("[MainMenu] API Error: ", response)
		start_button.text = "NETWORK ERROR"
		
		# Reset the button after 2 seconds so the player can try again
		await get_tree().create_timer(2.0).timeout
		if is_instance_valid(start_button):
			start_button.text = "START"
			start_button.disabled = false
		return

	# 4. Store the server's seed and game_id for the game scene to pick up
	RankedSession.start_new_session(response)
	print("[MainMenu] Server assigned seed: ", RankedSession.game_seed)
	
	# 5. Launch the game via the Navigator
	Nav.go_to_game()
