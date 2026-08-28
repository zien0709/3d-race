extends HBoxContainer

## QuickPhrases - 底部快捷短語列
## 自建子節點，場景只需掛一個空的 HBoxContainer 加此腳本。

signal phrase_selected(phrase: String)

const C_TEXT := Color(0.85, 0.88, 0.92)
const C_MUTED := Color(0.5, 0.55, 0.6)
const C_PANEL := Color(0.12, 0.14, 0.18)

var _phrases: Array = ["Ready", "GG", "😄"]

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	custom_minimum_size = Vector2(0, 44)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	alignment = BoxContainer.ALIGNMENT_CENTER
	_build_phrases()

func _build_phrases() -> void:
	for phrase in _phrases:
		var btn := Button.new()
		btn.text = phrase
		btn.custom_minimum_size = Vector2(0, 30)
		btn.add_theme_font_size_override("font_size", 12)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.17, 0.22)
		style.set_corner_radius_all(6)
		style.set_content_margin_all(6)
		btn.add_theme_stylebox_override("normal", style)

		var hover := style.duplicate()
		hover.bg_color = Color(0.2, 0.22, 0.28)
		btn.add_theme_stylebox_override("hover", hover)

		var pressed := style.duplicate()
		pressed.bg_color = Color(0.12, 0.14, 0.18)
		btn.add_theme_stylebox_override("pressed", pressed)

		btn.add_theme_color_override("font_color", C_TEXT)
		btn.add_theme_color_override("font_hover_color", C_TEXT.lightened(0.1))
		btn.pressed.connect(func(): phrase_selected.emit(phrase))
		add_child(btn)

func setup(phrases: Array) -> void:
	_phrases = phrases
	# Clear existing buttons
	for child in get_children():
		child.queue_free()
	_build_phrases()
