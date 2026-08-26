extends Node
## Downloads country flag sprites and caches them (memory + user://flags/)
## so the leaderboard can show a flag next to every player name without
## re-downloading. Later you can self-host these on your own CDN/R2 and
## only change FLAG_URL.

const FLAG_URL := "https://flagcdn.com/w40/%s.png"
const CACHE_DIR := "user://flags/"

var _memory: Dictionary = {}   # "fr" -> Texture2D
var _waiters: Dictionary = {}  # "fr" -> Array[Callable]

func flag_for(code: String, on_ready: Callable) -> void:
	var key := code.to_lower()
	if key.is_empty():
		return
		
	if _memory.has(key):
		if on_ready.is_valid():
			on_ready.call(_memory[key])
		return
		
	var is_new := not _waiters.has(key)
	if is_new:
		_waiters[key] = []
		
	# IMPORTANT: Append to the waiters list BEFORE calling _load().
	# If the file is already cached on disk, _load() will finish synchronously
	# and erase the key from _waiters. If we appended after, it would crash!
	_waiters[key].append(on_ready)
	
	if is_new:
		_load(key)

func _load(key: String) -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var path := CACHE_DIR + key + ".png"
	if FileAccess.file_exists(path):
		var img := Image.new()
		if img.load(path) == OK:
			_finish(key, ImageTexture.create_from_image(img))
			return
			
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_downloaded.bind(key, http))
	if http.request(FLAG_URL % key) != OK:
		http.queue_free()
		_finish(key, null)

func _on_downloaded(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, key: String, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_finish(key, null)
		return
		
	var file := FileAccess.open(CACHE_DIR + key + ".png", FileAccess.WRITE)
	if file != null:
		file.store_buffer(body)
		file.close()
		
	var img := Image.new()
	if img.load_png_from_buffer(body) != OK:
		_finish(key, null)
		return
		
	_finish(key, ImageTexture.create_from_image(img))

func _finish(key: String, tex: Texture2D) -> void:
	if tex != null:
		_memory[key] = tex
		
	var waiters: Array = _waiters.get(key, [])
	_waiters.erase(key)
	
	for cb in waiters:
		# is_valid() is false if the requesting card was freed meanwhile
		if cb.is_valid():
			cb.call(tex)
