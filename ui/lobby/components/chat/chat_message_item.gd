extends PanelContainer

## ChatMessageItem - 單則聊天訊息（現代化設計）
## 含：頭像、發送者、時間戳、內容、表情反應條

const ChatData := preload("res://ui/lobby/components/chat/chat_data.gd")

signal reaction_toggled(message_id: String, emoji: String)
signal reaction_panel_requested(message_id: String, item_rect: Rect2)
signal sender_clicked(sender_name: String, sender_id: String)

const C_TEXT := Color(0.90, 0.92, 0.95)
const C_TEXT_SECONDARY := Color(0.55, 0.60, 0.65)
const C_TEXT_MUTED := Color(0.40, 0.45, 0.50)
const C_TEXT_SYSTEM := Color(0.22, 0.74, 0.97)
const C_ACCENT_GREEN := Color(0.30, 0.85, 0.45)
const C_BG_SELF := Color(0.12, 0.18, 0.16)
const C_BG_OTHER := Color(0.10, 0.12, 0.16)
const C_BG_SYSTEM := Color(0.10, 0.14, 0.18)
const C_BORDER_SELF := Color(0.30, 0.85, 0.45, 0.4)
const C_BORDER_OTHER := Color(0.22, 0.25, 0.30, 0.4)

var _message_data: Dictionary = {}
var _avatar: PanelContainer
var _avatar_label: Label
var _sender_label: Label
var _time_label: Label
var _text_label: RichTextLabel
var _reaction_bar: HBoxContainer
var _reaction_chips: Dictionary = {}
var _style_box: StyleBoxFlat
var _is_self: bool = false
var _ui_animations: Node = null
var _sender_id: String = ""

func _ready() -> void:
	_ui_animations = UIAnimations
	_build_ui()

func _build_ui() -> void:
	custom_minimum_size = Vector2(0, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_style_box = StyleBoxFlat.new()
	_style_box.set_corner_radius_all(10)
	_style_box.set_content_margin_all(10)
	_style_box.set_border_width_all(1)
	add_theme_stylebox_override("panel", _style_box)

	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 8)
	add_child(main_hbox)

	# Avatar (circular)
	_avatar = PanelContainer.new()
	_avatar.custom_minimum_size = Vector2(36, 36)
	var avatar_style := StyleBoxFlat.new()
	avatar_style.set_corner_radius_all(18)
	avatar_style.bg_color = Color(0.18, 0.22, 0.28)
	_avatar.add_theme_stylebox_override("panel", avatar_style)
	main_hbox.add_child(_avatar)

	_avatar_label = Label.new()
	_avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avatar_label.add_theme_font_size_override("font_size", 14)
	_avatar_label.add_theme_color_override("font_color", C_TEXT)
	_avatar.add_child(_avatar_label)

	# Content column
	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 2)
	main_hbox.add_child(content_vbox)

	# Header row: sender + time
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 6)
	content_vbox.add_child(header_hbox)

	_sender_label = Label.new()
	_sender_label.add_theme_font_size_override("font_size", 12)
	_sender_label.add_theme_color_override("font_color", C_TEXT_SECONDARY)
	_sender_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_sender_label.gui_input.connect(_on_sender_input)
	header_hbox.add_child(_sender_label)

	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 10)
	_time_label.add_theme_color_override("font_color", C_TEXT_MUTED)
	header_hbox.add_child(_time_label)

	# Text content (RichTextLabel for emoji + search highlight)
	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(0, 0)
	_text_label.add_theme_font_size_override("normal_font_size", 13)
	_text_label.add_theme_color_override("default_color", C_TEXT)
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_vbox.add_child(_text_label)

	# Reaction bar
	_reaction_bar = HBoxContainer.new()
	_reaction_bar.add_theme_constant_override("separation", 4)
	_reaction_bar.visible = false
	content_vbox.add_child(_reaction_bar)

	# Right-click to add reaction
	gui_input.connect(_on_gui_input)

func setup(message_data: Dictionary, self_id: String = "") -> void:
	_message_data = message_data
	_is_self = bool(message_data.get("is_self", false))
	_sender_id = str(message_data.get("sender_id", ""))
	var sender: String = message_data.get("sender", "")
	var text: String = message_data.get("text", "")
	var tab: String = message_data.get("tab", "room")
	var timestamp: float = message_data.get("timestamp", 0.0)
	var is_private: bool = message_data.get("is_private", false)

	# Avatar initial
	var initial := "?"
	if sender != "" and sender != "System":
		initial = sender[0].to_upper()
	_avatar_label.text = initial

	# Header
	if sender == "System":
		_sender_label.text = "系統"
		_sender_label.add_theme_color_override("font_color", C_TEXT_SYSTEM)
	elif _is_self:
		_sender_label.text = "你"
		_sender_label.add_theme_color_override("font_color", C_ACCENT_GREEN)
	else:
		_sender_label.text = sender
		_sender_label.add_theme_color_override("font_color", C_TEXT)

	_time_label.text = ChatData.format_timestamp(timestamp)
	if is_private:
		_time_label.text += " 🔒"

	# Text
	_text_label.text = text

	# Style by type
	if sender == "System" or tab == "system":
		_style_box.bg_color = C_BG_SYSTEM
		_style_box.border_color = Color(0.22, 0.74, 0.97, 0.3)
	elif _is_self:
		_style_box.bg_color = C_BG_SELF
		_style_box.border_color = C_BORDER_SELF
		_avatar_style_bg(C_ACCENT_GREEN)
	else:
		_style_box.bg_color = C_BG_OTHER
		_style_box.border_color = C_BORDER_OTHER

	# Reactions
	_rebuild_reactions()

func _avatar_style_bg(color: Color) -> void:
	var sb: StyleBoxFlat = _avatar.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		sb.bg_color = color

func set_highlight(query: String) -> void:
	## 用 BBCode 高亮搜尋匹配
	var text: String = _message_data.get("text", "")
	if query.strip_edges().is_empty():
		_text_label.text = text
		return
	var lower_text := text.to_lower()
	var lower_query := query.to_lower()
	var result := ""
	var idx := 0
	while true:
		var found := lower_text.find(lower_query, idx)
		if found == -1:
			result += text.substr(idx)
			break
		result += text.substr(idx, found - idx)
		result += "[color=#FFE14D]%s[/color]" % text.substr(found, query.length())
		idx = found + query.length()
	_text_label.text = result

func _rebuild_reactions() -> void:
	for child in _reaction_bar.get_children():
		child.queue_free()
	_reaction_chips.clear()

	if _message_data.is_empty() or _message_data.reactions.is_empty():
		_reaction_bar.visible = false
		return

	_reaction_bar.visible = true
	for emoji in _message_data.reactions:
		var r: Dictionary = _message_data.reactions[emoji]
		var chip := _create_reaction_chip(emoji, r["count"])
		_reaction_chips[emoji] = chip
		_reaction_bar.add_child(chip)

func _create_reaction_chip(emoji: String, count: int) -> Button:
	var chip := Button.new()
	chip.text = "%s %d" % [emoji, count]
	chip.flat = true
	chip.custom_minimum_size = Vector2(0, 24)
	chip.add_theme_font_size_override("font_size", 11)
	chip.add_theme_color_override("font_color", C_TEXT_SECONDARY)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(12)
	style.bg_color = Color(0.16, 0.20, 0.26)
	style.set_border_width_all(1)
	style.border_color = Color(0.22, 0.74, 0.97, 0.3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	chip.add_theme_stylebox_override("normal", style)
	chip.pressed.connect(func():
		reaction_toggled.emit(_message_data["id"], emoji)
	)
	chip.mouse_entered.connect(func():
		if _ui_animations:
			_ui_animations.scale_to(chip, 1.08, 0.1)
	)
	chip.mouse_exited.connect(func():
		if _ui_animations:
			_ui_animations.scale_to(chip, 1.0, 0.1)
	)
	return chip

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			reaction_panel_requested.emit(_message_data["id"], get_global_rect())

func _on_sender_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _is_self or _sender_label.text == "系統":
				return
			sender_clicked.emit(_sender_label.text, _sender_id)
