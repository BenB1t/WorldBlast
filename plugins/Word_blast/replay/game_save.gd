extends RefCounted
class_name GameSave
## Persists the current game as its event log so the player can close the
## app and resume later — even days later. Resume flow:
##   read() -> GameReplayer.replay() -> hydrate the scene from result["game"]
## Deleting the save (the in-game Clear/Reset button) starts a fresh game.

const SAVE_PATH: String = "user://word_blast_save.json"

static func write(log: GameEventLog) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameSave: cannot open %s for writing (err=%d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return false
	file.store_string(log.to_json())
	file.close()
	return true

## Returns null when there is no save, it is unreadable, or it is corrupt.
## Callers treat all three as "start a new game".
static func read() -> GameEventLog:
	if not FileAccess.file_exists(SAVE_PATH):
		return null
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	return GameEventLog.from_json(text)

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
