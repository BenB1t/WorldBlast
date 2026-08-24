extends Node

const SAVE_PATH := "user://player_identity.json"
var player_id: String = ""
var display_name: String = "Player"

func _ready() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK:
			player_id = json.data.get("player_id", "")
			display_name = json.data.get("display_name", "Player")
		file.close()
		
	if player_id == "":
		player_id = _generate_uuid()
		_save()

func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"player_id": player_id, "display_name": display_name}))
	file.close()

func _generate_uuid() -> String:
	var bytes := PackedByteArray()
	bytes.resize(16)
	for i in range(16): bytes[i] = randi() % 256
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
