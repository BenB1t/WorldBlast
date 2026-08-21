extends Node

## Register this as an autoload named "WordDictionary"
## (Project Settings > Autoload > add this file, name it WordDictionary)
## Must be added BEFORE WordGrid/WordFinder ever run, since they call
## WordDictionary.is_valid() directly.

const WORD_LIST_PATH := "res://plugins/word_blast/data/word_list.txt"

# Stored as a Dictionary used purely as a set (word -> true) for O(1)
# lookups. ~7000 words costs negligible memory this way.
var _words: Dictionary = {}


func _ready() -> void:
	_load_word_list(WORD_LIST_PATH)


func _load_word_list(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("WordDictionary: could not open word list at %s" % path)
		return

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.length() >= 3:
			_words[line] = true
	file.close()

	print("[WordDictionary] Loaded %d words" % _words.size())


func is_valid(word: String) -> bool:
	return _words.has(word.to_upper())
