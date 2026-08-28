extends PanelContainer

## ChatPreview - 底部單行聊天預覽條（膠囊樣式 + Hover 微光 + 點擊開啟聊天）
## 自建子節點，場景只需掛一個空的 PanelContainer 加此腳本。

signal chat_toggled(opened: bool)

const C_TEXT := Color(0.85, 0.88, 0.92)
const C_MUTED := Color(0.5, 0.55, 0.6)
const C_CYAN := Color(0.3, 0.85, 0.95)

var _preview_label: Label
var _style: StyleBoxFlat

func _ready() -> void:
	custom_minimum_size = Vector2(0, 40)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.1, 0.13, 0.18)
	_style.set_corner_radius_all(12)
	_style.set_content_margin_all(8)
	_style.set_border_width_all(1)
	_style.border_color = Color(0.3, 0.85, 0.95, 0.4)
	add_theme_stylebox_override("panel", _style)

	# Hover glow
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	add_child(hbox)

	var icon := Label.new()
	icon.text = "💬"
	icon.add_theme_font_size_override("font_size", 12)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon)

	_preview_label = Label.new()
	_preview_label.text = "等待訊息..."
	_preview_label.add_theme_font_size_override("font_size", 11)
	_preview_label.add_theme_color_override("font_color", C_MUTED)
	_preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_label.clip_text = true
	hbox.add_child(_preview_label)

	# Click to open chat
	gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			chat_toggled.emit(true)
	)

func _on_hover(entered: bool) -> void:
	if _style == null:
		return
	if entered:
		_style.border_color = Color(0.3, 0.85, 0.95, 0.8)
		_style.shadow_size = 4
		_style.shadow_color = Color(0.3, 0.85, 0.95, 0.15)
	else:
		_style.border_color = Color(0.3, 0.85, 0.95, 0.4)
		_style.shadow_size = 0

func update_preview(sender: String, text: String) -> void:
	if _preview_label:
		_preview_label.text = "%s: %s" % [sender, text]
		_preview_label.add_theme_color_override("font_color", C_TEXT)

func clear_preview() -> void:
	if _preview_label:
		_preview_label.text = "等待訊息..."
		_preview_label.add_theme_color_override("font_color", C_MUTED)
