extends Node
## Central page/scene navigator. Register as an autoload named "Nav".
##
## Every screen change goes through here instead of calling
## get_tree().change_scene_to_file() from random buttons. That gives us
## one place to add polish later — fades, loading screens, transition
## sounds — without touching every screen.

const MENU_SCENE := "res://Scenes/main_menu.tscn"
const GAME_SCENE := "res://plugins/word_blast/scenes/word_blast_game.tscn"

const FADE_DURATION := 0.25

var _layer: CanvasLayer
var _overlay: ColorRect
var _busy := false  # guards against double-taps mid-transition


func _ready() -> void:
	# The overlay lives on a CanvasLayer owned by THIS autoload, so it
	# survives scene swaps and can smoothly cover the transition moment.
	_layer = CanvasLayer.new()
	_layer.layer = 100  # above every game screen
	add_child(_layer)

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)  # start transparent
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_overlay)


## Main Menu -> START button
func go_to_game() -> void:
	_change_scene(GAME_SCENE)


## Game -> red door button (saving is done by the game scene first)
func go_to_menu() -> void:
	_change_scene(MENU_SCENE)


## Game -> green restart button
func restart_game() -> void:
	_change_scene(GAME_SCENE)


func _change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # swallow input mid-fade

	# Fade to black
	var out_tween := create_tween()
	out_tween.tween_property(_overlay, "color:a", 1.0, FADE_DURATION)
	await out_tween.finished

	# Swap the scene while fully covered
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame  # let the new scene instantiate

	# Fade back in
	var in_tween := create_tween()
	in_tween.tween_property(_overlay, "color:a", 0.0, FADE_DURATION)
	await in_tween.finished

	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
