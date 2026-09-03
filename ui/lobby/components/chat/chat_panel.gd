extends PanelContainer

## ChatPanel - 聊天主面板（Dock 模式）
## 從底部 Dock 條向上展開，與 Dock 條共用圓角和邊框風格

const ChatData := preload("res://ui/lobby/components/chat/chat_data.gd")
const ChatMessageItemScript := preload("res://ui/lobby/components/chat/chat_message_item.gd")
const ChatTabsScript := preload("res://ui/lobby/components/chat/chat_tabs.gd")
const ChatInputBarScript := preload("res://ui/lobby/components/chat/chat_input_bar.gd")
const ChatEmojiPickerScript := preload("res://ui/lobby/components/chat/chat_emoji_picker.gd")
const ChatSearchBarScript := preload("res://ui/lobby/components/chat/chat_search_bar.gd")
const ChatReactionsScript := preload("res://ui/lobby/components/chat/chat_reactions.gd")

signal tab_changed(tab: String)
signal message_sent(text: String, is_private: bool, target_id: String)
signal private_message_sent(target_id: String, text: String)
signal reaction_added(message_id: String, emoji: String)
signal reaction_removed(message_id: String, emoji: String)
signal search_query_changed(query: String)
signal closed()

const C_BG := Color(0.08, 0.10, 0.14, 0.96)
const C_BORDER := Color(0.22, 0.74, 0.97, 0.5)
const C_ACCENT_CYAN := Color(0.22, 0.74, 0.97)
const C_TEXT_MUTED := Color(0.50, 0.55, 0.60)

var _tabs: Node
var _message_list: VBoxContainer
var _scroll: ScrollContainer
var _input_bar: Node
var _emoji_picker: Node
var _search_bar: Node
var _reactions_panel: Node
var _close_btn: Button
var _ui_animations: Node = null

var active_tab: String = "room"
var _messages: Array = []
var _message_items: Dictionary = {}
var _search_active: bool = false
var _search_query: String = ""
var _panel_height: float = 400.0
var _close_tween: Tween = null
var _open_tween: Tween = null
var _is_open: bool = false

func _ready() -> void:
	_ui_animations = UIAnimations
	# Force bottom-sheet anchoring (can't rely on .tscn persisted values)
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 12.0
	offset_top = -476.0
	offset_right = -12.0
	offset_bottom = -76.0
	custom_minimum_size = Vector2(0, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_style()
	_build_ui()
	set_active_tab(active_tab)
	# Start hidden for dock mode
	visible = false
	modulate.a = 0.0

func _build_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(1)
	sb.border_color = C_BORDER
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(0.22, 0.74, 0.97, 0.15)
	sb.shadow_size = 8
	add_theme_stylebox_override("panel", sb)

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	vbox.add_child(header)

	_tabs = ChatTabsScript.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.tab_selected.connect(_on_tab_selected)
	_tabs.search_button_pressed.connect(_on_search_pressed)
	header.add_child(_tabs)

	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.flat = true
	_close_btn.custom_minimum_size = Vector2(28, 28)
	_close_btn.add_theme_font_size_override("font_size", 14)
	_close_btn.add_theme_color_override("font_color", C_TEXT_MUTED)
	_close_btn.pressed.connect(_on_close_pressed)
	header.add_child(_close_btn)

	_search_bar = ChatSearchBarScript.new()
	_search_bar.visible = false
	_search_bar.search_changed.connect(_on_search_changed)
	_search_bar.search_closed.connect(_on_search_closed)
	vbox.add_child(_search_bar)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_message_list = VBoxContainer.new()
	_message_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_message_list)

	_input_bar = ChatInputBarScript.new()
	_input_bar.message_submitted.connect(_on_message_submitted)
	_input_bar.emoji_button_pressed.connect(_on_emoji_pressed)
	vbox.add_child(_input_bar)

	_emoji_picker = ChatEmojiPickerScript.new()
	_emoji_picker.visible = false
	_emoji_picker.emoji_selected.connect(_on_emoji_selected)
	_emoji_picker.close_requested.connect(func(): _emoji_picker.hide())
	add_child(_emoji_picker)

	_reactions_panel = ChatReactionsScript.new()
	_reactions_panel.visible = false
	_reactions_panel.reaction_selected.connect(_on_reaction_selected)
	_reactions_panel.close_requested.connect(func(): _reactions_panel.hide())
	add_child(_reactions_panel)

## ── 訊息管理 ──────────────────────────────────────────────

func add_message(sender: String, text: String, is_self: bool, tab: String = "room",
		sender_id: String = "", is_private: bool = false, target_id: String = "") -> Dictionary:
	var sid := sender_id
	if sid.is_empty():
		var nm = get_node_or_null("/root/NetworkManager")
		if nm != null:
			sid = nm.get("product_user_id")
	var msg := ChatData.create_message(sender, sid, text, tab, is_self, is_private, target_id)
	_messages.append(msg)
	_append_message_item(msg)
	if not is_private and tab != active_tab and not _search_active:
		_tabs.add_unread(tab)
	return msg

func add_system_message(text: String) -> Dictionary:
	var msg := ChatData.create_system_message(text)
	_messages.append(msg)
	_append_message_item(msg)
	if "system" != active_tab and not _search_active:
		_tabs.add_unread("system")
	return msg

func add_private_message(sender: String, target_id: String, text: String, is_self: bool) -> Dictionary:
	var sender_id := ""
	var nm = get_node_or_null("/root/NetworkManager")
	if nm != null:
		sender_id = nm.get("product_user_id")
	var msg := ChatData.create_message(sender, sender_id, text, "room", is_self, true, target_id)
	_messages.append(msg)
	_append_message_item(msg)
	if not _search_active:
		_tabs.add_unread("room")
	return msg

func _append_message_item(msg: Dictionary) -> void:
	if _search_active:
		if msg["text"].to_lower().contains(_search_query.to_lower()):
			_create_item(msg)
		return
	if msg.get("is_private", false):
		if active_tab == "room":
			_create_item(msg)
		return
	if msg["tab"] == active_tab:
		_create_item(msg)

func _create_item(msg: Dictionary) -> void:
	var item := ChatMessageItemScript.new()
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.reaction_toggled.connect(_on_item_reaction_toggled)
	item.reaction_panel_requested.connect(_on_item_reaction_panel)
	item.sender_clicked.connect(_on_item_sender_clicked)
	_message_list.add_child(item)
	item.setup(msg)
	_message_items[msg["id"]] = item
	item.modulate.a = 0.0
	item.position.x = 20
	var tween := create_tween()
	tween.tween_property(item, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(item, "position:x", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	call_deferred("_scroll_to_bottom")

func _scroll_to_bottom() -> void:
	if _scroll != null:
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

func clear_messages() -> void:
	for child in _message_list.get_children():
		child.queue_free()
	_message_items.clear()
	_messages.clear()

func set_active_tab(tab_id: String) -> void:
	active_tab = tab_id
	if _tabs != null:
		_tabs.set_active_tab(tab_id)
	_rebuild_message_list()

func _rebuild_message_list() -> void:
	for child in _message_list.get_children():
		child.queue_free()
	_message_items.clear()
	var msgs_to_show: Array
	if _search_active:
		msgs_to_show = ChatData.search_messages(_messages, _search_query)
	else:
		msgs_to_show = ChatData.filter_by_tab(_messages, active_tab)
		if active_tab == "room":
			msgs_to_show += ChatData.filter_private_messages(_messages, _get_self_id())
	for msg in msgs_to_show:
		_create_item(msg)

## ── 輸入列 ────────────────────────────────────────────────

func focus_input() -> void:
	if _input_bar != null:
		_input_bar.focus_input()

func set_private_target(target_name: String, target_id: String) -> void:
	if _input_bar != null:
		_input_bar.set_private_mode(true, target_name, target_id)

func clear_private_target() -> void:
	if _input_bar != null:
		_input_bar.set_private_mode(false, "")

## ── Dock 模式開關動畫 ──────────────────────────────────────

func open_chat() -> void:
	# Kill any running close animation to prevent race condition
	if _close_tween != null and _close_tween.is_valid():
		_close_tween.kill()
		_close_tween = null
	if _is_open:
		focus_input()
		return
	_is_open = true
	visible = true
	move_to_front()
	z_index = 10
	# Expand to cover BottomBar area (full-width bottom sheet)
	offset_bottom = 0.0
	modulate.a = 0.0
	_open_tween = create_tween()
	_open_tween.tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	focus_input()

func close_chat() -> void:
	if not _is_open:
		return
	# Kill any running open animation
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
		_open_tween = null
	_close_tween = create_tween()
	_close_tween.tween_property(self, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_close_tween.tween_callback(func():
		visible = false
		_is_open = false
		# Restore collapsed size (above BottomBar)
		offset_bottom = -76.0
	)

## ── 信號處理 ──────────────────────────────────────────────

func _on_tab_selected(tab_id: String) -> void:
	set_active_tab(tab_id)
	tab_changed.emit(tab_id)

func _on_close_pressed() -> void:
	close_chat()
	closed.emit()

func _on_message_submitted(text: String, is_private: bool, target_id: String) -> void:
	if is_private and target_id != "":
		private_message_sent.emit(target_id, text)
	else:
		message_sent.emit(text, is_private, target_id)

func _on_search_pressed() -> void:
	_search_active = true
	_search_bar.visible = true
	_search_bar.focus_input()
	_rebuild_message_list()

func _on_search_changed(query: String) -> void:
	_search_query = query
	search_query_changed.emit(query)
	_rebuild_message_list()
	for msg_id in _message_items:
		_message_items[msg_id].set_highlight(query)

func _on_search_closed() -> void:
	_search_active = false
	_search_query = ""
	_search_bar.visible = false
	_rebuild_message_list()

func _on_emoji_pressed() -> void:
	if _emoji_picker != null:
		_emoji_picker.visible = not _emoji_picker.visible
		if _emoji_picker.visible:
			_emoji_picker.position = Vector2(_input_bar.position.x, _input_bar.position.y - 280)

func _on_emoji_selected(emoji: String) -> void:
	if _input_bar != null:
		_input_bar.insert_text(emoji)
	_emoji_picker.visible = false

func _on_item_reaction_toggled(message_id: String, emoji: String) -> void:
	_toggle_reaction(message_id, emoji)

func _on_item_reaction_panel(message_id: String, item_rect: Rect2) -> void:
	if _reactions_panel != null:
		_reactions_panel.visible = true
		_reactions_panel.position = Vector2(item_rect.position.x, item_rect.position.y - 50)
		_reactions_panel.set_target_message(message_id)

func _on_item_sender_clicked(sender_name: String, sender_id: String) -> void:
	if sender_id.is_empty():
		return
	set_private_target(sender_name, sender_id)
	focus_input()

func _on_reaction_selected(emoji: String) -> void:
	if _reactions_panel != null and _reactions_panel.has_method("get_target_message"):
		var msg_id: String = _reactions_panel.get_target_message()
		_toggle_reaction(msg_id, emoji)
	_reactions_panel.visible = false

func _toggle_reaction(message_id: String, emoji: String) -> void:
	var msg: Dictionary = {}
	for m in _messages:
		if m["id"] == message_id:
			msg = m
			break
	if msg.is_empty():
		return
	var self_id := _get_self_id()
	if ChatData.has_user_reacted(msg, emoji, self_id):
		ChatData.remove_reaction(msg, emoji, self_id)
		reaction_removed.emit(message_id, emoji)
	else:
		ChatData.add_reaction(msg, emoji, self_id)
		reaction_added.emit(message_id, emoji)
	if _message_items.has(message_id):
		_message_items[message_id].setup(msg)

func add_reaction(message_id: String, emoji: String) -> void:
	var msg: Dictionary = {}
	for m in _messages:
		if m["id"] == message_id:
			msg = m
			break
	if msg.is_empty():
		return
	ChatData.add_reaction(msg, emoji, "remote")
	if _message_items.has(message_id):
		_message_items[message_id].setup(msg)

func remove_reaction(message_id: String, emoji: String) -> void:
	var msg: Dictionary = {}
	for m in _messages:
		if m["id"] == message_id:
			msg = m
			break
	if msg.is_empty():
		return
	ChatData.remove_reaction(msg, emoji, "remote")
	if _message_items.has(message_id):
		_message_items[message_id].setup(msg)

func _get_self_id() -> String:
	var nm = get_node_or_null("/root/NetworkManager")
	if nm != null:
		return nm.get("product_user_id")
	return ""

func get_messages() -> Array:
	return _messages
