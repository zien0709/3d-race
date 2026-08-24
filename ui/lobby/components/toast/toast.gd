extends Control

## Toast - 短暫通知（頂部置中，自動淡出）

const C_ACCENT := Color(0.22, 0.74, 0.97)

var _panel: PanelContainer
var _label: Label
var _tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size.y = 60

	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.16, 0.96)
	sb.set_border_width_all(1)
	sb.border_color = C_ACCENT
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 14)
	_panel.add_child(_label)

	_panel.modulate.a = 0.0

func show_message(msg: String) -> void:
	if _label == null:
		return
	_label.text = msg
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_panel.modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(1.4)
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.5)
