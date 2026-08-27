extends Button

## ReadyButton - 底部核心按鈕（房主🚀/隊員✅）

const C_TEXT := Color(0.85, 0.88, 0.92)
const C_GREEN := Color(0.3, 0.9, 0.4)
const C_GREEN_BG := Color(0.15, 0.4, 0.2)
const C_MUTED := Color(0.5, 0.55, 0.6)
const C_DISABLED_BG := Color(0.15, 0.17, 0.22)

@onready var _ui_animations := UIAnimations

var _is_host: bool = false
var _all_ready: bool = false
var _is_ready: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(0, 48)
	add_theme_font_size_override("font_size", 16)

	# Default style
	var style := StyleBoxFlat.new()
	style.bg_color = C_DISABLED_BG
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = C_DISABLED_BG.lightened(0.05)
	add_theme_stylebox_override("hover", hover)

	var style_pressed := style.duplicate()
	style_pressed.bg_color = C_DISABLED_BG.darkened(0.1)
	add_theme_stylebox_override("pressed", style_pressed)

	var style_disabled := style.duplicate()
	style_disabled.bg_color = C_DISABLED_BG
	add_theme_stylebox_override("disabled", style_disabled)

	add_theme_color_override("font_color", C_MUTED)
	add_theme_color_override("font_disabled_color", C_MUTED)

	text = "🚀 開始比賽"
	disabled = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	pressed.connect(_on_pressed)

func set_mode(is_host: bool, all_ready: bool = false, is_ready: bool = false) -> void:
	_is_host = is_host
	_all_ready = all_ready
	_is_ready = is_ready

	if is_host:
		text = "🚀 開始比賽"
		if all_ready:
			_set_enabled_style()
		else:
			_set_disabled_style()
	else:
		if is_ready:
			text = "❌ 取消準備"
			_set_enabled_style()
		else:
			text = "✅ 準備就緒"
			_set_enabled_style()

func set_offline_mode() -> void:
	text = " offline"
	disabled = true
	_set_disabled_style()

func _set_enabled_style() -> void:
	disabled = false
	var style = get_theme_stylebox("normal")
	if style is StyleBoxFlat:
		style.bg_color = C_GREEN_BG
	var hover = get_theme_stylebox("hover")
	if hover is StyleBoxFlat:
		hover.bg_color = C_GREEN_BG.lightened(0.1)
	add_theme_color_override("font_color", C_GREEN)

func _set_disabled_style() -> void:
	disabled = true
	var style = get_theme_stylebox("normal")
	if style is StyleBoxFlat:
		style.bg_color = C_DISABLED_BG
	add_theme_color_override("font_color", C_MUTED)

func _on_pressed() -> void:
	_ui_animations.kill_tweens(self)
	_ui_animations.scale_press(self, 0.95, 0.08)
	await get_tree().create_timer(0.1).timeout
	_ui_animations.scale_release(self, 0.12)
