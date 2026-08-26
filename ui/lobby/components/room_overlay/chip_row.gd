extends HBoxContainer

## ChipRow - 膠囊選擇列：一組互斥選項按鈕（房間設定 overlay 用）

signal value_changed(row: String, value: String)

@onready var _ui_animations := UIAnimations

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
		b.custom_minimum_size = Vector2(72, 28)
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(_on_chip_pressed.bind(opt))
		
		# Create visual container (PanelContainer) for animations
		var visual := PanelContainer.new()
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual.set_anchors_preset(Control.PRESET_FULL_RECT)
		visual.offset_left = 0
		visual.offset_top = 0
		visual.offset_right = 0
		visual.offset_bottom = 0
		b.add_child(visual)
		
		# Button text goes in a Label inside the visual container
		var chip_label := Label.new()
		chip_label.text = str(opt)
		chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip_label.add_theme_font_size_override("font_size", 12)
		chip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		chip_label.offset_left = 8
		chip_label.offset_right = -8
		chip_label.offset_top = 4
		chip_label.offset_bottom = -4
		visual.add_child(chip_label)
		
		# Make Button itself transparent (no visual style)
		var transparent_sb := StyleBoxFlat.new()
		transparent_sb.bg_color = Color(0, 0, 0, 0)
		b.add_theme_stylebox_override("normal", transparent_sb)
		b.add_theme_stylebox_override("hover", transparent_sb)
		b.add_theme_stylebox_override("pressed", transparent_sb)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		
		# Store visual container reference on button for animation access
		b.set_meta("_visual", visual)
		b.set_meta("_label", chip_label)
		
		# Connect animation signals
		b.mouse_entered.connect(_on_chip_mouse_entered.bind(b))
		b.mouse_exited.connect(_on_chip_mouse_exited.bind(b))
		b.gui_input.connect(_on_chip_gui_input.bind(b))
		
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
		var visual: PanelContainer = b.get_meta("_visual")
		var chip_label: Label = b.get_meta("_label")
		var active := is_current(str(options[i]))
		var bg := Color(0.22, 0.74, 0.97, 0.2) if active else Color(1, 1, 1, 0.03)
		var border := Color(0.22, 0.74, 0.97) if active else Color(0.545, 0.608, 0.706, 0.18)
		var font_color := Color(0.22, 0.74, 0.97) if active else Color(0.6, 0.65, 0.7)
		_style_chip(visual, bg, border)
		chip_label.add_theme_color_override("font_color", font_color)

func _style_chip(visual: PanelContainer, bg: Color, border: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	visual.add_theme_stylebox_override("panel", sb)
	
	var hover := sb.duplicate()
	hover.bg_color = bg.lightened(0.12)
	visual.add_theme_stylebox_override("panel_hover", hover)
	
	var pressed := sb.duplicate()
	pressed.bg_color = bg.darkened(0.12)
	visual.add_theme_stylebox_override("panel_pressed", pressed)

func _on_chip_mouse_entered(btn: Button) -> void:
	var visual: PanelContainer = btn.get_meta("_visual")
	_ui_animations.kill_tweens(visual)
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector2(1.03, 1.03), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_chip_mouse_exited(btn: Button) -> void:
	var visual: PanelContainer = btn.get_meta("_visual")
	_ui_animations.kill_tweens(visual)
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_chip_gui_input(btn: Button, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var visual: PanelContainer = btn.get_meta("_visual")
		if event.pressed:
			_ui_animations.kill_tweens(visual)
			var tween := create_tween()
			tween.tween_property(visual, "scale", Vector2(0.95, 0.95), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			_ui_animations.kill_tweens(visual)
			# Check if still hovered by checking mouse position
			var is_hovered := visual.get_rect().has_point(visual.get_local_mouse_position())
			var target_scale = Vector2(1.03, 1.03) if is_hovered else Vector2(1.0, 1.0)
			var tween := create_tween()
			tween.tween_property(visual, "scale", target_scale, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 新增方法：支援 host 權限控制
func set_disabled(disabled: bool) -> void:
	for b in _buttons:
		b.disabled = disabled

func set_chip_tooltip(text: String) -> void:
	for b in _buttons:
		b.tooltip_text = text
