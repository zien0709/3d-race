extends PanelContainer

## ChatPreview - 底部單行聊天預覽條
## 自建子節點，場景只需掛一個空的 PanelContainer 加此腳本。

signal preview_clicked()

const C_TEXT := Color(0.85, 0.88, 0.92)
const C_MUTED := Color(0.5, 0.55, 0.6)
const C_ACCENT := Color(0.3, 0.85, 0.95)

var _preview_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(0, 30)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", style)

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
			preview_clicked.emit()
	)

func update_preview(sender: String, text: String) -> void:
	if _preview_label:
		_preview_label.text = "%s: %s" % [sender, text]
		_preview_label.add_theme_color_override("font_color", C_TEXT)

func clear_preview() -> void:
	if _preview_label:
		_preview_label.text = "等待訊息..."
		_preview_label.add_theme_color_override("font_color", C_MUTED)
