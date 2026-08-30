extends PanelContainer

## ChatDock - 統一底部 Dock 條
## 所有子元素設為 MOUSE_FILTER_IGNORE，PanelContainer 接收所有點擊

signal chat_toggled(opened: bool)
signal phrase_selected(phrase: String)

const C_BG := Color(0.10, 0.13, 0.18)
const C_BORDER := Color(0.22, 0.74, 0.97, 0.4)
const C_BORDER_HOVER := Color(0.22, 0.74, 0.97, 0.8)
const C_TEXT := Color(0.85, 0.88, 0.92)
const C_MUTED := Color(0.50, 0.55, 0.60)
const C_ACCENT_GREEN := Color(0.30, 0.85, 0.45)
const C_SYSTEM := Color(0.22, 0.74, 0.97)
const C_CHIP_BG := Color(0.12, 0.14, 0.18)
const C_CHIP_BORDER := Color(0.3, 0.85, 0.95, 0.5)
const C_CHIP_HOVER := Color(0.18, 0.22, 0.30)

var _preview_label: Label
var _expand_btn: Button
var _hbox: HBoxContainer
var _style: StyleBoxFlat
var _is_open: bool = false
var _chip_buttons: Array = []
var _tab_icons: Dictionary = {
	"room": "🏠",
	"team": "👥",
	"global": "🌍",
	"system": "⚙️",
}
var _phrases: Array = [
	["🚀 發車", "發車！"],
	["⏳ 等我", "等我一下"],
	["🏁 GG", "GG"],
	["😄", "😄"],
]
var _ui_animations: Node = null

func _ready() -> void:
	_ui_animations = UIAnimations
	custom_minimum_size = Vector2(0, 50)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP

	_style = StyleBoxFlat.new()
	_style.bg_color = C_BG
	_style.set_corner_radius_all(14)
	_style.set_content_margin_all(10)
	_style.set_border_width_all(1)
	_style.border_color = C_BORDER
	add_theme_stylebox_override("panel", _style)

	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	gui_input.connect(_on_gui_input)

	_build_ui()

func _build_ui() -> void:
	_hbox = HBoxContainer.new()
	_hbox.add_theme_constant_override("separation", 8)
	_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hbox)

	var icon := Label.new()
	icon.text = "💬"
	icon.add_theme_font_size_override("font_size", 14)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hbox.add_child(icon)

	_preview_label = Label.new()
	_preview_label.text = "點擊開啟聊天"
	_preview_label.add_theme_font_size_override("font_size", 12)
	_preview_label.add_theme_color_override("font_color", C_MUTED)
	_preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_label.clip_text = true
	_preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hbox.add_child(_preview_label)

	for phrase_pair in _phrases:
		var chip := _create_chip(str(phrase_pair[0]), str(phrase_pair[1]))
		_hbox.add_child(chip)
		_chip_buttons.append(chip)

	_expand_btn = Button.new()
	_expand_btn.text = "▲"
	_expand_btn.flat = true
	_expand_btn.custom_minimum_size = Vector2(32, 32)
	_expand_btn.add_theme_font_size_override("font_size", 12)
	_expand_btn.add_theme_color_override("font_color", C_MUTED)
	_expand_btn.pressed.connect(_on_expand_pressed)
	_expand_btn.mouse_entered.connect(func():
		if _ui_animations: _ui_animations.scale_to(_expand_btn, 1.1, 0.1)
	)
	_expand_btn.mouse_exited.connect(func():
		if _ui_animations: _ui_animations.scale_to(_expand_btn, 1.0, 0.1)
	)
	_hbox.add_child(_expand_btn)

func _create_chip(display_text: String, send_text: String) -> Button:
	var btn := Button.new()
	btn.text = display_text
	btn.flat = true
	btn.custom_minimum_size = Vector2(60, 30)
	btn.add_theme_font_size_override("font_size", 11)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = C_CHIP_BG
	style.set_corner_radius_all(10)
	style.set_content_margin_all(6)
	style.set_border_width_all(1)
	style.border_color = C_CHIP_BORDER
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = C_CHIP_HOVER
	hover.border_color = Color(0.3, 0.85, 0.95, 0.8)
	hover.shadow_size = 3
	hover.shadow_color = Color(0.3, 0.85, 0.95, 0.12)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := style.duplicate()
	pressed.bg_color = Color(0.10, 0.12, 0.16)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", C_TEXT)
	btn.add_theme_color_override("font_hover_color", C_TEXT.lightened(0.1))

	btn.pressed.connect(func():
		if _ui_animations:
			_ui_animations.scale_press(btn, 0.92, 0.08)
			await get_tree().create_timer(0.08).timeout
			_ui_animations.scale_release(btn, 0.1)
		# Flash dock border on send
		_flash_send()
		phrase_selected.emit(send_text)
	)

	return btn

func _flash_send() -> void:
	# Brief green flash then return to current state
	_style.border_color = Color(0.30, 0.85, 0.45, 0.9)
	_style.shadow_size = 6
	_style.shadow_color = Color(0.30, 0.85, 0.45, 0.3)
	await get_tree().create_timer(0.3).timeout
	if _is_open:
		_style.border_color = Color(0.22, 0.74, 0.97, 0.8)
		_style.shadow_size = 4
		_style.shadow_color = Color(0.22, 0.74, 0.97, 0.2)
	else:
		_style.border_color = C_BORDER
		_style.shadow_size = 0

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if the click is on a chip button
		var mouse_pos := get_global_mouse_position()
		for chip in _chip_buttons:
			if chip.get_global_rect().has_point(mouse_pos):
				return  # Let the chip handle it
		var expand_rect := _expand_btn.get_global_rect()
		if expand_rect.has_point(mouse_pos):
			return  # Let the expand button handle it
		emit_signal("chat_toggled", not _is_open)

func _on_hover(entered: bool) -> void:
	if _style == null:
		return
	if entered:
		_style.border_color = C_BORDER_HOVER
		_style.shadow_size = 4
		_style.shadow_color = Color(0.22, 0.74, 0.97, 0.15)
	else:
		_style.border_color = C_BORDER
		_style.shadow_size = 0

func _on_expand_pressed() -> void:
	emit_signal("chat_toggled", not _is_open)

func update_preview(sender: String, text: String, tab: String = "room") -> void:
	if _preview_label:
		var icon: String = _tab_icons.get(tab, "💬")
		var tab_name: String = _get_tab_name(tab)
		_preview_label.text = "%s [%s] %s: %s" % [icon, tab_name, sender, text]
		match tab:
			"system":
				_preview_label.add_theme_color_override("font_color", C_SYSTEM)
			"team":
				_preview_label.add_theme_color_override("font_color", C_ACCENT_GREEN)
			_:
				_preview_label.add_theme_color_override("font_color", C_TEXT)

func set_open(open_state: bool) -> void:
	_is_open = open_state
	if open_state:
		_expand_btn.text = "▼"
		# Active state: brighter border + subtle glow
		_style.border_color = Color(0.22, 0.74, 0.97, 0.8)
		_style.shadow_size = 4
		_style.shadow_color = Color(0.22, 0.74, 0.97, 0.2)
		_style.bg_color = Color(0.12, 0.16, 0.22)
		if _preview_label:
			_preview_label.add_theme_color_override("font_color", C_MUTED)
	else:
		_expand_btn.text = "▲"
		# Inactive state: default border
		_style.border_color = C_BORDER
		_style.shadow_size = 0
		_style.bg_color = C_BG

func _get_tab_name(tab: String) -> String:
	match tab:
		"room": return "房間"
		"team": return "隊伍"
		"global": return "世界"
		"system": return "系統"
		_: return tab
