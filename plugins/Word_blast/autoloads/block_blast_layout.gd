extends Node

## Register this script as an autoload named "BlockBlastLayout"
## (Project Settings > Autoload > add this file, name it BlockBlastLayout)
## BEFORE running the game — grid.gd, letter_piece.gd, and letter_tray.gd
## all read cell_size from here instead of a hardcoded constant, so the
## whole board resizes to fit any screen.

var cell_size: int = 40

## How big a "cell" is while a piece is just resting in the tray —
## smaller than cell_size so all tray slots always fit across the screen.
## Pieces are built at full cell_size always; this is applied as a visual
## scale on top.
var tray_cell_size: int = 24


func get_tray_scale() -> float:
	if cell_size <= 0:
		return 1.0
	return float(tray_cell_size) / float(cell_size)
