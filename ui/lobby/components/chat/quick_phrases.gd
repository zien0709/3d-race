extends HBoxContainer

## QuickPhrases - 底部快捷短語列（膠囊樣式 + Hover 高亮 + 點擊縮放）
## 自建子節點，場景只需掛一個空的 HBoxContainer 加此腳本。

signal phrase_selected(phrase: String)

const C_TEXT := Color(0.85, 0.88, 0.92)
const C_MUTED := Color(0.5, 0.55, 0.6)
const C_CYAN := Color(0.3, 0.85, 0.95)

var _phrases: Array = ["Ready", "GG", "😄"]
var _ui_animations: Node = null

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	custom_minimum_size = Vector2(0, 38)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	alignment = BoxContainer.ALIGNMENT_CENTER

	# Get UIAnimations reference
	_ui_animations = UIAnimations

	_build_phrases()

func _build_phrases() -> void:
	for phrase in _phrases:
		var btn := Button.new()
		btn.text = phrase
		btn.custom_minimum_size = Vector2(56, 34)
		btn.add_theme_font_size_override("font_size", 12)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		# Capsule style (radius 12px)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.17, 0.22)
		style.set_corner_radius_all(12)
		style.set_content_margin_all(8)
		style.set_border_width_all(1)
		style.border_color = Color(0.3, 0.35, 0.4, 0.3)
		btn.add_theme_stylebox_override("normal", style)

		var hover := style.duplicate()
		hover.bg_color = Color(0.2, 0.23, 0.30)
		hover.border_color = Color(0.3, 0.85, 0.95, 0.5)
		btn.add_theme_stylebox_override("hover", hover)

		var pressed := style.duplicate()
		pressed.bg_color = Color(0.12, 0.14, 0.18)
		btn.add_theme_stylebox_override("pressed", pressed)

		btn.add_theme_color_override("font_color", C_TEXT)
		btn.add_theme_color_override("font_hover_color", C_TEXT.lightened(0.1))

		# Click scale feedback (0.95 → 1.0)
		btn.pressed.connect(func():
			if _ui_animations:
				_ui_animations.scale_press(btn, 0.95, 0.08)
				await get_tree().create_timer(0.08).timeout
				_ui_animations.scale_release(btn, 0.1)
			phrase_selected.emit(phrase)
		)

		add_child(btn)

	# Ensure all buttons have uniform size
	for btn in get_children():
		if btn is Button:
			btn.custom_minimum_size = Vector2(56, 34)
			btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func setup(phrases: Array) -> void:
	_phrases = phrases
	# Clear existing buttons
	for child in get_children():
		child.queue_free()
	_build_phrases()
