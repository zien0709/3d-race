extends HBoxContainer

## ChatInputBar - 現代化輸入列
## 含：Emoji 按鈕、文字輸入、私訊目標指示、送出手勢

signal message_submitted(text: String, is_private: bool, target_id: String)
signal emoji_button_pressed()

const C_TEXT := Color(0.90, 0.92, 0.95)
const C_TEXT_MUTED := Color(0.40, 0.45, 0.50)
const C_ACCENT_CYAN := Color(0.22, 0.74, 0.97)
const C_ACCENT_RED := Color(0.95, 0.30, 0.35)

var _emoji_btn: Button
var _line_edit: LineEdit
var _send_btn: Button
var _private_indicator: Label
var _is_private: bool = false
var _target_name: String = ""
var _ui_animations: Node = null

func _ready() -> void:
	_ui_animations = UIAnimations
	_build_ui()

func _build_ui() -> void:
	add_theme_constant_override("separation", 6)
	custom_minimum_size = Vector2(0, 48)

	# Emoji button
	_emoji_btn = Button.new()
	_emoji_btn.text = "😊"
	_emoji_btn.flat = true
	_emoji_btn.custom_minimum_size = Vector2(36, 36)
	_emoji_btn.add_theme_font_size_override("font_size", 18)
	_emoji_btn.pressed.connect(func(): emoji_button_pressed.emit())
	_emoji_btn.mouse_entered.connect(_on_emoji_hover.bind(true))
	_emoji_btn.mouse_exited.connect(_on_emoji_hover.bind(false))
	add_child(_emoji_btn)

	# Private message indicator (hidden by default)
	_private_indicator = Label.new()
	_private_indicator.text = "🔒 私訊"
	_private_indicator.add_theme_font_size_override("font_size", 11)
	_private_indicator.add_theme_color_override("font_color", C_ACCENT_RED)
	_private_indicator.visible = false
	_private_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_private_indicator)

	# Line edit
	_line_edit = LineEdit.new()
	_line_edit.placeholder_text = "輸入訊息… (Enter 發送)"
	_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line_edit.custom_minimum_size = Vector2(0, 36)
	_line_edit.text_submitted.connect(_on_text_submitted)
	add_child(_line_edit)

	# Send button
	_send_btn = Button.new()
	_send_btn.text = "➤"
	_send_btn.flat = true
	_send_btn.custom_minimum_size = Vector2(40, 36)
	_send_btn.add_theme_font_size_override("font_size", 16)
	_send_btn.add_theme_color_override("font_color", C_ACCENT_CYAN)
	_send_btn.pressed.connect(_on_send_pressed)
	_send_btn.mouse_entered.connect(_on_send_hover.bind(true))
	_send_btn.mouse_exited.connect(_on_send_hover.bind(false))
	add_child(_send_btn)

func _on_emoji_hover(entered: bool) -> void:
	if _ui_animations:
		_ui_animations.scale_to(_emoji_btn, 1.1 if entered else 1.0, 0.12)

func _on_send_hover(entered: bool) -> void:
	if _ui_animations:
		_ui_animations.scale_to(_send_btn, 1.05 if entered else 1.0, 0.12)
	if entered:
		_send_btn.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	else:
		_send_btn.add_theme_color_override("font_color", C_ACCENT_CYAN)

func _on_text_submitted(text: String) -> void:
	_submit(text)

func _on_send_pressed() -> void:
	_submit(_line_edit.text)

func _submit(text: String) -> void:
	var t := text.strip_edges()
	if t == "":
		return
	message_submitted.emit(t, _is_private, _target_id_internal())
	_line_edit.clear()
	# Reset private mode after send
	if _is_private:
		set_private_mode(false, "")

func _target_id_internal() -> String:
	return _target_id

var _target_id: String = ""

func set_private_mode(enabled: bool, target_name: String, target_id: String = "") -> void:
	_is_private = enabled
	_target_name = target_name
	_target_id = target_id
	_private_indicator.visible = enabled
	if enabled:
		_private_indicator.text = "🔒 → %s" % target_name
		_line_edit.placeholder_text = "私訊給 %s…" % target_name
	else:
		_line_edit.placeholder_text = "輸入訊息… (Enter 發送)"

func focus_input() -> void:
	if _line_edit != null:
		_line_edit.grab_focus()

func get_text() -> String:
	return _line_edit.text

func insert_text(text: String) -> void:
	## 插入文字到遊標位置（Emoji 選擇用）
	_line_edit.insert_text_at_caret(text)
	focus_input()
