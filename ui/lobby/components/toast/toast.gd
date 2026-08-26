extends Control

## Toast - 短暫通知（頂部置中，滑入滑出）

const C_ACCENT := Color(0.22, 0.74, 0.97)

@onready var _ui_animations := UIAnimations

var _panel: PanelContainer
var _label: Label

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
	_panel.position.y = -_panel.size.y

func show_message(msg: String) -> void:
	if _label == null:
		return
	_label.text = msg
	_ui_animations.kill_tweens(_panel)
	_ui_animations.kill_tweens(self)
	var tween := _ui_animations.create_tween().set_parallel(true)
	tween.tween_property(_panel, "position:y", 0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_start_hide_timer.bind())

func _start_hide_timer() -> void:
	var timer = create_tween()
	timer.tween_interval(1.4)
	timer.finished.connect(_hide)

func _hide() -> void:
	_ui_animations.kill_tweens(_panel)
	_ui_animations.kill_tweens(self)
	var tween := _ui_animations.create_tween().set_parallel(true)
	var target_y := -_panel.size.y
	tween.tween_property(_panel, "position:y", target_y, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(queue_free)
