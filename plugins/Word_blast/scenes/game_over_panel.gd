extends Control

signal menu_pressed
signal play_pressed

## The two star textures. Edit the thresholds to decide when players earn
## the 2nd and 3rd star. (Star 1 is always earned just for finishing).
const STAR_EARNED := preload("res://Assets/UI/star.svg")
const STAR_UNEARNED := preload("res://Assets/UI/star_outline.svg")

const STAR_2_THRESHOLD := 1000
const STAR_3_THRESHOLD := 2500

@onready var score: Label = $Center/Panel/VBox/RewardBox/RewardVbox/Score
@onready var menu_button: TextureButton = $Center/Panel/VBox/Buttons/MenuButton
@onready var play_button: TextureButton = $Center/Panel/VBox/Buttons/PlayButton
@onready var star_2: TextureRect = $Center/Panel/VBox/Stars/Star2
@onready var star_1: TextureRect = $Center/Panel/VBox/Stars/Star1
@onready var star_3: TextureRect = $Center/Panel/VBox/Stars/Star3


func _ready() -> void:
	visible = false
	menu_button.pressed.connect(func(): menu_pressed.emit())
	play_button.pressed.connect(func(): play_pressed.emit())


func show_results(final_score: int) -> void:
	visible = true
	
	# 1. Count up the score from 0
	score.text = "0 PTS"
	var score_tween := create_tween()
	score_tween.tween_method(_set_score_text, 0, final_score, 1.0)
	
	# 2. Determine stars earned
	var earned := 1
	if final_score >= STAR_2_THRESHOLD: earned += 1
	if final_score >= STAR_3_THRESHOLD: earned += 1
	
	# 3. Set star textures based on score
	star_1.texture = STAR_EARNED
	star_2.texture = STAR_EARNED if earned >= 2 else STAR_UNEARNED
	star_3.texture = STAR_EARNED if earned >= 3 else STAR_UNEARNED
	
	# 4. Pop-in animation for the stars
	_animate_stars()


func _set_score_text(v: int) -> void:
	score.text = "%d PTS" % v


func _animate_stars() -> void:
	var stars := [star_1, star_2, star_3]
	var tw := create_tween()
	for i in range(3):
		var s: TextureRect = stars[i]
		s.pivot_offset = s.size * 0.5
		s.scale = Vector2.ZERO
		tw.tween_interval(0.2) # slight delay between each star
		tw.tween_property(s, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
