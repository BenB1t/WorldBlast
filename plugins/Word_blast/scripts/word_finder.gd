extends RefCounted
class_name WordFinder

## Scans the row and column passing through (row, col) for every valid
## word of length >= 3. Returns an Array of Dictionaries:
##   {word: String, cells: Array[Vector2i]}
## A single placement can surface more than one match (e.g. a run of
## letters "S T A R T" validly contains both "STAR" and "START"), so this
## returns ALL valid substrings found, not just the first/longest.
##
## `cells` param is a raw 2D array where cells[y][x] is "" (empty) or a
## single uppercase letter — pass WordGrid.cells directly. This class
## touches no Nodes, so it can be unit-tested with a hand-built array
## before any scene exists.

static func find_words_through(cells: Array, size: int, row: int, col: int) -> Array:
	var matches: Array = []
	matches += _scan_axis(cells, size, row, col, Vector2i(1, 0))  # horizontal
	matches += _scan_axis(cells, size, row, col, Vector2i(0, 1))  # vertical
	return matches


static func _scan_axis(cells: Array, size: int, row: int, col: int, dir: Vector2i) -> Array:
	var origin := Vector2i(col, row)

	# Walk backward then forward along `dir` to find the full contiguous
	# run of filled cells that passes through origin.
	var back := origin
	while true:
		var probe: Vector2i = back - dir
		if not _in_bounds(probe, size) or cells[probe.y][probe.x] == "":
			break
		back = probe

	var forward := origin
	while true:
		var probe: Vector2i = forward + dir
		if not _in_bounds(probe, size) or cells[probe.y][probe.x] == "":
			break
		forward = probe

	var run_cells: Array[Vector2i] = []
	var run_letters: String = ""
	var cursor := back
	while true:
		run_cells.append(cursor)
		run_letters += cells[cursor.y][cursor.x]
		if cursor == forward:
			break
		cursor += dir

	if run_letters.length() < 3:
		return []

	# Check every substring of length >= 3 within the run, in reading
	# order, against the dictionary. O(n^2) substrings for a run of
	# length n (n <= 8 for an 8x8 board) — trivially cheap.
	var found: Array = []
	for start_i in range(run_letters.length()):
		for end_i in range(start_i + 3, run_letters.length() + 1):
			var sub := run_letters.substr(start_i, end_i - start_i)
			if WordDictionary.is_valid(sub):
				found.append({
					"word": sub,
					"cells": run_cells.slice(start_i, end_i)
				})
	return found


static func _in_bounds(pos: Vector2i, size: int) -> bool:
	return pos.x >= 0 and pos.x < size and pos.y >= 0 and pos.y < size
