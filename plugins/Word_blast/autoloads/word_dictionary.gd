class_name WordDictionary
extends RefCounted

const WORD_LIST_PATH := "res://plugins/word_blast/data/word_list.txt"

static var _words: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(WORD_LIST_PATH, FileAccess.READ)
	if file == null:
		push_error("WordDictionary: could not open word list at %s" % WORD_LIST_PATH)
		return
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.length() >= 3:
			_words[line] = true
	file.close()
	print("[WordDictionary] Loaded %d words" % _words.size())

static func is_valid(word: String) -> bool:
	_ensure_loaded()
	return _words.has(word.to_upper())
	
## Public accessor so features like the hint system can iterate the full list.
static func get_all_words() -> Array:
	_ensure_loaded()
	return _words.keys()
