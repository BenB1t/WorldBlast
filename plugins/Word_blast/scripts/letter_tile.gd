extends RefCounted
class_name LetterTile

## Full letter tiles (letter + point badge already baked into the art),
## organized as one folder per skin, one file per letter:
##   res://plugins/word_blast/assets/tiles/<skin_id>/<LETTER>.png
## e.g. assets/tiles/skin_01/E.png
##
## 208 combinations (26 letters x 8 skins) is too many to preload() by
## hand, so this builds the path at runtime and loads it lazily, caching
## each texture after first use so repeat lookups are free.

const TILE_DIR := "res://plugins/word_blast/assets/tiles/"
const SKIN_IDS := [
	"skin_01", "skin_02", "skin_03", "skin_04",
	"skin_05", "skin_06", "skin_07", "skin_08",
]

## Fallback skin used when a cell has an empty skin_id (e.g. from old saves
## or edge cases). Using a fixed skin ensures the letter doesn't flicker
## by changing appearance every frame.
const FALLBACK_SKIN := "skin_01"

static var _cache: Dictionary = {}  # "skin_01/A" -> Texture2D


static func get_texture(letter: String, skin_id: String) -> Texture2D:
	# DEFENSIVE: if skin_id is empty, use a consistent fallback to avoid flicker
	if skin_id == "":
		skin_id = FALLBACK_SKIN
	
	var key: String = "%s/%s" % [skin_id, letter]
	if _cache.has(key):
		return _cache[key]

	var path: String = "%s%s/%s.png" % [TILE_DIR, skin_id, letter]
	if not ResourceLoader.exists(path):
		push_error("LetterTile: missing texture at %s" % path)
		return null

	var tex: Texture2D = load(path)
	_cache[key] = tex
	return tex


static func random_skin_id() -> String:
	return SKIN_IDS[randi() % SKIN_IDS.size()]
