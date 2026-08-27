extends PanelContainer

## FloatingChat - 分頁聊天視窗（房間 / 隊伍 / 世界）
## 自建子節點，場景只需掛一個空的 PanelContainer 加此腳本。

signal tab_changed(tab: String)
signal message_sent(text: String)
signal closed()

const MessageItemScript := preload("res://ui/lobby/components/chat/message_item.gd")
@onready var _ui_animations := UIAnimations

const C_MUTED := Color(0.6, 0.65, 0.7)
const C_ACCENT := Color(0.22, 0.74, 0.97)

var _tab_styleboxes: Dictionary = {}

const TAB_DEFS := [["room", "房間"], ["team", "隊伍"], ["global", "世界"]]

var active_tab: String = "room"

var _tab_buttons: Dictionary = {}
var _message_list: VBoxContainer
var _scroll: ScrollContainer
var _line_edit: LineEdit

func _ready() -> void:
	custom_minimum_size = Vector2(280, 200)
	_build_ui()
	set_active_tab(active_tab)

func set_active_tab(tab_id: String) -> void:
	active_tab = tab_id
	for id in _tab_buttons:
		var b: Button = _tab_buttons[id]
		var on: bool = id == tab_id
		if not _tab_styleboxes.has(id):
			var new_sb := StyleBoxFlat.new()
			new_sb.bg_color = Color.TRANSPARENT
			new_sb.set_corner_radius_all(6)
			_tab_styleboxes[id] = new_sb
			b.add_theme_stylebox_override("normal", new_sb)
		var sb: StyleBoxFlat = _tab_styleboxes[id]
		var target_color := Color(1, 1, 1, 0.06) if on else Color.TRANSPARENT
		var tween := create_tween()
		tween.tween_property(sb, "bg_color", target_color, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		b.add_theme_color_override("font_color", C_ACCENT if on else C_MUTED)

func add_message(sender: String, text: String, is_self: bool) -> void:
	if _message_list == null:
		return
	var msg := MessageItemScript.new()
	msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg.setup(sender, text, is_self)
	msg.position.x = 50
	msg.modulate.a = 0.0
	_message_list.add_child(msg)
	var tween := _ui_animations.slide_in_from_right(msg, 0.2)
	tween.set_parallel(true)
	tween.tween_property(msg, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	call_deferred("_scroll_to_bottom")

func focus_input() -> void:
	if _line_edit != null:
		_line_edit.grab_focus()

func clear_messages() -> void:
	if _message_list != null:
		for child in _message_list.get_children():
			child.queue_free()

## --- UI building ---

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	## 標題列：分頁 + 關閉
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	vbox.add_child(header)
	for def in TAB_DEFS:
		var b := Button.new()
		b.text = str(def[1])
		b.flat = true
		b.custom_minimum_size = Vector2(56, 26)
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(_on_tab_pressed.bind(str(def[0])))
		b.mouse_entered.connect(func(): _ui_animations.kill_tweens(b); _ui_animations.scale_to(b, 1.05, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT))
		b.mouse_exited.connect(func(): _ui_animations.kill_tweens(b); _ui_animations.scale_to(b, 1.0, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT))
		b.gui_input.connect(func(event): _on_tab_gui_input(event, b))
		header.add_child(b)
		_tab_buttons[str(def[0])] = b
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(24, 24)
	close_btn.pressed.connect(func(): closed.emit())
	close_btn.mouse_entered.connect(func(): _ui_animations.kill_tweens(close_btn); _ui_animations.scale_to(close_btn, 1.1, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT))
	close_btn.mouse_exited.connect(func(): _ui_animations.kill_tweens(close_btn); _ui_animations.scale_to(close_btn, 1.0, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT))
	close_btn.gui_input.connect(func(event): _on_close_gui_input(event, close_btn))
	header.add_child(close_btn)

	## 訊息列表
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)
	_message_list = VBoxContainer.new()
	_message_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_message_list)

	## 輸入列
	_line_edit = LineEdit.new()
	_line_edit.placeholder_text = "輸入訊息…"
	_line_edit.custom_minimum_size = Vector2(0, 30)
	_line_edit.text_submitted.connect(_on_text_submitted)
	vbox.add_child(_line_edit)

## --- Handlers ---

func _on_tab_pressed(tab_id: String) -> void:
	set_active_tab(tab_id)
	tab_changed.emit(tab_id)

func _on_text_submitted(text: String) -> void:
	var t := text.strip_edges()
	if t == "":
		return
	message_sent.emit(t)
	_line_edit.clear()

func _scroll_to_bottom() -> void:
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

func _on_tab_gui_input(event: InputEvent, btn: Button) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_ui_animations.kill_tweens(btn)
			_ui_animations.scale_to(btn, 0.95, 0.07, Tween.TRANS_SINE, Tween.EASE_OUT)
		else:
			_ui_animations.kill_tweens(btn)
			_ui_animations.scale_to(btn, 1.05, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT)

func _on_close_gui_input(event: InputEvent, btn: Button) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_ui_animations.kill_tweens(btn)
			_ui_animations.scale_to(btn, 0.9, 0.07, Tween.TRANS_SINE, Tween.EASE_OUT)
		else:
			_ui_animations.kill_tweens(btn)
			_ui_animations.scale_to(btn, 1.1, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT)
