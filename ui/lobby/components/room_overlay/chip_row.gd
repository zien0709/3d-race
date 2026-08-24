extends HBoxContainer

## ChipRow - 膠囊選擇列：一組互斥選項按鈕（房間設定 overlay 用）

signal value_changed(row: String, value: String)

var row_key: String = ""
var label_text: String = ""
var options: Array = []
var current_value: String = ""
var _buttons: Array = []

func setup(key: String, text: String, opts: Array, initial: String) -> void:
	row_key = key
	label_text = text
	options = opts
	current_value = initial

func _ready() -> void:
	custom_minimum_size = Vector2(0, 28)
	add_theme_constant_override("separation", 8)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(90, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)

	for opt in options:
		var b := Button.new()
		b.text = str(opt)
		b.custom_minimum_size = Vector2(72, 28)
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(_on_chip_pressed.bind(opt))
		add_child(b)
		_buttons.append(b)
	_refresh_styles()

func _on_chip_pressed(value: String) -> void:
	current_value = value
	_refresh_styles()
	value_changed.emit(row_key, value)

func set_value(value: String) -> void:
	current_value = value
	_refresh_styles()

func get_value() -> String:
	return current_value

func is_current(option_text: String) -> bool:
	if row_key == "maxp":
		return int(current_value.replace("人", "")) == int(str(option_text).replace("人", ""))
	return current_value == str(option_text)

func _refresh_styles() -> void:
	for i in _buttons.size():
		var b: Button = _buttons[i]
		var active := is_current(str(options[i]))
		var bg := Color(0.22, 0.74, 0.97, 0.2) if active else Color(1, 1, 1, 0.03)
		var border := Color(0.22, 0.74, 0.97) if active else Color(0.545, 0.608, 0.706, 0.18)
		_style_button(b, bg, border)
		b.add_theme_color_override("font_color", Color(0.22, 0.74, 0.97) if active else Color(0.6, 0.65, 0.7))

func _style_button(b: Button, bg: Color, border: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.bg_color = bg.lightened(0.12)
	b.add_theme_stylebox_override("hover", hover)
	var pressed := sb.duplicate()
	pressed.bg_color = bg.darkened(0.12)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
