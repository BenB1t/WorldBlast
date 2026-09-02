extends Node
const DEF_URL := "https://api.dictionaryapi.dev/api/v2/entries/en/%s"
const CACHE_DIR := "user://definitions/"
var _memory := {}
var _waiters := {}

func definition_for(word: String, on_ready: Callable) -> void:
	var key := word.to_lower()
	if key.is_empty(): return
	if _memory.has(key):
		if on_ready.is_valid(): on_ready.call(_memory[key])
		return
	var is_new := not _waiters.has(key)
	if is_new: _waiters[key] = []
	_waiters[key].append(on_ready)
	if is_new: _load(key)

func _load(key: String) -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var path := CACHE_DIR + key + ".json"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		var d := _extract(f.get_as_text())
		if d != "": _finish(key, d); return
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_downloaded.bind(key, http))
	if http.request(DEF_URL % key) != OK:
		http.queue_free(); _finish(key, "")

func _on_downloaded(result: int, code: int, _h: PackedStringArray, body: PackedByteArray, key: String, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_finish(key, ""); return
	var text := body.get_string_from_utf8()
	var f := FileAccess.open(CACHE_DIR + key + ".json", FileAccess.WRITE)
	if f: f.store_string(text); f.close()
	_finish(key, _extract(text))

func _extract(text: String) -> String:
	var json := JSON.new()
	if json.parse(text) != OK: return ""
	var data = json.data
	if data is Array and data.size() > 0:
		var meanings = data[0].get("meanings", [])
		if meanings is Array and meanings.size() > 0:
			var defs = meanings[0].get("definitions", [])
			if defs is Array and defs.size() > 0:
				return str(defs[0].get("definition", ""))
	return ""

func _finish(key: String, d: String) -> void:
	if d != "": _memory[key] = d
	var w = _waiters.get(key, [])
	_waiters.erase(key)
	for cb in w:
		if cb.is_valid(): cb.call(d)
