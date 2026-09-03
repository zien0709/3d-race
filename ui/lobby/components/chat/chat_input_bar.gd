extends HBoxContainer

## ChatInputBar - 常駐底部聊天輸入列
## 含：快捷短語晶片、Emoji 按鈕、文字輸入、展開完整聊天、私訊指示、送出

signal message_submitted(text: String, is_private: bool, target_id: String)
signal emoji_button_pressed()
signal expand_chat_requested()
signal phrase_selected(phrase: String)

const C_TEXT := Color(0.90, 0.92, 0.95)
const C_TEXT_MUTED := Color(0.40, 0.45, 0.50)
const C_ACCENT_CYAN := Color(0.22, 0.74, 0.97)
const C_ACCENT_RED := Color(0.95, 0.30, 0.35)
const C_PANEL := Color(0.10, 0.12, 0.16)
const C_BORDER := Color(0.3, 0.35, 0.4, 0.3)

## 預設快捷短語
const DEFAULT_PHRASES := [
	"準備好了！",
	"好久不見",
	"這張圖不錯",
	"GG",
	"再來一局？",
	"有人要組隊嗎？",
	"車子調校怎麼樣？",
	"我先走了"
]

var _ui_animations := UIAnimations
var _phrase_container: HBoxContainer
var _emoji_btn: Button
var _line_edit: LineEdit
var _send_btn: Button
var _expand_btn: Button
var _private_indicator: Label
var _is_private: bool = false
var _target_name: String = ""
var _target_id: String = ""
var _phrases_visible: bool = true

func _ready() -> void:
	_ui_animations = UIAnimations
	_build_ui()

func _build_ui() -> void:
	add_theme_constant_override("separation", 8)
	custom_minimum_size = Vector2(0, 56)
	
	# Background panel style
	var style = StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.set_corner_radius_all(12)
	style.set_border_width_all(1)
	style.border_color = C_BORDER
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	
	# === Left: Quick Phrases (scrollable horizontal) ===
	var phrases_scroll = ScrollContainer.new()
	phrases_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phrases_scroll.horizontal_scroll_mode = 1  # Auto
	phrases_scroll.vertical_scroll_mode = 0    # Disabled
	add_child(phrases_scroll)
	
	_phrase_container = HBoxContainer.new()
	_phrase_container.add_theme_constant_override("separation", 6)
	phrases_scroll.add_child(_phrase_container)
	
	# Add default phrases as chips
	for phrase in DEFAULT_PHRASES:
		_add_phrase_chip(phrase)
	
	# Toggle phrases button
	var toggle_phrases_btn = Button.new()
	toggle_phrases_btn.text = "⋯"
	toggle_phrases_btn.flat = true
	toggle_phrases_btn.custom_minimum_size = Vector2(32, 32)
	toggle_phrases_btn.add_theme_font_size_override("font_size", 16)
	toggle_phrases_btn.add_theme_color_override("font_color", C_TEXT_MUTED)
	toggle_phrases_btn.pressed.connect(_toggle_phrases)
	_phrase_container.add_child(toggle_phrases_btn)
	
	# === Emoji Button ===
	_emoji_btn = Button.new()
	_emoji_btn.text = "😊"
	_emoji_btn.flat = true
	_emoji_btn.custom_minimum_size = Vector2(40, 40)
	_emoji_btn.add_theme_font_size_override("font_size", 20)
	_emoji_btn.pressed.connect(func(): emoji_button_pressed.emit())
	_emoji_btn.mouse_entered.connect(func(): _ui_animations.scale_to(_emoji_btn, 1.15, 0.12))
	_emoji_btn.mouse_exited.connect(func(): _ui_animations.scale_to(_emoji_btn, 1.0, 0.12))
	add_child(_emoji_btn)
	
	# === Private Message Indicator ===
	_private_indicator = Label.new()
	_private_indicator.text = "🔒 私訊"
	_private_indicator.add_theme_font_size_override("font_size", 11)
	_private_indicator.add_theme_color_override("font_color", C_ACCENT_RED)
	_private_indicator.visible = false
	_private_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_private_indicator)
	
	# === Line Edit ===
	_line_edit = LineEdit.new()
	_line_edit.placeholder_text = "輸入訊息… (Enter 發送，ESC 取消/關閉)"
	_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line_edit.custom_minimum_size = Vector2(0, 40)
	_line_edit.text_submitted.connect(_on_text_submitted)
	add_child(_line_edit)
	
	# === Send Button ===
	_send_btn = Button.new()
	_send_btn.text = "送出"
	_send_btn.flat = false
	_send_btn.custom_minimum_size = Vector2(70, 40)
	_send_btn.add_theme_font_size_override("font_size", 14)
	_send_btn.add_theme_color_override("font_color", Color(0.1, 0.12, 0.16))
	var send_style = StyleBoxFlat.new()
	send_style.bg_color = C_ACCENT_CYAN
	send_style.set_corner_radius_all(8)
	send_style.content_margin_left = 12
	send_style.content_margin_right = 12
	_send_btn.add_theme_stylebox_override("normal", send_style)
	var send_hover = send_style.duplicate()
	send_hover.bg_color = Color(0.3, 0.85, 1.0)
	_send_btn.add_theme_stylebox_override("hover", send_hover)
	_send_btn.pressed.connect(_on_send_pressed)
	add_child(_send_btn)
	
	# === Expand Chat Button ===
	_expand_btn = Button.new()
	_expand_btn.text = "⛶"
	_expand_btn.flat = true
	_expand_btn.custom_minimum_size = Vector2(40, 40)
	_expand_btn.add_theme_font_size_override("font_size", 18)
	_expand_btn.add_theme_color_override("font_color", C_TEXT_MUTED)
	_expand_btn.tooltip_text = "展開完整聊天視窗"
	_expand_btn.pressed.connect(func(): expand_chat_requested.emit())
	_expand_btn.mouse_entered.connect(func(): _ui_animations.scale_to(_expand_btn, 1.1, 0.12))
	_expand_btn.mouse_exited.connect(func(): _ui_animations.scale_to(_expand_btn, 1.0, 0.12))
	add_child(_expand_btn)

func _toggle_phrases() -> void:
	_phrases_visible = not _phrases_visible
	for child in _phrase_container.get_children():
		if child != _phrase_container.find_child("*"):  # Keep the toggle button
			child.visible = _phrases_visible

func _add_phrase_chip(phrase: String) -> void:
	var btn = Button.new()
	btn.text = phrase
	btn.flat = false
	btn.custom_minimum_size = Vector2(0, 32)
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", C_TEXT)
	var chip_style = StyleBoxFlat.new()
	chip_style.bg_color = Color(0.22, 0.74, 0.97, 0.15)
	chip_style.set_corner_radius_all(16)
	chip_style.set_border_width_all(1)
	chip_style.border_color = C_ACCENT_CYAN
	chip_style.content_margin_left = 12
	chip_style.content_margin_right = 12
	btn.add_theme_stylebox_override("normal", chip_style)
	var chip_hover = chip_style.duplicate()
	chip_hover.bg_color = Color(0.22, 0.74, 0.97, 0.3)
	btn.add_theme_stylebox_override("hover", chip_hover)
	btn.pressed.connect(func(p=phrase): _on_phrase_pressed(p))
	_phrase_container.add_child(btn)

func _on_phrase_pressed(phrase: String) -> void:
	phrase_selected.emit(phrase)
	_submit(phrase)

func _on_text_submitted(text: String) -> void:
	_submit(text)

func _on_send_pressed() -> void:
	_submit(_line_edit.text)

func _submit(text: String) -> void:
	var t := text.strip_edges()
	if t == "":
		return
	message_submitted.emit(t, _is_private, _target_id)
	_line_edit.clear()
	if _is_private:
		set_private_mode(false, "")

func set_private_mode(enabled: bool, target_name: String, target_id: String = "") -> void:
	_is_private = enabled
	_target_name = target_name
	_target_id = target_id
	_private_indicator.visible = enabled
	if enabled:
		_private_indicator.text = "🔒 → %s" % target_name
		_line_edit.placeholder_text = "私訊給 %s… (ESC 取消)" % target_name
	else:
		_line_edit.placeholder_text = "輸入訊息… (Enter 發送，ESC 取消/關閉)"

func focus_input() -> void:
	if _line_edit != null:
		_line_edit.grab_focus()

func get_text() -> String:
	return _line_edit.text

func insert_text(text: String) -> void:
	_line_edit.insert_text_at_caret(text)
	focus_input()

func clear_input() -> void:
	_line_edit.clear()

func _unhandled_input(event: InputEvent) -> void:
	# Handle ESC key - if line edit has focus, clear it; otherwise request chat close
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _line_edit.has_focus():
			_line_edit.release_focus()
			_line_edit.clear()
			if _is_private:
				set_private_mode(false, "")
			get_viewport().set_input_as_handled()
		else:
			# Could emit a signal to close chat, but lobby_main handles global ESC
			pass

func set_phrases(phrases: Array) -> void:
	# Clear existing phrase chips (except toggle button)
	for child in _phrase_container.get_children():
		if child != _phrase_container.get_child(-1):  # Last child is toggle button
			child.queue_free()
	
	for phrase in phrases:
		_add_phrase_chip(phrase)
