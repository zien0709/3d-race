extends VBoxContainer

## MessageItem - 單則聊天訊息

var _sender_label: Label
var _text_label: Label

func _init() -> void:
	add_theme_constant_override("separation", 0)
	_sender_label = Label.new()
	_sender_label.add_theme_font_size_override("font_size", 11)
	add_child(_sender_label)
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 13)
	add_child(_text_label)

func setup(sender: String, text: String, is_self: bool) -> void:
	var content_color: Color
	if sender == "System":
		_sender_label.text = "[系統]"
		_sender_label.add_theme_color_override("font_color", Color(0.22, 0.74, 0.97))
		content_color = Color(0.6, 0.65, 0.7)
	elif is_self:
		_sender_label.text = "You:"
		_sender_label.add_theme_color_override("font_color", Color(0.062, 0.724, 0.508))
		content_color = Color(1, 1, 1)
	else:
		_sender_label.text = "[%s]:" % sender
		_sender_label.add_theme_color_override("font_color", Color(1, 1, 1))
		content_color = Color(0.8, 0.85, 0.92)
	_text_label.text = text
	_text_label.add_theme_color_override("font_color", content_color)
