extends Control
class_name GameOverCard

signal restart_pressed
signal menu_pressed

## Tune these to decide when players earn the 2nd and 3rd star.
const STAR2_SCORE := 1000
const STAR3_SCORE := 2500

var _dim: ColorRect
var _panel: PanelContainer
var _stars: Array = []
var _reward_value: Label
var _gray_shader: Shader = null

func _ready() -> void:
	_build()
	visible = false

# =============================================================================
# BUILD (all UI created in code so nothing can be miswired in the editor)
# =============================================================================

func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# Blue floating panel with white border (like the reference)
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("2AA7DF")
	sb.set_corner_radius_all(18)
	sb.border_color = Color.WHITE
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.custom_minimum_size = Vector2(300, 0)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(vbox)

	# --- Stars row (middle star bigger, like the reference) ---
	var stars_row := HBoxContainer.new()
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.add_theme_constant_override("separation", 6)
	vbox.add_child(stars_row)
	var star_tex = load("res://Assets/UI/star.svg")
	for i in range(3):
		var t := TextureRect.new()
		t.texture = star_tex
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2(64, 64) if i != 1 else Vector2(92, 92)
		stars_row.add_child(t)
		_stars.append(t)

	# --- Title ---
	var title := Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", load("res://Assets/Fonts/LilitaOne-Regular.ttf"))
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	# --- Reward box: white with yellow border ---
	var reward_box := PanelContainer.new()
	var rb := StyleBoxFlat.new()
	rb.bg_color = Color.WHITE
	rb.border_color = Color("F6B93B")
	rb.set_border_width_all(3)
	rb.set_corner_radius_all(10)
	rb.content_margin_left = 16
	rb.content_margin_right = 16
	rb.content_margin_top = 10
	rb.content_margin_bottom = 10
	reward_box.add_theme_stylebox_override("panel", rb)
	vbox.add_child(reward_box)

	var rvbox := VBoxContainer.new()
	rvbox.add_theme_constant_override("separation", 2)
	reward_box.add_child(rvbox)

	var reward_title := Label.new()
	reward_title.text = "Your reward"
	reward_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_title.add_theme_font_override("font", load("res://Assets/Fonts/Viga-Regular.ttf"))
	reward_title.add_theme_font_size_override("font_size", 15)
	reward_title.add_theme_color_override("font_color", Color(0.45, 0.45, 0.48))
	rvbox.add_child(reward_title)

	_reward_value = Label.new()
	_reward_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_value.add_theme_font_override("font", load("res://Assets/Fonts/LilitaOne-Regular.ttf"))
	_reward_value.add_theme_font_size_override("font_size", 26)
	_reward_value.add_theme_color_override("font_color", Color(0.16, 0.16, 0.18))
	rvbox.add_child(_reward_value)

	# --- Round yellow buttons: menu (door) + play again (return arrow) ---
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var menu_btn := _make_round_button(load("res://Assets/UI/door.png"))
	menu_btn.pressed.connect(func(): menu_pressed.emit())
	var restart_btn := _make_round_button(load("res://Assets/UI/return.png"))
	restart_btn.pressed.connect(func(): restart_pressed.emit())
	btn_row.add_child(menu_btn)
	btn_row.add_child(restart_btn)

func _make_round_button(icon: Texture2D) -> Button:
	var b := Button.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("F6B93B")
	sb.set_corner_radius_all(32)
	sb.border_color = Color.WHITE
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 3)
	b.add_theme_stylebox_override("normal", sb)
	var sbp: StyleBoxFlat = sb.duplicate()
	sbp.bg_color = Color("E0A32E")
	b.add_theme_stylebox_override("pressed", sbp)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.custom_minimum_size = Vector2(64, 64)
	b.icon = icon
	b.add_theme_constant_override("icon_max_size", 30)
	return b

func _make_gray(t: TextureRect) -> void:
	if _gray_shader == null:
		_gray_shader = Shader.new()
		_gray_shader.code = "shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(g) * vec3(0.95, 0.97, 1.0), c.a);
}"
	var m := ShaderMaterial.new()
	m.shader = _gray_shader
	t.material = m

# =============================================================================
# SHOW
# =============================================================================

func show_results(final_score: int) -> void:
	visible = true
	_reward_value.text = "0 PTS"
	_dim.modulate.a = 0.0
	await get_tree().process_frame  # let layout settle so pivots are correct

	var earned := 1
	if final_score >= STAR2_SCORE: earned += 1
	if final_score >= STAR3_SCORE: earned += 1

	var tw := create_tween()
	tw.tween_property(_dim, "modulate:a", 1.0, 0.2)

	# Panel pop-in
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.7, 0.7)
	_panel.modulate.a = 0.0
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(_panel, "modulate:a", 1.0, 0.2)

	# Stars pop one by one; unearned ones turn gray
	for i in range(3):
		var s: TextureRect = _stars[i]
		s.pivot_offset = s.size * 0.5
		s.scale = Vector2.ZERO
		if i >= earned:
			_make_gray(s)
		tw.tween_property(s, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)

	# Score count-up
	tw.tween_method(_set_pts, 0, final_score, 0.8)

func _set_pts(v: int) -> void:
	_reward_value.text = "%s PTS" % _fmt(v)

func _fmt(value: int) -> String:
	var s := str(value)
	var out := ""
	var n := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		n += 1
		if n % 3 == 0 and i > 0:
			out = "," + out
	return out
